cmake_minimum_required(VERSION 3.10)
project(Cactus LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(SOURCE_DIR ${CMAKE_SOURCE_DIR}/build/cactus/cactus)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
    message(STATUS "CMAKE_BUILD_TYPE was not set, defaulting to Release.")
endif()

file(GLOB ENGINE_SOURCES "${SOURCE_DIR}/engine/*.cpp")
file(GLOB GRAPH_SOURCES "${SOURCE_DIR}/graph/*.cpp")
file(GLOB KERNEL_SOURCES "${SOURCE_DIR}/kernel/*.cpp")
file(GLOB FFI_SOURCES "${SOURCE_DIR}/ffi/*.cpp")
file(GLOB MODEL_SOURCES "${SOURCE_DIR}/models/*.cpp")
file(GLOB NPU_SOURCES "${SOURCE_DIR}/npu/*.cpp")
file(GLOB INDEX_SOURCES "${SOURCE_DIR}/index/*.cpp")

enable_language(OBJCXX)

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(CACTUS_PRO_LIB "${SOURCE_DIR}/../libs/libcactus_pro.a")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    string(TOLOWER "${CMAKE_OSX_SYSROOT}" SYSROOT_LOWER)
    if(SYSROOT_LOWER MATCHES "simulator")
        set(CACTUS_PRO_LIB "${CMAKE_SOURCE_DIR}/libcactus_pro-ios-simulator.a")
    else()
        set(CACTUS_PRO_LIB "${CMAKE_SOURCE_DIR}/libcactus_pro-ios.a")
    endif()
endif()

set(HEADER_FILES
    ${SOURCE_DIR}/cactus.h
    ${SOURCE_DIR}/engine/engine.h
    ${SOURCE_DIR}/graph/graph.h
    ${SOURCE_DIR}/kernel/kernel.h
    ${SOURCE_DIR}/kernel/kernel_utils.h
    ${SOURCE_DIR}/ffi/cactus_ffi.h
    ${SOURCE_DIR}/ffi/cactus_utils.h
    ${SOURCE_DIR}/npu/npu.h
    ${SOURCE_DIR}/models/model.h
    ${SOURCE_DIR}/index/index.h
)

set(COMMON_SOURCES
    ${KERNEL_SOURCES}
    ${GRAPH_SOURCES}
    ${ENGINE_SOURCES}
    ${FFI_SOURCES}
    ${MODEL_SOURCES}
    ${NPU_SOURCES}
    ${INDEX_SOURCES}
)

if(NOT COMMON_SOURCES)
    message(FATAL_ERROR "No source files found! Check SOURCE_DIR: ${SOURCE_DIR}")
endif()

add_library(CXXCactusDarwin SHARED ${COMMON_SOURCES})

set_target_properties(CXXCactusDarwin PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER com.cactuscompute.cactus
    VERSION 1.0.0
    SOVERSION 1.0.0
    OUTPUT_NAME "CXXCactusDarwin"
    PUBLIC_HEADER "${CMAKE_SOURCE_DIR}/build/cactus.h"
)

add_custom_command(TARGET CXXCactusDarwin POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Modules"
    COMMAND ${CMAKE_COMMAND} -E copy
        "${CMAKE_SOURCE_DIR}/module.modulemap.in"
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Modules/module.modulemap"
)

add_custom_command(TARGET CXXCactusDarwin POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Headers"
    COMMAND ${CMAKE_COMMAND} -E copy
        "${CMAKE_SOURCE_DIR}/build/cactus.h"
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Headers/CXXCactusDarwin.h"
)

target_include_directories(CXXCactusDarwin PUBLIC
    ${SOURCE_DIR}
    ${SOURCE_DIR}/engine
    ${SOURCE_DIR}/graph
    ${SOURCE_DIR}/kernel
    ${SOURCE_DIR}/ffi
    ${SOURCE_DIR}/npu
    ${SOURCE_DIR}/index
)

find_library(COREML_FRAMEWORK CoreML REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    find_package(CURL REQUIRED)
    target_link_libraries(CXXCactusDarwin PUBLIC ${COREML_FRAMEWORK} ${FOUNDATION_FRAMEWORK} ${CURL_LIBRARIES})
    target_include_directories(CXXCactusDarwin PUBLIC ${CURL_INCLUDE_DIRS})
    target_link_libraries(CXXCactusDarwin PUBLIC "-force_load ${CACTUS_PRO_LIB}")
elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(CXXCactusDarwin PUBLIC "-force_load ${CACTUS_PRO_LIB}")
    target_link_libraries(CXXCactusDarwin PUBLIC ${COREML_FRAMEWORK} ${FOUNDATION_FRAMEWORK})
endif()

target_compile_definitions(CXXCactusDarwin PRIVATE
    PLATFORM_CPU_ONLY=1
    __ARM_NEON=1
    __ARM_FEATURE_FP16_VECTOR_ARITHMETIC=1
    __ARM_FEATURE_DOTPROD=1
)

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_compile_definitions(CXXCactusDarwin PRIVATE TARGET_OS_IPHONE=1)
endif()

target_compile_options(CXXCactusDarwin PRIVATE
    -pthread
    -Wall
    -Wextra
    -pedantic
    -Wno-c++20-designator
    -Wno-missing-field-initializers
    -fomit-frame-pointer
    -funroll-loops
    -ftree-vectorize
    -O3 -DNDEBUG
    -fvisibility=hidden -fvisibility-inlines-hidden
    -ffunction-sections -fdata-sections
    -march=armv8.2-a+fp16+simd+dotprod
)

if (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    target_compile_options(CXXCactusDarwin PRIVATE -DCACTUS_IOS_ENABLE_LOGGING)
endif ()

target_link_options(CXXCactusDarwin PRIVATE
    -Wl,-dead_strip
    -flto
)
