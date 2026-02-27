cmake_minimum_required(VERSION 3.10)
project(Cactus LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version")
set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.0" CACHE STRING "Minimum iOS version")
set(CMAKE_XCODE_ATTRIBUTE_TVOS_DEPLOYMENT_TARGET "16.0" CACHE STRING "Minimum tvOS version")
set(CMAKE_XCODE_ATTRIBUTE_WATCHOS_DEPLOYMENT_TARGET "9.0" CACHE STRING "Minimum watchOS version")

set(BIN_DIR ${CMAKE_CURRENT_LIST_DIR}/..)
set(SOURCE_DIR ${BIN_DIR}/build/cactus/cactus)
set(CACTUS_CURL_ROOT "${BIN_DIR}/build/cactus/libs/curl" CACHE PATH "Path to vendored libcurl artifacts")

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
    message(STATUS "CMAKE_BUILD_TYPE was not set, defaulting to Release.")
endif()

set(CACTUS_CURL_INCLUDE_DIR "${CACTUS_CURL_ROOT}/include")
set(CACTUS_ENABLE_CURL OFF)
set(CACTUS_CURL_LIBRARY "")

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(CACTUS_CURL_LIBRARY "${CACTUS_CURL_ROOT}/macos/libcurl.a")
    set(CACTUS_ENABLE_CURL ON)
    message(STATUS "Configuring vendored libcurl for macOS")
elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    string(TOLOWER "${CMAKE_OSX_SYSROOT}" CACTUS_SYSROOT_LOWER)
    if(CACTUS_SYSROOT_LOWER MATCHES "simulator")
        set(CACTUS_CURL_LIBRARY "${CACTUS_CURL_ROOT}/ios/simulator/libcurl.a")
        message(STATUS "Configuring vendored libcurl for iOS Simulator")
    else()
        set(CACTUS_CURL_LIBRARY "${CACTUS_CURL_ROOT}/ios/device/libcurl.a")
        message(STATUS "Configuring vendored libcurl for iOS Device")
    endif()
    set(CACTUS_ENABLE_CURL ON)
else()
    message(STATUS "Skipping libcurl on ${CMAKE_SYSTEM_NAME}")
endif()

file(GLOB ENGINE_SOURCES "${SOURCE_DIR}/engine/*.cpp")
file(GLOB GRAPH_SOURCES "${SOURCE_DIR}/graph/*.cpp")
file(GLOB KERNEL_SOURCES "${SOURCE_DIR}/kernel/*.cpp")
file(GLOB FFI_SOURCES "${SOURCE_DIR}/ffi/*.cpp")
file(GLOB MODEL_SOURCES "${SOURCE_DIR}/models/*.cpp")
file(GLOB TELEMETRY_SOURCES "${SOURCE_DIR}/telemetry/*.cpp")
file(GLOB INDEX_SOURCES "${SOURCE_DIR}/index/*.cpp")

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(NPU_SOURCES "${SOURCE_DIR}/npu/npu_ane.mm")
else()
    set(NPU_SOURCES "${SOURCE_DIR}/npu/npu.cpp")
endif()

if(NOT CACTUS_ENABLE_CURL)
    set(CACTUS_TELEMETRY_STUB "${CMAKE_CURRENT_LIST_DIR}/telemetry_stub.cpp")
    set(TELEMETRY_SOURCES "${CACTUS_TELEMETRY_STUB}")
    message(STATUS "Using telemetry stub for ${CMAKE_SYSTEM_NAME}")
endif()

enable_language(OBJCXX)

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
    ${TELEMETRY_SOURCES}
    ${NPU_SOURCES}
    ${INDEX_SOURCES}
)

if(NOT COMMON_SOURCES)
    message(FATAL_ERROR "No source files found! Check SOURCE_DIR: ${SOURCE_DIR}")
endif()

if(BUILD_SHARED_LIBS)
    add_library(CXXCactusDarwin SHARED ${COMMON_SOURCES})
else()
    add_library(CXXCactusDarwin STATIC ${COMMON_SOURCES})
endif()

set_target_properties(CXXCactusDarwin PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER com.cactuscompute.cactus
    VERSION 1.0.0
    SOVERSION 1.0.0
    OUTPUT_NAME "CXXCactusDarwin"
    PUBLIC_HEADER "${BIN_DIR}/build/cactus.h"
)

add_custom_command(TARGET CXXCactusDarwin POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Modules"
    COMMAND ${CMAKE_COMMAND} -E copy
        "${BIN_DIR}/module.modulemap.in"
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Modules/module.modulemap"
)

add_custom_command(TARGET CXXCactusDarwin POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Headers"
    COMMAND ${CMAKE_COMMAND} -E copy
        "${BIN_DIR}/build/cactus.h"
        "$<TARGET_FILE_DIR:CXXCactusDarwin>/Headers/CXXCactusDarwin.h"
)

target_include_directories(CXXCactusDarwin PUBLIC
    ${SOURCE_DIR}
    ${SOURCE_DIR}/engine
    ${SOURCE_DIR}/graph
    ${SOURCE_DIR}/kernel
    ${SOURCE_DIR}/ffi
    ${SOURCE_DIR}/telemetry
    ${SOURCE_DIR}/npu
    ${SOURCE_DIR}/index
)

find_library(COREML_FRAMEWORK CoreML REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)
find_library(SECURITY_FRAMEWORK Security)
find_library(SYSTEMCONFIGURATION_FRAMEWORK SystemConfiguration)
find_library(CFNETWORK_FRAMEWORK CFNetwork)

target_link_libraries(CXXCactusDarwin PUBLIC
    ${COREML_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${ACCELERATE_FRAMEWORK}
)

if(CACTUS_ENABLE_CURL)
    if(NOT SECURITY_FRAMEWORK OR NOT SYSTEMCONFIGURATION_FRAMEWORK OR NOT CFNETWORK_FRAMEWORK)
        message(FATAL_ERROR "Required networking frameworks were not found for libcurl linking")
    endif()
    if(NOT EXISTS "${CACTUS_CURL_INCLUDE_DIR}/curl/curl.h" OR NOT EXISTS "${CACTUS_CURL_LIBRARY}")
        message(FATAL_ERROR "Vendored libcurl not found. Expected: ${CACTUS_CURL_INCLUDE_DIR}/curl/curl.h and ${CACTUS_CURL_LIBRARY}")
    endif()
    target_link_libraries(CXXCactusDarwin PUBLIC
        ${SECURITY_FRAMEWORK}
        ${SYSTEMCONFIGURATION_FRAMEWORK}
        ${CFNETWORK_FRAMEWORK}
        "${CACTUS_CURL_LIBRARY}"
    )
    target_include_directories(CXXCactusDarwin PUBLIC "${CACTUS_CURL_INCLUDE_DIR}")
    target_compile_definitions(CXXCactusDarwin PRIVATE CACTUS_USE_CURL=1)
endif()

target_compile_definitions(CXXCactusDarwin PRIVATE
    PLATFORM_CPU_ONLY=1
    __ARM_NEON=1
    __ARM_FEATURE_FP16_VECTOR_ARITHMETIC=1
    __ARM_FEATURE_DOTPROD=1
    __ARM_FEATURE_MATMUL_INT8=1
    ACCELERATE_NEW_LAPACK
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
    -O3
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
