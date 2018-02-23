#!/bin/bash

##################################################################################
# Custom build tool for Realm Objective-C binding.
#
# (C) Copyright 2011-2015 by realm.io.
##################################################################################

# Warning: pipefail is not a POSIX compatible option, but on OS X it works just fine.
#          OS X uses a POSIX complain version of bash as /bin/sh, but apparently it does
#          not strip away this feature. Also, this will fail if somebody forces the script
#          to be run with zsh.
set -o pipefail
set -e

source_root="$(dirname "$0")"

# You can override the version of the core library
: ${REALM_CORE_VERSION:=$(sed -n 's/^REALM_CORE_VERSION=\(.*\)$/\1/p' ${source_root}/dependencies.list)} # set to "current" to always use the current build

: ${REALM_SYNC_VERSION:=$(sed -n 's/^REALM_SYNC_VERSION=\(.*\)$/\1/p' ${source_root}/dependencies.list)}

: ${REALM_OBJECT_SERVER_VERSION:=$(sed -n 's/^REALM_OBJECT_SERVER_VERSION=\(.*\)$/\1/p' ${source_root}/dependencies.list)}

# You can override the xcmode used
: ${XCMODE:=xcodebuild} # must be one of: xcodebuild (default), xcpretty, xctool

# Provide a fallback value for TMPDIR, relevant for Xcode Bots
: ${TMPDIR:=$(getconf DARWIN_USER_TEMP_DIR)}

PATH=/usr/libexec:$PATH

if ! [ -z "${JENKINS_HOME}" ]; then
    XCPRETTY_PARAMS="--no-utf --report junit --output build/reports/junit.xml"
    CODESIGN_PARAMS="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO"
fi

usage() {
cat <<EOF
Usage: sh $0 command [argument]

command:
  clean:                clean up/remove all generated files
  download-core:        downloads core library (binary version)
  download-object-server:  downloads and installs the Realm Object Server
  download-sync:        downloads sync library (binary version, core+sync)
  build:                builds all iOS  and OS X frameworks
  ios-static:           builds fat iOS static framework
  ios-dynamic:          builds iOS dynamic frameworks
  ios-swift:            builds RealmSwift frameworks for iOS
  watchos:              builds watchOS framwork
  watchos-swift:        builds RealmSwift framework for watchOS
  tvos:                 builds tvOS framework
  tvos-swift:           builds RealmSwift framework for tvOS
  osx:                  builds OS X framework
  osx-swift:            builds RealmSwift framework for OS X
  analyze-osx:          analyzes OS X framework
  test:                 tests all iOS and OS X frameworks
  test-all:             tests all iOS and OS X frameworks in both Debug and Release configurations
  test-ios-static:      tests static iOS framework on 32-bit and 64-bit simulators
  test-ios-dynamic:     tests dynamic iOS framework on 32-bit and 64-bit simulators
  test-ios-swift:       tests RealmSwift iOS framework on 32-bit and 64-bit simulators
  test-ios-devices:     tests ObjC & Swift iOS frameworks on all attached iOS devices
  test-ios-devices-objc:  tests ObjC iOS framework on all attached iOS devices
  test-ios-devices-swift: tests Swift iOS framework on all attached iOS devices
  test-tvos:            tests tvOS framework
  test-tvos-swift:      tests RealmSwift tvOS framework
  test-tvos-devices:    tests ObjC & Swift tvOS frameworks on all attached tvOS devices
  test-osx:             tests OS X framework
  test-osx-swift:       tests RealmSwift OS X framework
  verify:               verifies docs, osx, osx-swift, ios-static, ios-dynamic, ios-swift, ios-device in both Debug and Release configurations, swiftlint
  verify-osx-object-server:  downloads the Realm Object Server and runs the Objective-C and Swift integration tests
  docs:                 builds docs in docs/output
  examples:             builds all examples
  examples-ios:         builds all static iOS examples
  examples-ios-swift:   builds all Swift iOS examples
  examples-osx:         builds all OS X examples
  get-version:          get the current version
  set-version version:  set the version
  cocoapods-setup:      download realm-core and create a stub RLMPlatform.h file to enable building via CocoaPods


argument:
  version: version in the x.y.z format

environment variables:
  XCMODE: xcodebuild (default), xcpretty or xctool
  CONFIGURATION: Debug or Release (default)
  REALM_CORE_VERSION: version in x.y.z format or "current" to use local build
  REALM_EXTRA_BUILD_ARGUMENTS: additional arguments to pass to the build tool
  REALM_XCODE_VERSION: the version number of Xcode to use (e.g.: 8.1)
EOF
}

######################################
# Xcode Helpers
######################################

xcode_version_major() {
    echo "${REALM_XCODE_VERSION%%.*}"
}

xcode() {
    mkdir -p build/DerivedData
    CMD="xcodebuild -IDECustomDerivedDataLocation=build/DerivedData $@"
    echo "Building with command:" $CMD
    eval "$CMD"
}

xc() {
    # Logs xcodebuild output in realtime
    : ${NSUnbufferedIO:=YES}
    args="$@ SWIFT_VERSION=$REALM_SWIFT_VERSION $REALM_EXTRA_BUILD_ARGUMENTS"
    if [[ "$XCMODE" == "xcodebuild" ]]; then
        xcode "$args"
    elif [[ "$XCMODE" == "xcpretty" ]]; then
        mkdir -p build
        xcode "$args" | tee build/build.log | xcpretty -c ${XCPRETTY_PARAMS} || {
            echo "The raw xcodebuild output is available in build/build.log"
            exit 1
        }
    elif [[ "$XCMODE" == "xctool" ]]; then
        xctool "$args"
    fi
}

copy_bcsymbolmap() {
    find "$1" -name '*.bcsymbolmap' -type f -exec cp {} "$2" \;
}

build_combined() {
    local scheme="$1"
    local module_name="$2"
    local os="$3"
    local simulator="$4"
    local scope_suffix="$5"
    local version_suffix="$6"
    local config="$CONFIGURATION"

    local destination=""
    local os_name=""
    if [[ "$os" == "iphoneos" ]]; then
        os_name="ios"
        destination="iPhone 6"
    elif [[ "$os" == "watchos"  ]]; then
        os_name="$os"
        destination="Apple Watch - 42mm"
    elif [[ "$os" == "appletvos"  ]]; then
        os_name="tvos"
        if (( $(xcode_version_major) >= 9 )); then
            destination="Apple TV"
        else
            destination="Apple TV 1080p"
        fi
    fi

    # Derive build paths
    local build_products_path="build/DerivedData/Realm/Build/Products"
    local product_name="$module_name.framework"
    local binary_path="$module_name"
    local os_path="$build_products_path/$config-$os$scope_suffix/$product_name"
    local simulator_path="$build_products_path/$config-$simulator$scope_suffix/$product_name"
    local out_path="build/$os_name$scope_suffix$version_suffix"

    # Build for each platform
    xc "-scheme '$scheme' -configuration $config -sdk $os"
    xc "-scheme '$scheme' -configuration $config -sdk $simulator -destination 'name=$destination' ONLY_ACTIVE_ARCH=NO"

    # Combine .swiftmodule
    if [ -d $simulator_path/Modules/$module_name.swiftmodule ]; then
      cp $simulator_path/Modules/$module_name.swiftmodule/* $os_path/Modules/$module_name.swiftmodule/
    fi

    # Copy *.bcsymbolmap to .framework for submitting app with bitcode
    copy_bcsymbolmap "$build_products_path/$config-$os$scope_suffix" "$os_path"

    # Retrieve build products
    clean_retrieve $os_path $out_path $product_name

    # Combine ar archives
    LIPO_OUTPUT="$out_path/$product_name/$module_name"
    xcrun lipo -create "$simulator_path/$binary_path" "$os_path/$binary_path" -output "$LIPO_OUTPUT"

    if [[ "$destination" != "" && "$config" == "Release" ]]; then
        sh build.sh binary-has-bitcode "$LIPO_OUTPUT"
    fi
}

clean_retrieve() {
  mkdir -p "$2"
  rm -rf "$2/$3"
  cp -R "$1" "$2"
}

move_to_clean_dir() {
    rm -rf "$2"
    mkdir -p "$2"
    mv "$1" "$2"
}

test_ios_static() {
    destination="$1"
    xc "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' build"
    if (( $(xcode_version_major) < 9 )); then
        xc "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' test 'ARCHS=\$(ARCHS_STANDARD_32_BIT)'"
    fi

    # Xcode's depending tracking is lacking and it doesn't realize that the Realm static framework's static library
    # needs to be recreated when the active architectures change. Help Xcode out by removing the static library.
    settings=$(xcode "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' -showBuildSettings")
    path=$(echo "$settings" | awk '/CONFIGURATION_BUILD_DIR/ { cbd = $3; } /EXECUTABLE_PATH/ { ep = $3; } END { printf "%s/%s\n", cbd, ep; }')
    rm "$path"

    xc "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' test"
}

######################################
# Device Test Helper
######################################

test_devices() {
    local serial_numbers=()
    local awk_script="
    /^ +Vendor ID: / { is_apple = 0; }
    /^ +Vendor ID: 0x05[aA][cC] / { is_apple = 1; }
    /^ +Serial Number: / {
        if (is_apple) {
            match(\$0, /^ +Serial Number: /);
            print substr(\$0, RLENGTH + 1);
        }
    }
    "
    local serial_numbers_text=$(/usr/sbin/system_profiler SPUSBDataType | /usr/bin/awk "$awk_script")
    while read -r number; do
        if [[ "$number" != "" ]]; then
            serial_numbers+=("$number")
        fi
    done <<< "$serial_numbers_text"
    if [[ ${#serial_numbers[@]} == 0 ]]; then
        echo "At least one iOS/tvOS device must be connected to this computer to run device tests"
        if [ -z "${JENKINS_HOME}" ]; then
            # Don't fail if running locally and there's no device
            exit 0
        fi
        exit 1
    fi
    local sdk="$1"
    local scheme="$2"
    local configuration="$3"
    local failed=0
    for device in "${serial_numbers[@]}"; do
        xc "-scheme '$scheme' -configuration $configuration -destination 'id=$device' -sdk $sdk test" || failed=1
    done
    return $failed
}

######################################
# Docs
######################################

build_docs() {
    local language="$1"
    local version=$(sh build.sh get-version)

    local xcodebuild_arguments="--objc,Realm/Realm.h,--,-x,objective-c,-isysroot,$(xcrun --show-sdk-path),-I,$(pwd)"
    local module="Realm"
    local objc="--objc"

    if [[ "$language" == "swift" ]]; then
        sh build.sh set-swift-version
        xcodebuild_arguments="-scheme,RealmSwift"
        module="RealmSwift"
        objc=""
    fi

    touch Realm/RLMPlatform.h # jazzy will fail if it can't find all public header files
    jazzy \
      ${objc} \
      --clean \
      --author Realm \
      --author_url https://realm.io \
      --github_url https://github.com/realm/realm-cocoa \
      --github-file-prefix https://github.com/realm/realm-cocoa/tree/v${version} \
      --module-version ${version} \
      --xcodebuild-arguments ${xcodebuild_arguments} \
      --module ${module} \
      --root-url https://realm.io/docs/${language}/${version}/api/ \
      --output docs/${language}_output \
      --head "$(cat docs/custom_head.html)"

    rm Realm/RLMPlatform.h
}

######################################
# Input Validation
######################################

if [ "$#" -eq 0 -o "$#" -gt 3 ]; then
    usage
    exit 1
fi

######################################
# Downloading
######################################

kill_object_server() {
# Based on build.sh conventions we always run ROS from a path ending in 'ros/bin/ros'.
    pkill -f ros/bin/ros\ start
}

download_object_server() {
    rm -rf ./test-ros-instance
    mkdir -p ./test-ros-instance/ros
    chmod 777 ./test-ros-instance
    /usr/local/bin/node /usr/local/bin/npm install --scripts-prepend-node-path=auto --prefix ./test-ros-instance/ros \
        -g realm-object-server@${REALM_OBJECT_SERVER_VERSION}
}

download_common() {
    local download_type=$1 tries_left=3 version url error temp_dir temp_path tar_path

    if [ "$download_type" == "core" ]; then
        version=$REALM_CORE_VERSION
        url="https://static.realm.io/downloads/core/realm-core-${version}.tar.xz"
    elif [ "$download_type" == "sync" ]; then
        version=$REALM_SYNC_VERSION
        url="https://static.realm.io/downloads/sync/realm-sync-cocoa-${version}.tar.xz"
    else
        echo "Unknown dowload_type: $download_type"
        exit 1
    fi

    echo "Downloading dependency: ${download_type} ${version}"

    if [ -z "$TMPDIR" ]; then
        TMPDIR='/tmp'
    fi
    temp_dir=$(dirname "$TMPDIR/waste")/${download_type}_bin
    mkdir -p "$temp_dir"
    tar_path="${temp_dir}/${download_type}-${version}.tar.xz"
    temp_path="${tar_path}.tmp"

    while [ 0 -lt $tries_left ] && [ ! -f "$tar_path" ]; do
        if ! error=$(/usr/bin/curl --fail --silent --show-error --location "$url" --output "$temp_path" 2>&1); then
            tries_left=$[$tries_left-1]
        else
            mv "$temp_path" "$tar_path"
        fi
    done

    if [ ! -f "$tar_path" ]; then
        printf "Downloading ${download_type} failed:\n\t$url\n\t$error\n"
        exit 1
    fi

    (
        cd "$temp_dir"
        rm -rf "$download_type"
        tar xf "$tar_path" --xz
        mv core "${download_type}-${version}"
    )

    rm -rf "${download_type}-${version}" core
    mv "${temp_dir}/${download_type}-${version}" .
    ln -s "${download_type}-${version}" core
}

download_core() {
    download_common "core"
}

download_sync() {
    download_common "sync"
}

######################################
# Variables
######################################

COMMAND="$1"

# Use Debug config if command ends with -debug, otherwise default to Release
# Set IS_RUNNING_PACKAGING when running packaging steps to avoid running iOS static tests with Xcode 8.3.3
case "$COMMAND" in
    *-debug)
        COMMAND="${COMMAND%-debug}"
        CONFIGURATION="Debug"
        ;;
    package-*)
        IS_RUNNING_PACKAGING=1
        ;;
esac
export CONFIGURATION=${CONFIGURATION:-Release}
export IS_RUNNING_PACKAGING=${IS_RUNNING_PACKAGING:-0}

# Pre-choose Xcode and Swift versions for those operations that do not set them
REALM_XCODE_VERSION=${xcode_version:-$REALM_XCODE_VERSION}
REALM_SWIFT_VERSION=${swift_version:-$REALM_SWIFT_VERSION}
source "${source_root}/scripts/swift-version.sh"
set_xcode_and_swift_versions

######################################
# Commands
######################################

case "$COMMAND" in

    ######################################
    # Clean
    ######################################
    "clean")
        find . -type d -name build -exec rm -r "{}" +
        exit 0
        ;;

    ######################################
    # Object Server
    ######################################
    "download-object-server")
        download_object_server
        exit 0
        ;;

    "reset-ros-server-state")
        rm -rf "./test-ros-instance/data"
        rm -rf "./test-ros-instance/realm-object-server"
        exit 0
        ;;

    "reset-ros-client-state")
        rm -rf ~/Library/Application\ Support/xctest
        rm -rf ~/Library/Application\ Support/io.realm.TestHost
        rm -rf ~/Library/Application\ Support/xctest-child
        exit 0
        ;;

    "reset-object-server")
        kill_object_server
        # Add a short delay, so file system doesn't complain about files in use
        sleep 1
        sh build.sh reset-ros-server-state
        sh build.sh reset-ros-client-state
        # Add another delay to ensure files are actually gone from file system
        sleep 1
        exit 0
        ;;

    ######################################
    # Core
    ######################################
    "download-core")
        if [ "$REALM_CORE_VERSION" = "current" ]; then
            echo "Using version of core already in core/ directory"
            exit 0
        fi
        if [ -d core -a -d ../realm-core -a ! -L core ]; then
          # Allow newer versions than expected for local builds as testing
          # with unreleased versions is one of the reasons to use a local build
          if ! $(grep -i "${REALM_CORE_VERSION} Release notes" core/release_notes.txt >/dev/null); then
              echo "Local build of core is out of date."
              exit 1
          else
              echo "The core library seems to be up to date."
          fi
        elif ! [ -L core ]; then
            echo "core is not a symlink. Deleting..."
            rm -rf core
            download_core
        # With a prebuilt version we only want to check the first non-empty
        # line so that checking out an older commit will download the
        # appropriate version of core if the already-present version is too new
        elif ! $(grep -m 1 . core/release_notes.txt | grep -i "${REALM_CORE_VERSION} RELEASE NOTES" >/dev/null); then
            download_core
        else
            echo "The core library seems to be up to date."
        fi
        exit 0
        ;;

    ######################################
    # Sync
    ######################################
    "download-sync")
        if [ "$REALM_SYNC_VERSION" = "current" ]; then
            echo "Using version of core already in core/ directory"
            exit 0
        fi
        if [ -d core -a -d ../realm-core -a -d ../realm-sync -a ! -L core ]; then
          echo "Using version of core already in core/ directory"
        elif ! [ -L core ]; then
            echo "core is not a symlink. Deleting..."
            rm -rf core
            download_sync
        elif [[ "$(cat core/version.txt)" != "$REALM_SYNC_VERSION" ]]; then
            download_sync
        else
            echo "The core library seems to be up to date."
        fi
        exit 0
        ;;

    ######################################
    # Swift versioning
    ######################################
    "set-swift-version")
        version=${2:-$REALM_SWIFT_VERSION}

        SWIFT_VERSION_FILE="RealmSwift/SwiftVersion.swift"
        CONTENTS="let swiftLanguageVersion = \"$version\""
        if [ ! -f "$SWIFT_VERSION_FILE" ] || ! grep -q "$CONTENTS" "$SWIFT_VERSION_FILE"; then
            echo "$CONTENTS" > "$SWIFT_VERSION_FILE"
        fi

        exit 0
        ;;

    "prelaunch-simulator")
        sh ${source_root}/scripts/reset-simulators.sh
        ;;

    ######################################
    # Building
    ######################################
    "build")
        sh build.sh ios-static
        sh build.sh ios-dynamic
        sh build.sh ios-swift
        sh build.sh watchos
        sh build.sh watchos-swift
        sh build.sh tvos
        sh build.sh tvos-swift
        sh build.sh osx
        sh build.sh osx-swift
        exit 0
        ;;

    "ios-static")
        build_combined 'Realm iOS static' Realm iphoneos iphonesimulator "-static"
        exit 0
        ;;

    "ios-dynamic")
        build_combined Realm Realm iphoneos iphonesimulator
        exit 0
        ;;

    "ios-swift")
        sh build.sh ios-dynamic
        build_combined RealmSwift RealmSwift iphoneos iphonesimulator '' "/swift-$REALM_SWIFT_VERSION"
        cp -R build/ios/Realm.framework build/ios/swift-$REALM_SWIFT_VERSION
        exit 0
        ;;

    "watchos")
        build_combined Realm Realm watchos watchsimulator
        exit 0
        ;;

    "watchos-swift")
        sh build.sh watchos
        build_combined RealmSwift RealmSwift watchos watchsimulator '' "/swift-$REALM_SWIFT_VERSION"
        cp -R build/watchos/Realm.framework build/watchos/swift-$REALM_SWIFT_VERSION
        exit 0
        ;;

    "tvos")
        build_combined Realm Realm appletvos appletvsimulator
        exit 0
        ;;

    "tvos-swift")
        sh build.sh tvos
        build_combined RealmSwift RealmSwift appletvos appletvsimulator '' "/swift-$REALM_SWIFT_VERSION"
        cp -R build/tvos/Realm.framework build/tvos/swift-$REALM_SWIFT_VERSION
        exit 0
        ;;

    "osx")
        xc "-scheme Realm -configuration $CONFIGURATION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/Realm.framework" "build/osx" "Realm.framework"
        exit 0
        ;;

    "osx-swift")
        sh build.sh osx
        xc "-scheme 'RealmSwift' -configuration $CONFIGURATION build"
        destination="build/osx/swift-$REALM_SWIFT_VERSION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/RealmSwift.framework" "$destination" "RealmSwift.framework"
        cp -R build/osx/Realm.framework "$destination"
        exit 0
        ;;

    ######################################
    # Analysis
    ######################################

    "analyze-osx")
        xc "-scheme Realm -configuration $CONFIGURATION analyze"
        exit 0
        ;;

    ######################################
    # Testing
    ######################################
    "test")
        set +e # Run both sets of tests even if the first fails
        failed=0
        sh build.sh test-ios-static || failed=1
        sh build.sh test-ios-dynamic || failed=1
        sh build.sh test-ios-swift || failed=1
        sh build.sh test-ios-devices || failed=1
        sh build.sh test-tvos-devices || failed=1
        sh build.sh test-osx || failed=1
        sh build.sh test-osx-swift || failed=1
        exit $failed
        ;;

    "test-all")
        set +e
        failed=0
        sh build.sh test || failed=1
        sh build.sh test-debug || failed=1
        exit $failed
        ;;

    "test-ios-static")
        test_ios_static "name=iPhone 6"
        exit 0
        ;;

    "test-ios-dynamic")
        xc "-scheme Realm -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' build"
        if (( $(xcode_version_major) < 9 )); then
            xc "-scheme Realm -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' test 'ARCHS=\$(ARCHS_STANDARD_32_BIT)'"
        fi
        xc "-scheme Realm -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' test"
        exit 0
        ;;

    "test-ios-swift")
        xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' build"
        if (( $(xcode_version_major) < 9 )); then
            xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' test 'ARCHS=\$(ARCHS_STANDARD_32_BIT)'"
        fi
        xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 6' test"
        exit 0
        ;;

    "test-ios-devices")
        failed=0
        trap "failed=1" ERR
        sh build.sh test-ios-devices-objc
        sh build.sh test-ios-devices-swift
        exit $failed
        ;;

    "test-ios-devices-objc")
        test_devices iphoneos "Realm" "$CONFIGURATION"
        exit $?
        ;;

    "test-ios-devices-swift")
        test_devices iphoneos "RealmSwift" "$CONFIGURATION"
        exit $?
        ;;

    "test-tvos")
        if (( $(xcode_version_major) >= 9 )); then
            destination="Apple TV"
        else
            destination="Apple TV 1080p"
        fi
        xc "-scheme Realm -configuration $CONFIGURATION -sdk appletvsimulator -destination 'name=$destination' test"
        exit $?
        ;;

    "test-tvos-swift")
        if (( $(xcode_version_major) >= 9 )); then
            destination="Apple TV"
        else
            destination="Apple TV 1080p"
        fi
        xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk appletvsimulator -destination 'name=$destination' test"
        exit $?
        ;;

    "test-tvos-devices")
        test_devices appletvos TestHost "$CONFIGURATION"
        ;;

    "test-osx")
        COVERAGE_PARAMS=""
        if [[ "$CONFIGURATION" == "Debug" ]]; then
            COVERAGE_PARAMS="GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES"
        fi
        xc "-scheme Realm -configuration $CONFIGURATION test $COVERAGE_PARAMS"
        exit 0
        ;;

    "test-osx-swift")
        xc "-scheme RealmSwift -configuration $CONFIGURATION test"
        exit 0
        ;;

    "test-osx-object-server")
        xc "-scheme 'Object Server Tests' -configuration $CONFIGURATION -sdk macosx test \
            -skip-testing:ObjectServerTests/RLMObjectServerTests/testUsernamePasswordAuthenticationWithReconnection \
            -skip-testing:ObjectServerTests/RLMObjectServerTests/testAddObjectsWithReconnection \
            -skip-testing:ObjectServerTests/RLMObjectServerTests/testDownloadRealmWithReconnection"
        exit 0
        ;;

    "test-osx-object-server-poor-network")
        xc "-scheme 'Object Server Tests' -configuration $CONFIGURATION -sdk macosx test \
            -only-testing:ObjectServerTests/RLMObjectServerTests/testUsernamePasswordAuthenticationWithReconnection \
            -only-testing:ObjectServerTests/RLMObjectServerTests/testAddObjectsWithReconnection \
            -only-testing:ObjectServerTests/RLMObjectServerTests/testDownloadRealmWithReconnection"
        exit 0
        ;;

    ######################################
    # Full verification
    ######################################
    "verify")
        sh build.sh verify-cocoapods
        sh build.sh verify-docs
        sh build.sh verify-osx
        sh build.sh verify-osx-debug
        sh build.sh verify-osx-swift
        sh build.sh verify-osx-swift-debug
        sh build.sh verify-ios-static
        sh build.sh verify-ios-static-debug
        sh build.sh verify-ios-dynamic
        sh build.sh verify-ios-dynamic-debug
        sh build.sh verify-ios-swift
        sh build.sh verify-ios-swift-debug
        sh build.sh verify-ios-device-objc
        sh build.sh verify-ios-device-swift
        sh build.sh verify-watchos
        sh build.sh verify-tvos
        sh build.sh verify-tvos-debug
        sh build.sh verify-tvos-device
        sh build.sh verify-swiftlint
        sh build.sh verify-osx-object-server
        ;;

    "verify-cocoapods")
        if [[ -d .git ]]; then
          # Verify the current branch, unless one was already specified in the sha environment variable.
          if [[ -z $sha ]]; then
            export sha=$(git rev-parse --abbrev-ref HEAD)
          fi

          if [[ $(git log -1 @{push}..) != "" ]] || ! git diff-index --quiet HEAD; then
            echo "WARNING: verify-cocoapods will test the latest revision of $sha found on GitHub."
            echo "         Any unpushed local changes will not be tested."
            echo ""
            sleep 1
          fi
        fi

        cd examples/installation
        sh build.sh test-ios-objc-cocoapods
        sh build.sh test-ios-objc-cocoapods-dynamic
        sh build.sh test-ios-swift-cocoapods
        sh build.sh test-osx-objc-cocoapods
        sh build.sh test-osx-swift-cocoapods
        sh build.sh test-watchos-objc-cocoapods
        sh build.sh test-watchos-swift-cocoapods
        ;;

    "verify-osx-encryption")
        REALM_ENCRYPT_ALL=YES sh build.sh test-osx
        exit 0
        ;;

    "verify-osx")
        sh build.sh test-osx
        sh build.sh analyze-osx
        sh build.sh examples-osx

        (
            cd examples/osx/objc/build/DerivedData/RealmExamples/Build/Products/$CONFIGURATION
            DYLD_FRAMEWORK_PATH=. ./JSONImport >/dev/null
        )
        exit 0
        ;;

    "verify-osx-swift")
        sh build.sh test-osx-swift
        exit 0
        ;;

    "verify-ios-static")
        sh build.sh test-ios-static
        sh build.sh examples-ios
        ;;

    "verify-ios-dynamic")
        sh build.sh test-ios-dynamic
        ;;

    "verify-ios-swift")
        sh build.sh test-ios-swift
        sh build.sh examples-ios-swift
        ;;

    "verify-ios-device-objc")
        sh build.sh test-ios-devices-objc
        exit 0
        ;;

    "verify-ios-device-swift")
        sh build.sh test-ios-devices-swift
        exit 0
        ;;

    "verify-docs")
        sh build.sh docs
        for lang in swift objc; do
            undocumented="docs/${lang}_output/undocumented.json"
            if ruby -rjson -e "j = JSON.parse(File.read('docs/${lang}_output/undocumented.json')); exit j['warnings'].length != 0"; then
              echo "Undocumented Realm $lang declarations:"
              cat "$undocumented"
              exit 1
            fi
        done
        exit 0
        ;;

    "verify-watchos")
        sh build.sh watchos-swift
        exit 0
        ;;

    "verify-tvos")
        sh build.sh test-tvos
        sh build.sh test-tvos-swift
        sh build.sh examples-tvos
        sh build.sh examples-tvos-swift
        exit 0
        ;;

    "verify-tvos-device")
        sh build.sh test-tvos-devices
        exit 0
        ;;

    "verify-swiftlint")
        swiftlint lint --strict
        exit 0
        ;;

    "verify-osx-object-server")
        sh build.sh download-object-server
        sh build.sh test-osx-object-server
        sh build.sh reset-object-server
        exit 0
        ;;

    "verify-osx-object-server-poor-network")
        sh build.sh download-object-server
        sh build.sh test-osx-object-server-poor-network
        sh build.sh reset-object-server
        exit 0
        ;;

    ######################################
    # Docs
    ######################################
    "docs")
        build_docs objc
        build_docs swift
        exit 0
        ;;

    ######################################
    # Examples
    ######################################
    "examples")
        sh build.sh clean
        sh build.sh examples-ios
        sh build.sh examples-ios-swift
        sh build.sh examples-osx
        sh build.sh examples-tvos
        sh build.sh examples-tvos-swift
        exit 0
        ;;

    "examples-ios")
        sh build.sh prelaunch-simulator
        workspace="examples/ios/objc/RealmExamples.xcworkspace"
        pod install --project-directory="$workspace/.." --no-repo-update
        xc "-workspace $workspace -scheme Simple -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme TableView -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Migration -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Backlink -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme GroupedTableView -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme RACTableView -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Encryption -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Draw -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"

        if [ ! -z "${JENKINS_HOME}" ]; then
            xc "-workspace $workspace -scheme Extension -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        fi

        exit 0
        ;;

    "examples-ios-swift")
        sh build.sh prelaunch-simulator
        workspace="examples/ios/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_SWIFT_VERSION}"
        fi

        xc "-workspace $workspace -scheme Simple -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme TableView -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Migration -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Encryption -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Backlink -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme GroupedTableView -configuration $CONFIGURATION -destination 'name=iPhone 6' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    "examples-osx")
        xc "-workspace examples/osx/objc/RealmExamples.xcworkspace -scheme JSONImport -configuration ${CONFIGURATION} build ${CODESIGN_PARAMS}"
        ;;

    "examples-tvos")
        workspace="examples/tvos/objc/RealmExamples.xcworkspace"
        if (( $(xcode_version_major) >= 9 )); then
            destination="Apple TV"
        else
            destination="Apple TV 1080p"
        fi

        xc "-workspace $workspace -scheme DownloadCache -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme PreloadedData -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    "examples-tvos-swift")
        workspace="examples/tvos/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_SWIFT_VERSION}"
        fi

        if (( $(xcode_version_major) >= 9 )); then
            destination="Apple TV"
        else
            destination="Apple TV 1080p"
        fi

        xc "-workspace $workspace -scheme DownloadCache -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme PreloadedData -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    ######################################
    # Versioning
    ######################################
    "get-version")
        version_file="Realm/Realm-Info.plist"
        echo "$(PlistBuddy -c "Print :CFBundleShortVersionString" "$version_file")"
        exit 0
        ;;

    "set-version")
        realm_version="$2"
        version_files="Realm/Realm-Info.plist"

        if [ -z "$realm_version" ]; then
            echo "You must specify a version."
            exit 1
        fi
        # The bundle version can contain only three groups of digits separated by periods,
        # so strip off any -beta.x tag from the end of the version string.
        bundle_version=$(echo "$realm_version" | cut -d - -f 1)
        for version_file in $version_files; do
            PlistBuddy -c "Set :CFBundleVersion $bundle_version" "$version_file"
            PlistBuddy -c "Set :CFBundleShortVersionString $realm_version" "$version_file"
        done
        sed -i '' "s/^VERSION=.*/VERSION=$realm_version/" dependencies.list
        exit 0
        ;;

    ######################################
    # Bitcode Detection
    ######################################

    "binary-has-bitcode")
        BINARY="$2"
        # Although grep has a '-q' flag to prevent logging to stdout, grep
        # behaves differently when used, so redirect stdout to /dev/null.
        if otool -l "$BINARY" | grep "segname __LLVM" > /dev/null 2>&1; then
            exit 0
        fi
        # Work around rdar://21826157 by checking for bitcode in thin binaries

        # Get architectures for binary
        archs="$(lipo -info "$BINARY" | rev | cut -d ':' -f1 | rev)"

        archs_array=( $archs )
        if [[ ${#archs_array[@]} -lt 2 ]]; then
            exit 1 # Early exit if not a fat binary
        fi

        TEMPDIR=$(mktemp -d $TMPDIR/realm-bitcode-check.XXXX)

        for arch in $archs; do
            lipo -thin "$arch" "$BINARY" -output "$TEMPDIR/$arch"
            if otool -l "$TEMPDIR/$arch" | grep -q "segname __LLVM"; then
                exit 0
            fi
        done
        exit 1
        ;;

    ######################################
    # CocoaPods
    ######################################
    "cocoapods-setup")
        if [ ! -d core ]; then
          sh build.sh download-sync
          rm core
          mv sync-* core
          mv core/librealm-ios.a core/librealmcore-ios.a
          mv core/librealm-macosx.a core/librealmcore-macosx.a
          mv core/librealm-tvos.a core/librealmcore-tvos.a
          mv core/librealm-watchos.a core/librealmcore-watchos.a
        fi

        if [[ "$2" != "swift" ]]; then
          if [ ! -d Realm/ObjectStore/src ]; then
            cat >&2 <<EOM


ERROR: One of Realm's submodules is missing!

If you're using Realm and/or RealmSwift from a git branch, please add 'submodules: true' to
their entries in your Podfile.


EOM
            exit 1
          fi

          rm -rf include
          mkdir -p include
          mv core/include include/core

          mkdir -p include/impl/apple include/util/apple include/sync/impl/apple
          cp Realm/*.hpp include
          cp Realm/ObjectStore/src/*.hpp include
          cp Realm/ObjectStore/src/sync/*.hpp include/sync
          cp Realm/ObjectStore/src/sync/impl/*.hpp include/sync/impl
          cp Realm/ObjectStore/src/sync/impl/apple/*.hpp include/sync/impl/apple
          cp Realm/ObjectStore/src/impl/*.hpp include/impl
          cp Realm/ObjectStore/src/impl/apple/*.hpp include/impl/apple
          cp Realm/ObjectStore/src/util/*.hpp include/util
          cp Realm/ObjectStore/src/util/apple/*.hpp include/util/apple

          touch Realm/RLMPlatform.h
          if [ -n "$COCOAPODS_VERSION" ]; then
            # This variable is set for the prepare_command available
            # from the 1.0 prereleases, which requires a different
            # header layout within the header_mappings_dir.
            cp Realm/*.h include
          else
            # For CocoaPods < 1.0, we need to scope the headers within
            # the header_mappings_dir by another subdirectory to avoid
            # Clang from complaining about non-modular headers.
            mkdir -p include/Realm
            cp Realm/*.h include/Realm
          fi
        else
          sh build.sh set-swift-version
        fi
        ;;

    ######################################
    # Continuous Integration
    ######################################

    "ci-pr")
        mkdir -p build/reports
        # FIXME: Re-enable once CI can properly unlock the keychain
        export REALM_DISABLE_METADATA_ENCRYPTION=1

        # strip off the ios|tvos version specifier, e.g. the last part of: `ios-device-objc-ios8`
        if [[ "$target" =~ ^((ios|tvos)-device(-(objc|swift))?)(-(ios|tvos)[[:digit:]]+)?$ ]]; then
            export target=${BASH_REMATCH[1]}
        fi

        if [ "$target" = "docs" ]; then
            sh build.sh set-swift-version
            sh build.sh verify-docs
        elif [ "$target" = "swiftlint" ]; then
            sh build.sh verify-swiftlint
        else
            export sha=$GITHUB_PR_SOURCE_BRANCH
            export CONFIGURATION=$configuration
            export REALM_EXTRA_BUILD_ARGUMENTS='GCC_GENERATE_DEBUGGING_SYMBOLS=NO REALM_PREFIX_HEADER=Realm/RLMPrefix.h'
            sh build.sh prelaunch-simulator

            # Reset CoreSimulator.log
            mkdir -p ~/Library/Logs/CoreSimulator
            echo > ~/Library/Logs/CoreSimulator/CoreSimulator.log

            if [ -d ~/Library/Developer/CoreSimulator/Devices/ ]; then
                # Verify that no Realm files still exist
                ! find ~/Library/Developer/CoreSimulator/Devices/ -name '*.realm' | grep -q .
            fi

            failed=0
            sh build.sh verify-$target 2>&1 | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            if [ "$failed" = "1" ] && cat build/build.log | grep -E 'DTXProxyChannel|DTXChannel|out of date and needs to be rebuilt|operation never finished bootstrapping'; then
                echo "Known Xcode error detected. Running job again."
                if cat build/build.log | grep -E 'out of date and needs to be rebuilt'; then
                    rm -rf build/DerivedData
                fi
                failed=0
                sh build.sh verify-$target | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            elif [ "$failed" = "1" ] && tail ~/Library/Logs/CoreSimulator/CoreSimulator.log | grep -E "Operation not supported|Failed to lookup com.apple.coreservices.lsuseractivity.simulatorsupport"; then
                echo "Known Xcode error detected. Running job again."
                failed=0
                sh build.sh verify-$target | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            fi
            if [ "$failed" = "1" ]; then
                echo "\n\n***\nbuild/build.log\n***\n\n" && cat build/build.log || true
                echo "\n\n***\nCoreSimulator.log\n***\n\n" && cat ~/Library/Logs/CoreSimulator/CoreSimulator.log
                exit 1
            fi
        fi

        if [ "$target" = "osx" ] && [ "$configuration" = "Debug" ]; then
          gcovr -r . -f ".*Realm.*" -e ".*Tests.*" -e ".*core.*" --xml > build/reports/coverage-report.xml
          WS=$(pwd | sed "s/\//\\\\\//g")
          sed -i ".bak" "s/<source>\./<source>${WS}/" build/reports/coverage-report.xml
        fi
        ;;

    ######################################
    # Release packaging
    ######################################

    "package-examples")
        ./scripts/package_examples.rb
        zip --symlinks -r realm-examples.zip examples -x "examples/installation/*"
        ;;

    "package-test-examples")
        if ! VERSION=$(echo realm-objc-*.zip | egrep -o '\d*\.\d*\.\d*-[a-z]*(\.\d*)?'); then
            VERSION=$(echo realm-objc-*.zip | egrep -o '\d*\.\d*\.\d*')
        fi
        OBJC="realm-objc-${VERSION}"
        SWIFT="realm-swift-${VERSION}"
        unzip ${OBJC}.zip

        cp $0 ${OBJC}
        cp -r ${source_root}/scripts ${OBJC}
        cd ${OBJC}
        sh build.sh examples-ios
        sh build.sh examples-tvos
        sh build.sh examples-osx
        cd ..
        rm -rf ${OBJC}

        unzip ${SWIFT}.zip

        cp $0 ${SWIFT}
        cp -r ${source_root}/scripts ${SWIFT}
        cd ${SWIFT}
        sh build.sh examples-ios-swift
        sh build.sh examples-tvos-swift
        cd ..
        rm -rf ${SWIFT}
        ;;

    "package-ios-static")
        sh build.sh prelaunch-simulator
        sh build.sh ios-static

        cd build/ios-static
        zip --symlinks -r realm-framework-ios-static.zip Realm.framework
        ;;

    "package-ios")
        sh build.sh prelaunch-simulator
        sh build.sh ios-dynamic
        cd build/ios
        zip --symlinks -r realm-framework-ios.zip Realm.framework
        ;;

    "package-osx")
        sh build.sh osx

        cd build/DerivedData/Realm/Build/Products/Release
        zip --symlinks -r realm-framework-osx.zip Realm.framework
        ;;

    "package-ios-swift")
        for version in 8.3.3 9.0 9.1 9.2; do
            REALM_XCODE_VERSION=$version
            REALM_SWIFT_VERSION=
            set_xcode_and_swift_versions
            sh build.sh prelaunch-simulator
            sh build.sh ios-swift
        done

        cd build/ios
        ln -s swift-4.0 swift-3.2
        ln -s swift-4.0.2 swift-3.2.2
        ln -s swift-4.0.2 swift-3.2.3
        ln -s swift-4.0.2 swift-4.0.3
        zip --symlinks -r realm-swift-framework-ios.zip swift-3.1 swift-3.2 swift-3.2.2 swift-3.2.3 swift-4.0 swift-4.0.2 swift-4.0.3
        ;;

    "package-osx-swift")
        for version in 8.3.3 9.0 9.1 9.2; do
            REALM_XCODE_VERSION=$version
            REALM_SWIFT_VERSION=
            set_xcode_and_swift_versions
            sh build.sh prelaunch-simulator
            sh build.sh osx-swift
        done

        cd build/osx
        ln -s swift-4.0 swift-3.2
        ln -s swift-4.0.2 swift-3.2.2
        ln -s swift-4.0.2 swift-3.2.3
        ln -s swift-4.0.2 swift-4.0.3
        zip --symlinks -r realm-swift-framework-osx.zip swift-3.1 swift-3.2 swift-3.2.2 swift-3.2.3 swift-4.0 swift-4.0.2 swift-4.0.3
        ;;

    "package-watchos")
        sh build.sh prelaunch-simulator
        sh build.sh watchos

        cd build/watchos
        zip --symlinks -r realm-framework-watchos.zip Realm.framework
        ;;

    "package-watchos-swift")
        for version in 8.3.3 9.0 9.1 9.2; do
            REALM_XCODE_VERSION=$version
            REALM_SWIFT_VERSION=
            set_xcode_and_swift_versions
            sh build.sh prelaunch-simulator
            sh build.sh watchos-swift
        done

        cd build/watchos
        ln -s swift-4.0 swift-3.2
        ln -s swift-4.0.2 swift-3.2.2
        ln -s swift-4.0.2 swift-3.2.3
        ln -s swift-4.0.2 swift-4.0.3
        zip --symlinks -r realm-swift-framework-watchos.zip swift-3.1 swift-3.2 swift-3.2.2 swift-3.2.3 swift-4.0 swift-4.0.2 swift-4.0.3
        ;;

    "package-tvos")
        sh build.sh prelaunch-simulator
        sh build.sh tvos

        cd build/tvos
        zip --symlinks -r realm-framework-tvos.zip Realm.framework
        ;;

    "package-tvos-swift")
        for version in 8.3.3 9.0 9.1 9.2; do
            REALM_XCODE_VERSION=$version
            REALM_SWIFT_VERSION=
            set_xcode_and_swift_versions
            sh build.sh prelaunch-simulator
            sh build.sh tvos-swift
        done

        cd build/tvos
        ln -s swift-4.0 swift-3.2
        ln -s swift-4.0.2 swift-3.2.2
        ln -s swift-4.0.2 swift-3.2.3
        ln -s swift-4.0.2 swift-4.0.3
        zip --symlinks -r realm-swift-framework-tvos.zip swift-3.1 swift-3.2 swift-3.2.2 swift-3.2.3 swift-4.0 swift-4.0.2 swift-4.0.3
        ;;

    package-*-swift-3.2)
        PLATFORM=$(echo $COMMAND | cut -d - -f 2)
        mkdir -p build/$PLATFORM
        cd build/$PLATFORM
        ln -s swift-4.0 swift-3.2
        zip --symlinks -r realm-swift-framework-$PLATFORM-swift-3.2.zip swift-3.2
        ;;

    package-*-swift-3.2.2)
        PLATFORM=$(echo $COMMAND | cut -d - -f 2)
        mkdir -p build/$PLATFORM
        cd build/$PLATFORM
        ln -s swift-4.0.2 swift-3.2.2
        zip --symlinks -r realm-swift-framework-$PLATFORM-swift-3.2.2.zip swift-3.2.2
        ;;

    package-*-swift-3.2.3)
        PLATFORM=$(echo $COMMAND | cut -d - -f 2)
        mkdir -p build/$PLATFORM
        cd build/$PLATFORM
        ln -s swift-4.0.2 swift-3.2.3
        zip --symlinks -r realm-swift-framework-$PLATFORM-swift-3.2.3.zip swift-3.2.3
        ;;

    package-*-swift-4.0.3)
        PLATFORM=$(echo $COMMAND | cut -d - -f 2)
        mkdir -p build/$PLATFORM
        cd build/$PLATFORM
        ln -s swift-4.0.2 swift-4.0.3
        zip --symlinks -r realm-swift-framework-$PLATFORM-swift-4.0.3.zip swift-4.0.3
        ;;

    package-*-swift-*)
        PLATFORM=$(echo $COMMAND | cut -d - -f 2)
        REALM_SWIFT_VERSION=$(echo $COMMAND | cut -d - -f 4)
        REALM_XCODE_VERSION=

        set_xcode_and_swift_versions
        sh build.sh prelaunch-simulator
        sh build.sh $PLATFORM-swift

        cd build/$PLATFORM
        zip --symlinks -r realm-swift-framework-$PLATFORM-swift-$REALM_SWIFT_VERSION.zip swift-$REALM_SWIFT_VERSION
        ;;

    "package-release")
        LANG="$2"
        TEMPDIR=$(mktemp -d $TMPDIR/realm-release-package-${LANG}.XXXX)

        VERSION=$(sh build.sh get-version)

        FOLDER=${TEMPDIR}/realm-${LANG}-${VERSION}

        mkdir -p ${FOLDER}/osx ${FOLDER}/ios ${FOLDER}/watchos ${FOLDER}/tvos

        if [[ "${LANG}" == "objc" ]]; then
            mkdir -p ${FOLDER}/ios/static
            mkdir -p ${FOLDER}/ios/dynamic
            mkdir -p ${FOLDER}/Swift

            (
                cd ${FOLDER}/osx
                unzip ${WORKSPACE}/realm-framework-osx.zip
            )

            (
                cd ${FOLDER}/ios/static
                unzip ${WORKSPACE}/realm-framework-ios-static.zip
            )

            (
                cd ${FOLDER}/ios/dynamic
                unzip ${WORKSPACE}/realm-framework-ios.zip
            )

            (
                cd ${FOLDER}/watchos
                unzip ${WORKSPACE}/realm-framework-watchos.zip
            )

            (
                cd ${FOLDER}/tvos
                unzip ${WORKSPACE}/realm-framework-tvos.zip
            )
        else
            (
                cd ${FOLDER}/osx
                for f in ${WORKSPACE}/realm-swift-framework-osx-swift-*.zip; do
                    unzip "$f"
                done
            )

            (
                cd ${FOLDER}/ios
                for f in ${WORKSPACE}/realm-swift-framework-ios-swift-*.zip; do
                    unzip "$f"
                done
            )

            (
                cd ${FOLDER}/watchos
                for f in ${WORKSPACE}/realm-swift-framework-watchos-swift-*.zip; do
                    unzip "$f"
                done
            )

            (
                cd ${FOLDER}/tvos
                for f in ${WORKSPACE}/realm-swift-framework-tvos-swift-*.zip; do
                    unzip "$f"
                done
            )
        fi

        (
            cd ${WORKSPACE}
            cp -R plugin ${FOLDER}
            cp LICENSE ${FOLDER}/LICENSE.txt
            if [[ "${LANG}" == "objc" ]]; then
                cp Realm/Swift/RLMSupport.swift ${FOLDER}/Swift/
            fi
        )

        (
            cd ${FOLDER}
            unzip ${WORKSPACE}/realm-examples.zip
            cd examples
            if [[ "${LANG}" == "objc" ]]; then
                rm -rf ios/swift-* tvos/swift-*
            else
                rm -rf ios/objc ios/rubymotion osx tvos/objc
            fi
        )

        cat > ${FOLDER}/docs.webloc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>https://realm.io/docs/${LANG}/${VERSION}</string>
</dict>
</plist>
EOF

        (
          cd ${TEMPDIR}
          zip --symlinks -r realm-${LANG}-${VERSION}.zip realm-${LANG}-${VERSION}
          mv realm-${LANG}-${VERSION}.zip ${WORKSPACE}
        )
        ;;

    "test-package-release")
        # Generate a release package locally for testing purposes
        # Real releases should always be done via Jenkins
        if [ -z "${WORKSPACE}" ]; then
            echo 'WORKSPACE must be set to a directory to assemble the release in'
            exit 1
        fi
        if [ -d "${WORKSPACE}" ]; then
            echo 'WORKSPACE directory should not already exist'
            exit 1
        fi

        REALM_SOURCE="$(pwd)"
        mkdir -p "$WORKSPACE"
        WORKSPACE="$(cd "$WORKSPACE" && pwd)"
        export WORKSPACE
        cd $WORKSPACE
        git clone --recursive $REALM_SOURCE realm-cocoa
        cd realm-cocoa

        echo 'Packaging iOS'
        sh build.sh package-ios-static
        cp build/ios-static/realm-framework-ios-static.zip ..
        sh build.sh package-ios
        cp build/ios/realm-framework-ios.zip ..
        sh build.sh package-ios-swift
        cp build/ios/realm-swift-framework-ios.zip ..

        echo 'Packaging OS X'
        sh build.sh package-osx
        cp build/DerivedData/Realm/Build/Products/Release/realm-framework-osx.zip ..
        sh build.sh package-osx-swift
        cp build/osx/realm-swift-framework-osx.zip ..

        echo 'Packaging watchOS'
        sh build.sh package-watchos
        cp build/watchos/realm-framework-watchos.zip ..
        sh build.sh package-watchos-swift
        cp build/watchos/realm-swift-framework-watchos.zip ..

        echo 'Packaging tvOS'
        sh build.sh package-tvos
        cp build/tvos/realm-framework-tvos.zip ..
        sh build.sh package-tvos-swift
        cp build/tvos/realm-swift-framework-tvos.zip ..

        echo 'Packaging examples'
        sh build.sh package-examples
        cp realm-examples.zip ..

        echo 'Building final release packages'
        sh build.sh package-release objc
        sh build.sh package-release swift

        echo 'Testing packaged examples'
        sh build.sh package-test-examples
        ;;

    "github-release")
        if [ -z "${GITHUB_ACCESS_TOKEN}" ]; then
            echo 'GITHUB_ACCESS_TOKEN must be set to create GitHub releases'
            exit 1
        fi
        ./scripts/github_release.rb
        ;;

    "add-empty-changelog")
        empty_section=$(cat <<EOS
x.x.x Release notes (yyyy-MM-dd)
=============================================================

### Breaking Changes

* None.

### Enhancements

* None.

### Bugfixes

* None.
EOS)
        changelog=$(cat CHANGELOG.md)
        echo "$empty_section" > CHANGELOG.md
        echo >> CHANGELOG.md
        echo "$changelog" >> CHANGELOG.md
        ;;

    *)
        echo "Unknown command '$COMMAND'"
        usage
        exit 1
        ;;
esac
