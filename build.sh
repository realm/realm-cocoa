#!/bin/bash

##################################################################################
# Custom build tool for Realm Objective-C binding.
#
# (C) Copyright 2011-2015 by realm.io.
##################################################################################

# Warning: pipefail is not a POSIX compatible option, but on macOS it works just fine.
#          macOS uses a POSIX complain version of bash as /bin/sh, but apparently it does
#          not strip away this feature. Also, this will fail if somebody forces the script
#          to be run with zsh.
set -o pipefail
set -e

readonly source_root="$(dirname "$0")"

# You can override the version of the core library
: "${REALM_BASE_URL:="https://static.realm.io/downloads"}" # set it if you need to use a remote repo

: "${REALM_CORE_VERSION:=$(sed -n 's/^REALM_CORE_VERSION=\(.*\)$/\1/p' "${source_root}/dependencies.list")}" # set to "current" to always use the current build

# You can override the xcmode used
: "${XCMODE:=xcodebuild}" # must be one of: xcodebuild (default), xcpretty, xctool

# Provide a fallback value for TMPDIR, relevant for Xcode Bots
: "${TMPDIR:=$(getconf DARWIN_USER_TEMP_DIR)}"

PATH=/usr/libexec:$PATH

if [ -n "${JENKINS_HOME}" ]; then
    XCPRETTY_PARAMS=(--no-utf --report junit --output build/reports/junit.xml)
    CODESIGN_PARAMS=(CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
fi

usage() {
cat <<EOF
Usage: sh $0 command [argument]

command:
  clean:                clean up/remove all generated files
  download-core:        downloads core library (binary version)
  build:                builds all iOS and macOS frameworks
  ios-static:           builds fat iOS static framework
  ios-dynamic:          builds iOS dynamic frameworks
  ios-swift:            builds RealmSwift frameworks for iOS
  watchos:              builds watchOS framwork
  watchos-swift:        builds RealmSwift framework for watchOS
  tvos:                 builds tvOS framework
  tvos-swift:           builds RealmSwift framework for tvOS
  osx:                  builds macOS framework
  osx-swift:            builds RealmSwift framework for macOS
  xcframework [plats]:  builds xcframeworks for Realm and RealmSwift for given platforms
  analyze-osx:          analyzes macOS framework
  test:                 tests all iOS and macOS frameworks
  test-all:             tests all iOS and macOS frameworks in both Debug and Release configurations
  test-ios-static:      tests static iOS framework on 32-bit and 64-bit simulators
  test-ios-dynamic:     tests dynamic iOS framework on 32-bit and 64-bit simulators
  test-ios-swift:       tests RealmSwift iOS framework on 32-bit and 64-bit simulators
  test-ios-devices:     tests ObjC & Swift iOS frameworks on all attached iOS devices
  test-ios-devices-objc:  tests ObjC iOS framework on all attached iOS devices
  test-ios-devices-swift: tests Swift iOS framework on all attached iOS devices
  test-tvos:            tests tvOS framework
  test-tvos-swift:      tests RealmSwift tvOS framework
  test-tvos-devices:    tests ObjC & Swift tvOS frameworks on all attached tvOS devices
  test-osx:             tests macOS framework
  test-osx-swift:       tests RealmSwift macOS framework
  test-catalyst:        tests Mac Catalyst framework
  test-catalyst-swift:  tests RealmSwift Mac Catalyst framework
  test-swiftpm:         tests ObjC and Swift macOS frameworks via SwiftPM
  test-swiftui-ios:         tests SwiftUI framework UI tests
  test-swiftui-server-ios:  tests Server Sync in SwiftUI
  verify:               verifies docs, osx, osx-swift, ios-static, ios-dynamic, ios-swift, ios-device, swiftui-ios in both Debug and Release configurations, swiftlint
  verify-osx-object-server:  downloads the Realm Object Server and runs the Objective-C and Swift integration tests
  docs:                 builds docs in docs/output
  examples:             builds all examples
  examples-ios:         builds all static iOS examples
  examples-ios-swift:   builds all Swift iOS examples
  examples-osx:         builds all macOS examples
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
    CMD="xcodebuild -IDECustomDerivedDataLocation=build/DerivedData"
    echo "Building with command: $CMD $*"
    xcodebuild -IDECustomDerivedDataLocation=build/DerivedData "$@"
}

xc() {
    # Logs xcodebuild output in realtime
    : "${NSUnbufferedIO:=YES}"
    args=("SWIFT_VERSION=$REALM_SWIFT_VERSION" $REALM_EXTRA_BUILD_ARGUMENTS)
    if [[ "$XCMODE" == "xcodebuild" ]]; then
        xcode "$@" "${args[@]}"
    elif [[ "$XCMODE" == "xcpretty" ]]; then
        mkdir -p build
        xcode "$@" "${args[@]}" | tee build/build.log | xcpretty -c "${XCPRETTY_PARAMS[@]}" || {
            echo "The raw xcodebuild output is available in build/build.log"
            exit 1
        }
    elif [[ "$XCMODE" == "xctool" ]]; then
        xctool "$@" "${args[@]}"
    fi
}

xctest() {
  local scheme="$1"
  xc -scheme "$scheme" "${@:2}" build-for-testing
  xc -scheme "$scheme" "${@:2}" test-without-building
}

build_combined() {
    local scheme="$1"
    local module_name="$2"
    local os="$3"
    local simulator="$4"
    local scope_suffix="$5"
    local version_suffix="$6"
    local config="$CONFIGURATION"

    local os_name=""
    if [[ "$os" == "iphoneos" ]]; then
        os_name="ios"
    elif [[ "$os" == "watchos"  ]]; then
        os_name="$os"
    elif [[ "$os" == "appletvos"  ]]; then
        os_name="tvos"
    fi

    # Derive build paths
    local build_products_path="build/DerivedData/Realm/Build/Products"
    local product_name="$module_name.framework"
    local os_path="$build_products_path/$config-$os$scope_suffix/$product_name"
    local simulator_path="$build_products_path/$config-$simulator$scope_suffix/$product_name"
    local out_path="build/$os_name$scope_suffix$version_suffix"
    local xcframework_path="$out_path/$module_name.xcframework"

    # Build for each platform
    xc -scheme "$scheme" -configuration "$config" -sdk "$os" build
    xc -scheme "$scheme" -configuration "$config" -sdk "$simulator" build ONLY_ACTIVE_ARCH=NO

    # Create the xcframework
    rm -rf "$xcframework_path"
    xcodebuild -create-xcframework -allow-internal-distribution -output "$xcframework_path" \
        -framework "$os_path" -framework "$simulator_path"
}

copy_realm_framework() {
    local platform="$1"
    rm -rf "build/$platform/swift-$REALM_XCODE_VERSION/Realm.xcframework"
    cp -R "build/$platform/Realm.xcframework" "build/$platform/swift-$REALM_XCODE_VERSION"
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
    xctest 'Realm iOS static' -configuration "$CONFIGURATION" -sdk iphonesimulator -destination "$1"
}

plist_get() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2> /dev/null
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
        xc -scheme "$scheme" -configuration "$configuration" -destination "id=$device" -sdk "$sdk" test || failed=1
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
        xcodebuild_arguments="-scheme,RealmSwift"
        module="RealmSwift"
        objc=""
    fi

    touch Realm/RLMPlatform.h # jazzy will fail if it can't find all public header files
    jazzy \
      "${objc}" \
      --clean \
      --author Realm \
      --author_url https://realm.io \
      --github_url https://github.com/realm/realm-cocoa \
      --github-file-prefix "https://github.com/realm/realm-cocoa/tree/v${version}" \
      --module-version "${version}" \
      --xcodebuild-arguments "${xcodebuild_arguments}" \
      --module "${module}" \
      --root-url "https://docs.mongodb.com/realm-sdks/${language}/${version}/" \
      --output "docs/${language}_output" \
      --head "$(cat docs/custom_head.html)" \
      --exclude 'RealmSwift/Impl/*'

    rm Realm/RLMPlatform.h
}

######################################
# Input Validation
######################################

if [ "$#" -eq 0 ] || [ "$#" -gt 3 ]; then
    usage
    exit 1
fi

######################################
# Downloading
######################################

copy_core() {
    local src="$1"
    rm -rf core
    mkdir core
    ditto "$src" core

    # XCFramework processing only copies the "realm" headers, so put the third-party ones in a known location
    mkdir -p core/include
    find "$src" -name external -exec ditto "{}" core/include/external \; -quit
}

download_common() {
    local tries_left=3 version url error suffix
    suffix='-xcframework'

    version=$REALM_CORE_VERSION
    url="${REALM_BASE_URL}/core/realm-monorepo-xcframework-v${version}.tar.xz"

    # First check if we need to do anything
    if [ -e core ]; then
        if [ -e core/version.txt ]; then
            if [ "$(cat core/version.txt)" == "$version" ]; then
                echo "Version ${version} already present"
                exit 0
            else
                echo "Switching from version $(cat core/version.txt) to ${version}"
            fi
        else
            if [ "$(find core -name librealm-monorepo.a)" ]; then
                echo 'Using existing custom core build without checking version'
                exit 0
            fi
        fi
    fi

    # We may already have this version downloaded and just need to set it as
    # the active one
    local versioned_dir="realm-core-${version}${suffix}"
    if [ -e "$versioned_dir/version.txt" ]; then
        echo "Setting ${version} as the active version"
        copy_core "$versioned_dir"
        exit 0
    fi

    echo "Downloading dependency: ${version} from ${url}"

    if [ -z "$TMPDIR" ]; then
        TMPDIR='/tmp'
    fi
    local temp_dir=$(dirname "$TMPDIR/waste")/realm-core-tmp
    mkdir -p "$temp_dir"
    local tar_path="${temp_dir}/${versioned_dir}.tar.xz"
    local temp_path="${tar_path}.tmp"

    while [ 0 -lt $tries_left ] && [ ! -f "$tar_path" ]; do
        if ! error=$(/usr/bin/curl --fail --silent --show-error --location "$url" --output "$temp_path" 2>&1); then
            tries_left=$((tries_left-1))
        else
            mv "$temp_path" "$tar_path"
        fi
    done

    if [ ! -f "$tar_path" ]; then
        printf "Downloading core failed:\n\t%s\n\t%s\n" "$url" "$error"
        exit 1
    fi

    (
        cd "$temp_dir"
        rm -rf core
        tar xf "$tar_path" --xz
        if [ ! -f core/version.txt ]; then
            printf %s "${version}" > core/version.txt
        fi

        mv core "${versioned_dir}"
    )

    rm -rf "${versioned_dir}"
    mv "${temp_dir}/${versioned_dir}" .
    copy_core "$versioned_dir"
}

######################################
# Variables
######################################

COMMAND="$1"

# Use Debug config if command ends with -debug, otherwise default to Release
case "$COMMAND" in
    *-debug)
        COMMAND="${COMMAND%-debug}"
        CONFIGURATION="Debug"
        ;;
esac
export CONFIGURATION=${CONFIGURATION:-Release}

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
    # Dependencies
    ######################################
    "download-core")
        download_common
        exit 0
        ;;

    "setup-baas")
        ruby Realm/ObjectServerTests/setup_baas.rb
        exit 0
        ;;

    "prelaunch-simulator")
        if [ -z "$REALM_SKIP_PRELAUNCH" ]; then
            sh "${source_root}/scripts/reset-simulators.sh" "$1"
        fi
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
        build_combined RealmSwift RealmSwift iphoneos iphonesimulator '' "/swift-$REALM_XCODE_VERSION"
        copy_realm_framework ios
        exit 0
        ;;

    "watchos")
        build_combined Realm Realm watchos watchsimulator
        exit 0
        ;;

    "watchos-swift")
        sh build.sh watchos
        build_combined RealmSwift RealmSwift watchos watchsimulator '' "/swift-$REALM_XCODE_VERSION"
        copy_realm_framework watchos
        exit 0
        ;;

    "tvos")
        build_combined Realm Realm appletvos appletvsimulator
        exit 0
        ;;

    "tvos-swift")
        sh build.sh tvos
        build_combined RealmSwift RealmSwift appletvos appletvsimulator '' "/swift-$REALM_XCODE_VERSION"
        copy_realm_framework tvos
        exit 0
        ;;

    "osx")
        xc -scheme Realm -configuration "$CONFIGURATION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/Realm.framework" "build/osx" "Realm.framework"
        exit 0
        ;;

    "osx-swift")
        sh build.sh osx
        xc -scheme RealmSwift -configuration "$CONFIGURATION" build
        destination="build/osx/swift-$REALM_XCODE_VERSION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/RealmSwift.framework" "$destination" "RealmSwift.framework"
        clean_retrieve "build/osx/Realm.framework" "$destination" "Realm.framework"
        exit 0
        ;;

    "swiftui")
        xc -scheme SwiftUITestHost -configuration $CONFIGURATION -sdk iphonesimulator build
        ;;

    "catalyst")
        export REALM_SDKROOT=iphoneos
        xc -scheme Realm -configuration "$CONFIGURATION" -destination variant='Mac Catalyst'
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION-maccatalyst/Realm.framework" "build/catalyst" "Realm.framework"
        ;;

    "catalyst-swift")
        sh build.sh catalyst
        export REALM_SDKROOT=iphoneos
        xc -scheme 'RealmSwift' -configuration "$CONFIGURATION" -destination variant='Mac Catalyst' build
        destination="build/catalyst/swift-$REALM_XCODE_VERSION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION-maccatalyst/RealmSwift.framework" "$destination" "RealmSwift.framework"
        clean_retrieve "build/catalyst/Realm.framework" "$destination" "Realm.framework"
        ;;

    "xcframework")
        # Build all of the requested frameworks
        shift
        PLATFORMS="${*:-osx ios watchos tvos catalyst}"
        for platform in $PLATFORMS; do
            sh build.sh "$platform-swift"
        done

        # Assemble them into xcframeworks
        rm -rf build/*.xcframework
        find build/DerivedData/Realm/Build/Products -name 'Realm.framework' \
            | grep -v '\-static' \
            | sed 's/.*/-framework &/' \
            | xargs xcodebuild -create-xcframework -allow-internal-distribution -output build/Realm.xcframework
        find build/DerivedData/Realm/Build/Products -name 'RealmSwift.framework' \
            | sed 's/.*/-framework &/' \
            | xargs xcodebuild -create-xcframework -allow-internal-distribution -output build/RealmSwift.xcframework

        exit 0
        ;;

    ######################################
    # Analysis
    ######################################

    "analyze-osx")
        xc -scheme Realm -configuration "$CONFIGURATION" analyze
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
        sh build.sh test-catalyst || failed=1
        sh build.sh test-catalyst-swift || failed=1
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
        test_ios_static "name=iPhone 8"
        exit 0
        ;;

    "test-ios-dynamic")
        xctest Realm -configuration "$CONFIGURATION" -sdk iphonesimulator -destination 'name=iPhone 8'
        exit 0
        ;;

    "test-ios-swift")
        xctest RealmSwift -configuration "$CONFIGURATION" -sdk iphonesimulator -destination 'name=iPhone 8'
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
        destination="Apple TV"
        xctest Realm -configuration "$CONFIGURATION" -sdk appletvsimulator -destination "name=$destination"
        exit $?
        ;;

    "test-tvos-swift")
        destination="Apple TV"
        xctest RealmSwift -configuration "$CONFIGURATION" -sdk appletvsimulator -destination "name=$destination"
        exit $?
        ;;

    "test-tvos-devices")
        test_devices appletvos TestHost "$CONFIGURATION"
        ;;

    "test-osx")
        COVERAGE_PARAMS=()
        if [[ "$CONFIGURATION" == "Debug" ]]; then
            COVERAGE_PARAMS=(GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES)
        fi
        xctest Realm -configuration "$CONFIGURATION" "${COVERAGE_PARAMS[@]}"
        exit 0
        ;;

    "test-osx-swift")
        xctest RealmSwift -configuration $CONFIGURATION
        exit 0
        ;;

    "test-osx-object-server")
        xctest 'Object Server Tests' -configuration "$CONFIGURATION" -sdk macosx
        exit 0
        ;;

    test-swiftpm-ios)
        cd examples/installation
        sh build.sh test-ios-swift-spm
        exit 0
        ;;

    test-swiftpm*)
        SANITIZER=$(echo "$COMMAND" | cut -d - -f 3)
        if [ -n "$SANITIZER" ]; then
            SANITIZER="--sanitize $SANITIZER"
            export ASAN_OPTIONS='check_initialization_order=true:detect_stack_use_after_return=true'
        fi
        xcrun swift package resolve
        find .build -name views.cpp -delete
        xcrun swift test --configuration "$(echo "$CONFIGURATION" | tr "[:upper:]" "[:lower:]")" $SANITIZER
        exit 0
        ;;

    "test-swiftui-ios")
        xctest 'SwiftUITestHost' -configuration "$CONFIGURATION" -sdk iphonesimulator -destination 'name=iPhone 8'
        exit 0
        ;;

    "test-catalyst")
        export REALM_SDKROOT=iphoneos
        xctest Realm -configuration "$CONFIGURATION" -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY=''
        exit 0
        ;;

    "test-catalyst-swift")
        export REALM_SDKROOT=iphoneos
        xctest RealmSwift -configuration "$CONFIGURATION" -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY=''
        exit 0
        ;;

    "test-swiftui-server-ios")
        xctest 'SwiftUISyncTestHost' -configuration "$CONFIGURATION" -sdk macosx -destination 'platform=macOS'
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
        sh build.sh verify-swiftpm
        sh build.sh verify-osx-object-server
        sh build.sh verify-catalyst
        sh build.sh verify-catalyst-swift
        sh build.sh verify-swiftui-ios
        sh build.sh verify-swiftui-server-ios
        ;;

    "verify-cocoapods")
        if [[ -d .git ]]; then
          # Verify the current branch, unless one was already specified in the sha environment variable.
          if [[ -z $sha ]]; then
            export sha=$(git rev-parse --abbrev-ref HEAD)
          fi

          if [[ $(git log -1 '@{push}..') != "" ]] || ! git diff-index --quiet HEAD; then
            echo "WARNING: verify-cocoapods will test the latest revision of $sha found on GitHub."
            echo "         Any unpushed local changes will not be tested."
            echo ""
            sleep 1
          fi
        fi

        sh build.sh verify-cocoapods-ios
        sh build.sh verify-cocoapods-ios-dynamic
        sh build.sh verify-cocoapods-osx
        sh build.sh verify-cocoapods-watchos

        # https://github.com/CocoaPods/CocoaPods/issues/7708
        export EXPANDED_CODE_SIGN_IDENTITY=''
        cd examples/installation
        sh build.sh test-ios-objc-cocoapods
        sh build.sh test-ios-objc-cocoapods-dynamic
        sh build.sh test-ios-swift-cocoapods
        sh build.sh test-osx-objc-cocoapods
        sh build.sh test-osx-swift-cocoapods
        sh build.sh test-catalyst-objc-cocoapods
        sh build.sh test-catalyst-objc-cocoapods-dynamic
        sh build.sh test-catalyst-swift-cocoapods
        sh build.sh test-watchos-objc-cocoapods
        sh build.sh test-watchos-swift-cocoapods
        ;;

    verify-cocoapods-ios-dynamic)
        PLATFORM=$(echo "$COMMAND" | cut -d - -f 3)
        # https://github.com/CocoaPods/CocoaPods/issues/7708
        export EXPANDED_CODE_SIGN_IDENTITY=''
        cd examples/installation
        sh build.sh test-ios-objc-cocoapods-dynamic
        ;;

    verify-cocoapods-*)
        PLATFORM=$(echo "$COMMAND" | cut -d - -f 3)
        # https://github.com/CocoaPods/CocoaPods/issues/7708
        export EXPANDED_CODE_SIGN_IDENTITY=''
        cd examples/installation
        sh build.sh "test-$PLATFORM-swift-cocoapods"
        ;;

    "verify-osx-encryption")
        REALM_ENCRYPT_ALL=YES sh build.sh test-osx
        exit 0
        ;;

    "verify-osx")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/osx/objc/RealmExamples.xcworkspace" \
            sh build.sh test-osx
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

    "verify-swiftui-ios")
        sh build.sh test-swiftui-ios
        exit 0
        ;;

    "verify-swiftui-server-ios")
        sh build.sh test-swiftui-server-ios
        exit 0
        ;;

    "verify-osx-swift-evolution")
        export REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS REALM_BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        sh build.sh test-osx-swift
        exit 0
        ;;

    "verify-ios-static")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/ios/objc/RealmExamples.xcworkspace" \
            sh build.sh test-ios-static
        sh build.sh examples-ios
        ;;

    "verify-ios-dynamic")
        sh build.sh test-ios-dynamic
        ;;

    "verify-ios-swift")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/ios/swift/RealmExamples.xcworkspace" \
            sh build.sh test-ios-swift
        sh build.sh examples-ios-swift
        ;;

    "verify-ios-swift-evolution")
        export REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS REALM_BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        sh build.sh test-ios-swift
        exit 0
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
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/tvos/objc/RealmExamples.xcworkspace" \
            sh build.sh test-tvos
        sh build.sh examples-tvos
        exit 0
        ;;

    "verify-tvos-swift")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/tvos/swift/RealmExamples.xcworkspace" \
            sh build.sh test-tvos-swift
        sh build.sh examples-tvos-swift
        exit 0
        ;;

    "verify-tvos-swift-evolution")
        export REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS REALM_BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        sh build.sh test-tvos-swift
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

    verify-swiftpm*)
        sh build.sh "test-$(echo "$COMMAND" | cut -d - -f 2-)"
        exit 0
        ;;

    "verify-osx-object-server")
        sh build.sh test-osx-object-server
        exit 0
        ;;

    "verify-catalyst")
        sh build.sh test-catalyst
        exit 0
        ;;

    "verify-catalyst-swift")
        sh build.sh test-catalyst-swift
        exit 0
        ;;

    "verify-xcframework")
        sh build.sh xcframework
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
        sh build.sh prelaunch-simulator
        export REALM_SKIP_PRELAUNCH=1
        sh build.sh examples-ios
        sh build.sh examples-ios-swift
        sh build.sh examples-osx
        sh build.sh examples-tvos
        sh build.sh examples-tvos-swift
        exit 0
        ;;

    "examples-ios")
        workspace="examples/ios/objc/RealmExamples.xcworkspace"
        pod install --project-directory="$workspace/.." --no-repo-update
        examples="Simple TableView Migration Backlink GroupedTableView RACTableView Encryption Draw"
        versions="0 1 2 3 4 5"
        for example in $examples; do
            if [ "$example" = "Migration" ]; then
                # The migration example needs to be built for each schema version to ensure each compiles.
                for version in $versions; do
                    xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk iphonesimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}" GCC_PREPROCESSOR_DEFINITIONS="\$(GCC_PREPROCESSOR_DEFINITIONS) SCHEMA_VERSION_$version"
                done
            else
                xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk iphonesimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}"
            fi
        done
        if [ -n "${JENKINS_HOME}" ]; then
            xc -workspace "$workspace" -scheme Extension -configuration "$CONFIGURATION" -sdk iphonesimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}"
        fi

        exit 0
        ;;

    "examples-ios-swift")
        workspace="examples/ios/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_XCODE_VERSION}"
        fi

        examples="Simple TableView Migration Backlink GroupedTableView Encryption AppClip AppClipParent"
        versions="0 1 2 3 4 5"
        for example in $examples; do
            if [ "$example" = "Migration" ]; then
                # The migration example needs to be built for each schema version to ensure each compiles.
                for version in $versions; do
                    xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk iphonesimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}" OTHER_SWIFT_FLAGS="\$(OTHER_SWIFT_FLAGS) -DSCHEMA_VERSION_$version"
                done
            else
                xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk iphonesimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}"
            fi
        done

        exit 0
        ;;

    "examples-osx")
        xc -workspace examples/osx/objc/RealmExamples.xcworkspace -scheme JSONImport -configuration "${CONFIGURATION}" build "${CODESIGN_PARAMS[@]}"
        ;;

    "examples-tvos")
        workspace="examples/tvos/objc/RealmExamples.xcworkspace"
        examples="DownloadCache PreloadedData"
        for example in $examples; do
            xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk appletvsimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}"
        done

        exit 0
        ;;

    "examples-tvos-swift")
        workspace="examples/tvos/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_XCODE_VERSION}"
        fi
        examples="DownloadCache PreloadedData"
        for example in $examples; do
            xc -workspace "$workspace" -scheme "$example" -configuration "$CONFIGURATION" -sdk appletvsimulator build ARCHS=x86_64 "${CODESIGN_PARAMS[@]}"
        done

        exit 0
        ;;

    ######################################
    # Versioning
    ######################################
    "get-version")
        plist_get 'Realm/Realm-Info.plist' 'CFBundleShortVersionString'
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
        sed -i '' "s/^let coreVersionStr =.*/let coreVersionStr = \"$REALM_CORE_VERSION\"/" Package.swift
        sed -i '' "s/^let cocoaVersionStr =.*/let cocoaVersionStr = \"$realm_version\"/" Package.swift
        sed -i '' "s/x.y.z Release notes (yyyy-MM-dd)/$realm_version Release notes ($(date '+%Y-%m-%d'))/" CHANGELOG.md

        exit 0
        ;;

    ######################################
    # Bitcode Detection
    ######################################

    "binary-has-bitcode")
        # Disable pipefail as grep -q will make otool fail due to exiting
        # before reading all the output
        set +o pipefail

        BINARY="$2"
        if otool -l "$BINARY" | grep -q "segname __LLVM"; then
            exit 0
        fi
        # Work around rdar://21826157 by checking for bitcode in thin binaries

        # Get architectures for binary
        archs="$(lipo -info "$BINARY" | rev | cut -d ':' -f1 | rev)"

        archs_array=( $archs )
        if [[ ${#archs_array[@]} -lt 2 ]]; then
            echo 'Error: Built library is not a fat binary'
            exit 1 # Early exit if not a fat binary
        fi

        TEMPDIR=$(mktemp -d $TMPDIR/realm-bitcode-check.XXXX)

        for arch in $archs; do
            lipo -thin "$arch" "$BINARY" -output "$TEMPDIR/$arch"
            if otool -l "$TEMPDIR/$arch" | grep -q "segname __LLVM"; then
                exit 0
            fi
        done
        echo 'Error: Built library does not contain bitcode'
        exit 1
        ;;

    ######################################
    # CocoaPods
    ######################################
    "cocoapods-setup")
        if [ ! -f core/version.txt ]; then
          sh build.sh download-core
        fi

        rm -rf include
        mkdir -p include
        cp -R core/realm-monorepo.xcframework/ios-armv7_arm64/Headers include/core

        mkdir -p include
        echo '' > Realm/RLMPlatform.h
        cp Realm/*.h Realm/*.hpp include
        ;;

    ######################################
    # Continuous Integration
    ######################################

    "ci-pr")
        mkdir -p build/reports
        export REALM_DISABLE_ANALYTICS=1
        export REALM_DISABLE_UPDATE_CHECKER=1
        # FIXME: Re-enable once CI can properly unlock the keychain
        export REALM_DISABLE_METADATA_ENCRYPTION=1

        # Make sure there aren't any lingering server processes from previous jobs
        pkill -9 mongo stitch || true

        # strip off the ios|tvos version specifier, e.g. the last part of: `ios-device-objc-ios8`
        if [[ "$target" =~ ^((ios|tvos)-device(-(objc|swift))?)(-(ios|tvos)[[:digit:]]+)?$ ]]; then
            export target=${BASH_REMATCH[1]}
        fi

        if [ "$target" = "docs" ]; then
            sh build.sh verify-docs
        elif [ "$target" = "swiftlint" ]; then
            sh build.sh verify-swiftlint
        else
            export sha=$GITHUB_PR_SOURCE_BRANCH
            export REALM_EXTRA_BUILD_ARGUMENTS='GCC_GENERATE_DEBUGGING_SYMBOLS=NO -allowProvisioningUpdates'
            if [[ "$target" = *ios* ]] || [[ "$target" = *tvos* ]] || [[ "$target" = *watchos* ]]; then
                sh build.sh prelaunch-simulator "$target"
            fi
            export REALM_SKIP_PRELAUNCH=1

            if [[ "$target" = *"server"* ]] || [[ "$target" = "swiftpm"* ]]; then
                mkdir .baas
                mv build/stitch .baas
                source "$(brew --prefix nvm)/nvm.sh" --no-use
                nvm install 13.14.0
                sh build.sh setup-baas
            fi

            # Reset CoreSimulator.log
            mkdir -p ~/Library/Logs/CoreSimulator
            echo > ~/Library/Logs/CoreSimulator/CoreSimulator.log

            failed=0
            sh build.sh "verify-$target" 2>&1 | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            if [ "$failed" = "1" ] && grep -E 'DTXProxyChannel|DTXChannel|out of date and needs to be rebuilt|operation never finished bootstrapping' build/build.log ; then
                echo "Known Xcode error detected. Running job again."
                if grep -E 'out of date and needs to be rebuilt' build/build.log; then
                    rm -rf build/DerivedData
                fi
                failed=0
                sh build.sh "verify-$target" | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            elif [ "$failed" = "1" ] && tail ~/Library/Logs/CoreSimulator/CoreSimulator.log | grep -E "Operation not supported|Failed to lookup com.apple.coreservices.lsuseractivity.simulatorsupport"; then
                echo "Known Xcode error detected. Running job again."
                failed=0
                sh build.sh "verify-$target" | tee build/build.log | xcpretty -r junit -o build/reports/junit.xml || failed=1
            fi
            if [ "$failed" = "1" ]; then
                set +e
                printf "%s" "\n\n***\nbuild/build.log\n***\n\n" && cat build/build.log
                printf "%s" "\n\n***\nCoreSimulator.log\n***\n\n" && cat ~/Library/Logs/CoreSimulator/CoreSimulator.log
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

    "package-test-examples-objc")
        if ! VERSION=$(echo realm-objc-*.zip | grep -E -o '\d*\.\d*\.\d*-[a-z]*(\.\d*)?'); then
            VERSION=$(echo realm-objc-*.zip | grep -E -o '\d*\.\d*\.\d*')
        fi
        OBJC="realm-objc-${VERSION}"
        unzip "${OBJC}.zip"

        cp "$0" "${OBJC}"
        cp -r "${source_root}/scripts" "${OBJC}"
        cd "${OBJC}"
        sh build.sh examples-ios
        sh build.sh examples-tvos
        sh build.sh examples-osx
        cd ..
        rm -rf "${OBJC}"
        ;;

    "package-test-examples-swift")
        if ! VERSION=$(echo realm-swift-*.zip | grep -E -o '\d*\.\d*\.\d*-[a-z]*(\.\d*)?'); then
            VERSION=$(echo realm-swift-*.zip | grep -E -o '\d*\.\d*\.\d*')
        fi
        SWIFT="realm-swift-${VERSION}"
        unzip "${SWIFT}.zip"

        cp "$0" "${SWIFT}"
        cp -r "${source_root}/scripts" "${SWIFT}"
        cd "${SWIFT}"
        sh build.sh examples-ios-swift
        sh build.sh examples-tvos-swift
        cd ..
        rm -rf "${SWIFT}"
        ;;

    "package-ios-static")
        sh build.sh prelaunch-simulator
        sh build.sh ios-static

        cd build/ios-static
        zip --symlinks -r realm-framework-ios-static.zip Realm.xcframework
        ;;

    "package")
        PLATFORM="$2"
        REALM_SWIFT_VERSION=

        set_xcode_and_swift_versions

        sh build.sh "$PLATFORM-swift"

        cd "build/$PLATFORM"
        zip --symlinks -r "realm-framework-$PLATFORM-$REALM_XCODE_VERSION.zip" "swift-$REALM_XCODE_VERSION"
        ;;

    "package-release")
        LANG="$2"
        tempdir="$(mktemp -d "$TMPDIR"/realm-release-package-"${LANG}".XXXX)"
        extract_dir="$(mktemp -d "$TMPDIR"/realm-release-package-"${LANG}".XXXX)"
        version="$(sh build.sh get-version)"
        package_dir="${tempdir}/realm-${LANG}-${version}"

        mkdir -p "${package_dir}"

        if [[ "${LANG}" == "objc" ]]; then
            mkdir -p "${extract_dir}"
            unzip "${WORKSPACE}/realm-framework-ios-static.zip" -d "${package_dir}/ios-static"
            for platform in osx ios watchos tvos catalyst; do
                unzip "${WORKSPACE}/realm-framework-${platform}-${REALM_XCODE_VERSION}.zip" -d "${extract_dir}/${platform}"
            done
            find "${extract_dir}" -name 'Realm.framework' \
                | sed 's/.*/-framework &/' \
                | xargs xcodebuild -create-xcframework -allow-internal-distribution -output "${package_dir}/Realm.xcframework"

            cp "${WORKSPACE}/Realm/Swift/RLMSupport.swift" "${package_dir}"
            rm -r "${extract_dir}"
        else
            xcode_versions=$(find . -name 'realm-framework-*-1*' | sed 's@./realm-framework-[a-z]*-\(.*\).zip@\1@' | sort -u)
            for xcode_version in $xcode_versions; do
                mkdir -p "${extract_dir}"
                for platform in osx ios watchos tvos catalyst; do
                    unzip "realm-framework-$platform-$xcode_version.zip" -d "${extract_dir}/${platform}"
                done
                find "${extract_dir}" -name 'Realm.framework' \
                    | sed 's/.*/-framework &/' \
                    | xargs xcodebuild -create-xcframework -allow-internal-distribution -output "${package_dir}/${xcode_version}/Realm.xcframework"
                find "${extract_dir}" -name 'RealmSwift.framework' \
                    | sed 's/.*/-framework &/' \
                    | xargs xcodebuild -create-xcframework -allow-internal-distribution -output "${package_dir}/${xcode_version}/RealmSwift.xcframework"
                rm -r "${extract_dir}"
            done
        fi

        (
            cd "${WORKSPACE}"
            cp -R plugin LICENSE "${package_dir}"
        )

        (
            cd "${package_dir}"
            unzip "${WORKSPACE}/realm-examples.zip"
            cd examples
            if [[ "${LANG}" == "objc" ]]; then
                rm -rf ios/swift-* tvos/swift-*
            else
                rm -rf ios/objc osx tvos/objc
            fi
        )

        cat > "${package_dir}"/docs.webloc <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>https://realm.io/docs/${LANG}/${version}</string>
</dict>
</plist>
EOF

        (
          cd "${tempdir}"
          zip --symlinks -r "realm-${LANG}-${version}.zip" "realm-${LANG}-${version}"
          mv "realm-${LANG}-${version}.zip" "${WORKSPACE}"
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
        cd "$WORKSPACE"
        git clone --recursive "$REALM_SOURCE" realm-cocoa
        cd realm-cocoa

        echo 'Packaging iOS'
        sh build.sh package-ios-static
        cp build/ios-static/realm-framework-ios-static.zip .
        sh build.sh package ios
        cp "build/ios/realm-framework-ios-$REALM_XCODE_VERSION.zip" .

        echo 'Packaging macOS'
        sh build.sh package osx
        cp "build/osx/realm-framework-osx-$REALM_XCODE_VERSION.zip" .

        echo 'Packaging watchOS'
        sh build.sh package watchos
        cp "build/watchos/realm-framework-watchos-$REALM_XCODE_VERSION.zip" .

        echo 'Packaging tvOS'
        sh build.sh package tvos
        cp "build/tvos/realm-framework-tvos-$REALM_XCODE_VERSION.zip" .

        echo 'Packaging Catalyst'
        sh build.sh package catalyst
        cp "build/catalyst/realm-framework-catalyst-$REALM_XCODE_VERSION.zip" .

        echo 'Packaging examples'
        sh build.sh package-examples

        echo 'Building final release packages'
        export WORKSPACE="${WORKSPACE}/realm-cocoa"
        sh build.sh package-release objc
        sh build.sh package-release swift

        echo 'Testing packaged examples'
        sh build.sh package-test-examples-objc
        sh build.sh package-test-examples-swift
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
x.y.z Release notes (yyyy-MM-dd)
=============================================================
### Enhancements
* None.

### Fixed
* <How to hit and notice issue? what was the impact?> ([#????](https://github.com/realm/realm-cocoa/issues/????), since v?.?.?)
* None.

<!-- ### Breaking Changes - ONLY INCLUDE FOR NEW MAJOR version -->

### Compatibility
* Realm Studio: 11.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.1.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 2.

### Internal
* Upgraded realm-core from ? to ?

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
