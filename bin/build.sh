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

function build_android_artifactbundle() {
    rm -drf "$OUTPUT_DIR/CXXCactus.artifactbundle"
    echo "🤖 Building Cactus artifactbundle for Android platforms..."

    sed -i.bak 's/set(CMAKE_CXX_STANDARD *17)/set(CMAKE_CXX_STANDARD 20)/' "$ANDROID_DIR/CMakeLists.txt"

    $ANDROID_DIR/build.sh
    mkdir "$ARTIFACT_BUNDLE_PATH"
    mkdir -p "$ARTIFACT_BUNDLE_PATH/dist/android"
    cp -r "$ANDROID_DIR/libcactus.a" "$ARTIFACT_BUNDLE_PATH/dist/android/libcactus.a"
    mkdir -p "$ARTIFACT_BUNDLE_PATH/include"
    cp -r "$BUILD_DIR/cactus.h" "$ARTIFACT_BUNDLE_PATH/include/cactus.h"

    cat > "$ARTIFACT_BUNDLE_PATH/include/module.modulemap" << 'EOF'
module CXXCactus {
    header "cactus.h"
    export *
}
EOF

    cat > "$ARTIFACT_BUNDLE_PATH/info.json" << 'EOF'
{
  "schemaVersion": "1.0",
  "artifacts": {
    "cxxcactus": {
      "type": "staticLibrary",
      "version": "1.0.0",
      "variants": [
        {
          "path": "dist/android/libcactus.a",
          "supportedTriples": ["aarch64-unknown-linux-android"],
          "staticLibraryMetadata": {
            "headerPaths": ["include"],
            "moduleMapPath": "include/module.modulemap"
          }
        }
      ]
    }
  }
}
EOF

    zip -r "$ARTIFACT_BUNDLE_PATH.zip" "$ARTIFACT_BUNDLE_PATH"
    rm -drf "$ARTIFACT_BUNDLE_PATH"
    echo "✅ Finished creating Android artifactbundle"
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

        cmake -S "$SCRIPT_DIR" \
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

    # NB: macOS needs additional symlinks for SPM to detect the framework.
    MAC_DIR="$XCFRAMEWORK_PATH/macos-arm64/CXXCactusDarwin.framework"
    rm -rf "$MAC_DIR/Headers" "$MAC_DIR/Modules"
    ln -s Versions/A/Headers "$MAC_DIR/Headers"
    ln -s Versions/A/Modules "$MAC_DIR/Modules"

    echo "✅ Apple XCFramework built:"
    echo "   $XCFRAMEWORK_PATH"
    zip -r "$XCFRAMEWORK_PATH.zip" "$XCFRAMEWORK_PATH"
    rm -drf "$XCFRAMEWORK_PATH"
}

build_android_artifactbundle
build_apple_xcframework

rm -drf $BUILD_DIR
