#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

rm -drf "$BUILD_DIR"
mkdir "$BUILD_DIR"

COMMIT_SHA="${1:-}"
CLONE_DESC="main branch"
if [ -n "$COMMIT_SHA" ]; then
    CLONE_DESC="commit $COMMIT_SHA"
fi

if [ -z "$ANDROID_NDK_HOME" ]; then
    if [ -n "$ANDROID_HOME" ]; then
        ANDROID_NDK_HOME=$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)
    elif [ -d "$HOME/Library/Android/sdk" ]; then
        ANDROID_NDK_HOME=$(ls -d "$HOME/Library/Android/sdk/ndk/"* 2>/dev/null | sort -V | tail -1)
    fi
fi

echo "🔧 Cloning Cactus Repo from $CLONE_DESC"
CACTUS_ROOT_DIR="$BUILD_DIR/cactus"
git clone git@github.com:cactus-compute/cactus.git "$CACTUS_ROOT_DIR"
if [ -n "$COMMIT_SHA" ]; then
    git -C "$CACTUS_ROOT_DIR" checkout "$COMMIT_SHA"
    echo "✅ Checked out Cactus repo at commit $COMMIT_SHA"
fi

CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-Release}
ANDROID_DIR="$CACTUS_ROOT_DIR/android"
SOURCE_DIR="$CACTUS_ROOT_DIR/cactus"

OUTPUT_DIR="bin"

ARTIFACT_BUNDLE_PATH="$OUTPUT_DIR/CXXCactus.artifactbundle"
XCFRAMEWORK_PATH="$OUTPUT_DIR/CXXCactusDarwin.xcframework"

echo "🗑️ Removing Existing Binaries"
rm -drf "$ARTIFACT_BUNDLE_PATH" "$XCFRAMEWORK_PATH"

cp "$SOURCE_DIR/ffi/cactus_ffi.h" "$BUILD_DIR/cactus.h"

n_cpu=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

VARIANT_PATHS=()
VARIANT_TRIPLES=()

function artifactbundle_init() {
    rm -drf "$ARTIFACT_BUNDLE_PATH"
    mkdir -p "$ARTIFACT_BUNDLE_PATH/dist"
    mkdir -p "$ARTIFACT_BUNDLE_PATH/include"
    cp -r "$BUILD_DIR/cactus.h" "$ARTIFACT_BUNDLE_PATH/include/cactus.h"

    cat > "$ARTIFACT_BUNDLE_PATH/include/module.modulemap" << 'EOF'
module CXXCactus {
    header "cactus.h"
    export *
}
EOF
}

function artifactbundle_add_variant() {
    local RELATIVE_PATH="$1"
    local SUPPORTED_TRIPLE="$2"
    VARIANT_PATHS+=("$RELATIVE_PATH")
    VARIANT_TRIPLES+=("$SUPPORTED_TRIPLE")
}

function artifactbundle_write_info_json() {
    local INFO_FILE="$ARTIFACT_BUNDLE_PATH/info.json"
    {
        echo "{"
        echo "  \"schemaVersion\": \"1.0\"," 
        echo "  \"artifacts\": {"
        echo "    \"cxxcactus\": {"
        echo "      \"type\": \"staticLibrary\"," 
        echo "      \"version\": \"1.0.0\"," 
        echo "      \"variants\": ["
        local i
        for i in "${!VARIANT_PATHS[@]}"; do
            local COMMA="," 
            if [ "$i" -eq $((${#VARIANT_PATHS[@]} - 1)) ]; then
                COMMA=""
            fi
            echo "        {"
            echo "          \"path\": \"${VARIANT_PATHS[$i]}\"," 
            echo "          \"supportedTriples\": [\"${VARIANT_TRIPLES[$i]}\"],"
            echo "          \"staticLibraryMetadata\": {"
            echo "            \"headerPaths\": [\"include\"],"
            echo "            \"moduleMapPath\": \"include/module.modulemap\""
            echo "          }"
            echo "        }$COMMA"
        done
        echo "      ]"
        echo "    }"
        echo "  }"
        echo "}"
    } > "$INFO_FILE"
}

function artifactbundle_finalize() {
    artifactbundle_write_info_json
    zip -r "$ARTIFACT_BUNDLE_PATH.zip" "$ARTIFACT_BUNDLE_PATH"
    rm -drf "$ARTIFACT_BUNDLE_PATH"
    echo "✅ Artifactbundle created at $ARTIFACT_BUNDLE_PATH.zip"
}

function build_android_variant() {
    echo "🤖 Building Cactus artifactbundle variant for Android..."

    sed -i.bak 's/set(CMAKE_CXX_STANDARD *17)/set(CMAKE_CXX_STANDARD 20)/' "$ANDROID_DIR/CMakeLists.txt"
    sed -i.bak 's/target_link_libraries(cactus \${LOG_LIB} android)/target_link_libraries(cactus ${LOG_LIB} android c++_shared)/' "$ANDROID_DIR/CMakeLists.txt"

    "$ANDROID_DIR/build.sh"

    mkdir -p "$ARTIFACT_BUNDLE_PATH/dist/android"
    cp -r "$ANDROID_DIR/libcactus.a" "$ARTIFACT_BUNDLE_PATH/dist/android/libcactus.a"
    artifactbundle_add_variant "dist/android/libcactus.a" "aarch64-unknown-linux-android"
    echo "✅ Finished Android artifactbundle variant"
}

function build_linux_arm_variant() {
    local LINUX_ARM_OUT="$BUILD_DIR/linux-arm"
    local HOST_OS
    local HOST_ARCH
    local LINUX_ARM_PROCESSOR="aarch64"
    local CMAKE_TOOLCHAIN_FILE=""

    echo "🐧 Building Cactus artifactbundle variant for Linux ARM..."

    HOST_OS="$(uname -s)"
    HOST_ARCH="$(uname -m)"

    if [ "$HOST_OS" = "Linux" ] && { [ "$HOST_ARCH" = "aarch64" ] || [ "$HOST_ARCH" = "arm64" ]; }; then
        echo "Using native Linux ARM toolchain ($HOST_ARCH)."
    elif [ "$HOST_OS" = "Darwin" ] && [ "$HOST_ARCH" = "arm64" ]; then
        CMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/linux-arm/aarch64-macos-cross.toolchain.cmake"
        if [ ! -f "$CMAKE_TOOLCHAIN_FILE" ]; then
            echo "Error: Missing Linux ARM toolchain file at $CMAKE_TOOLCHAIN_FILE"
            exit 1
        fi
        echo "Using macOS cross toolchain file: $CMAKE_TOOLCHAIN_FILE"
    else
        echo "Error: Unsupported host for Linux ARM build: $HOST_OS/$HOST_ARCH"
        echo "Linux ARM build is supported on native Linux ARM or Apple Silicon macOS."
        exit 1
    fi

    local CMAKE_ARGS=(
        -S "$SCRIPT_DIR/linux-arm"
        -B "$LINUX_ARM_OUT"
        -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"
        -DCMAKE_SYSTEM_PROCESSOR="$LINUX_ARM_PROCESSOR"
    )

    if [ -n "$CMAKE_TOOLCHAIN_FILE" ]; then
        CMAKE_ARGS+=( -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" )
    fi

    cmake "${CMAKE_ARGS[@]}"
    cmake --build "$LINUX_ARM_OUT" --config "$CMAKE_BUILD_TYPE" -j "$n_cpu"

    local LINUX_LIB_PATH="$LINUX_ARM_OUT/lib/libcactus.a"
    if [ ! -f "$LINUX_LIB_PATH" ]; then
        LINUX_LIB_PATH="$LINUX_ARM_OUT/libcactus.a"
    fi

    if [ ! -f "$LINUX_LIB_PATH" ]; then
        echo "Error: Could not find Linux ARM static library output."
        exit 1
    fi

    mkdir -p "$ARTIFACT_BUNDLE_PATH/dist/linux-arm64"
    cp -r "$LINUX_LIB_PATH" "$ARTIFACT_BUNDLE_PATH/dist/linux-arm64/libcactus.a"
    artifactbundle_add_variant "dist/linux-arm64/libcactus.a" "aarch64-unknown-linux-gnu"
    echo "✅ Finished Linux ARM artifactbundle variant"
}

function build_apple_xcframework() {
    echo "🍏 Building Cactus XCFramework for all Apple platforms..."
    echo "Build type: $CMAKE_BUILD_TYPE"
    echo "Using $n_cpu CPU cores"

    APPLE_OUT="$BUILD_DIR"

    function build_apple_target() {
        local PLATFORM=$1
        local SYS=$2
        local SDK=$3
        local ARCH="arm64"
        local OUT="$APPLE_OUT/$PLATFORM"
        local VERSION=$4

        local SDK_PATH=$(xcrun --sdk "$SDK" --show-sdk-path)

        echo "▶️  Building $PLATFORM ($SYS, $ARCH, $SDK)"

        cmake -S "$SCRIPT_DIR/darwin" \
           -B "$OUT" \
           -GXcode \
           -DCMAKE_SYSTEM_NAME="$SYS" \
           -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
           -DCMAKE_OSX_SYSROOT="$SDK_PATH" \
           -DCMAKE_OSX_DEPLOYMENT_TARGET=$VERSION \
           -DBUILD_SHARED_LIBS=ON \
           -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"

        cmake --build "$OUT" --config "$CMAKE_BUILD_TYPE" -j "$n_cpu"
    }

    function find_framework() {
        echo "$APPLE_OUT/$1/Release$2/CXXCactusDarwin.framework"
    }

    echo "🛠️ Building iOS"
    build_apple_target "ios" "iOS" "iphoneos" 13.0
    IOS=$(find_framework "ios" "-iphoneos")

    echo "🛠️ Building iOS Simulator"
    build_apple_target "ios_sim" "iOS" "iphonesimulator" 13.0
    IOS_SIM=$(find_framework "ios_sim" "-iphonesimulator")

    echo "🛠️ Building macOS"
    build_apple_target "macos" "Darwin" "macosx" 11.0
    MAC=$(find_framework "macos" "")

    echo "🛠️ Building tvOS"
    build_apple_target "tvos" "tvOS" "appletvos" 13.0
    TVOS=$(find_framework "tvos" "-appletvos")

    echo "🛠️ Building tvOS Simulator"
    build_apple_target "tvos_sim" "tvOS" "appletvsimulator" 13.0
    TVOS_SIM=$(find_framework "tvos_sim" "-appletvsimulator")

    echo "🛠️ Building watchOS"
    build_apple_target "watchos" "watchOS" "watchos" 6.0
    WATCHOS=$(find_framework "watchos" "-watchos")

    echo "🛠️ Building watchOS Simulator"
    build_apple_target "watchos_sim" "watchOS" "watchsimulator" 6.0
    WATCHOS_SIM=$(find_framework "watchos_sim" "-watchsimulator")

    echo "🛠️ Building visionOS"
    build_apple_target "visionos" "visionOS" "xros" 1.0
    VISIONOS=$(find_framework "visionos" "-xros")

    echo "🛠️ Building visionOS Simulator"
    build_apple_target "visionos_sim" "visionOS" "xrsimulator" 1.0
    VISIONOS_SIM=$(find_framework "visionos_sim" "-xrsimulator")

    echo "IOS: $IOS"
    echo "IOS_SIM: $IOS_SIM"
    echo "MAC: $MAC"
    echo "TVOS: $TVOS"
    echo "TVOS_SIM: $TVOS_SIM"
    echo "WATCHOS: $WATCHOS"
    echo "WATCHOS_SIM: $WATCHOS_SIM"
    echo "VISIONOS: $VISIONOS"
    echo "VISIONOS_SIM: $VISIONOS_SIM"

    echo "📦 Creating XCFramework..."

    xcodebuild -create-xcframework \
        -framework "$IOS" \
        -framework "$IOS_SIM" \
        -framework "$MAC" \
        -framework "$TVOS" \
        -framework "$TVOS_SIM" \
        -framework "$WATCHOS" \
        -framework "$WATCHOS_SIM" \
        -framework "$VISIONOS" \
        -framework "$VISIONOS_SIM" \
        -output "$XCFRAMEWORK_PATH"

    MAC_DIR="$XCFRAMEWORK_PATH/macos-arm64/CXXCactusDarwin.framework"
    rm -rf "$MAC_DIR/Headers" "$MAC_DIR/Modules"
    ln -s Versions/A/Headers "$MAC_DIR/Headers"
    ln -s Versions/A/Modules "$MAC_DIR/Modules"

    echo "✅ Apple XCFramework built:"
    echo "   $XCFRAMEWORK_PATH"
    zip -r "$XCFRAMEWORK_PATH.zip" "$XCFRAMEWORK_PATH"
    rm -drf "$XCFRAMEWORK_PATH"
}

artifactbundle_init
build_android_variant
build_linux_arm_variant
artifactbundle_finalize
build_apple_xcframework

rm -drf "$BUILD_DIR"
