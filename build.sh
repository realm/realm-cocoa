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

source_root="$(dirname "$0")"

# You can override the version of the core library
: ${REALM_BASE_URL:="https://static.realm.io/downloads"} # set it if you need to use a remote repo

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
  download-sync:        downloads sync library (binary version, core+sync)
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
  verify:               verifies docs, osx, osx-swift, ios-static, ios-dynamic, ios-swift, ios-device in both Debug and Release configurations, swiftlint
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

xctest() {
  xc "$@" build-for-testing
  xc "$@" test
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
        destination="iPhone 8"
    elif [[ "$os" == "watchos"  ]]; then
        os_name="$os"
        destination="Apple Watch Series 3 - 42mm"
    elif [[ "$os" == "appletvos"  ]]; then
        os_name="tvos"
        destination="Apple TV"
    fi

    # Derive build paths
    local build_products_path="build/DerivedData/Realm/Build/Products"
    local build_intermediates_path="build/DerivedData/Realm/Build/Intermediates.noindex"
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
      cp -r $simulator_path/Modules/$module_name.swiftmodule/* $os_path/Modules/$module_name.swiftmodule/
    fi

    # Xcode 10.2 merges the generated headers together with ifdef guards for
    # each of the target platforms. This doesn't handle merging
    # device/simulator builds, so we need to take care of that ourselves.
    # Currently all platforms have identical headers, so we just pick one and
    # use that rather than merging, but this may change in the future.
    if [ -f $os_path/Headers/$module_name-Swift.h ]; then
      unique_headers=$(find $build_intermediates_path -name $module_name-Swift.h -exec shasum {} \; | cut -d' ' -f 1 | uniq | grep -c '^')
      if [ $unique_headers != "1" ]; then
        echo "Platform-specific Swift generated headers are not identical. Merging them is required and is not yet implemented."
        exit 1
      fi
      find $build_intermediates_path -name $module_name-Swift.h -exec cp {} $os_path/Headers \; -quit
    fi

    # Copy *.bcsymbolmap to .framework for submitting app with bitcode
    copy_bcsymbolmap "$build_products_path/$config-$os$scope_suffix" "$os_path"

    # Retrieve build products
    clean_retrieve $os_path $out_path $product_name

    # Combine ar archives
    LIPO_OUTPUT="$out_path/$product_name/$module_name"
    xcrun lipo -create "$simulator_path/$binary_path" "$os_path/$binary_path" -output "$LIPO_OUTPUT"

    # Verify that the combined library has bitcode and we didn't accidentally
    # remove it somewhere along the line
    if [[ "$destination" != "" && "$config" == "Release" ]]; then
        sh build.sh binary-has-bitcode "$LIPO_OUTPUT"
    fi
}

copy_realm_framework() {
    local platform="$1"
    rm -rf build/$platform/swift-$REALM_XCODE_VERSION/Realm.framework
    cp -R build/$platform/Realm.framework build/$platform/swift-$REALM_XCODE_VERSION
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
    xc "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' build-for-testing"
    xc "-scheme 'Realm iOS static' -configuration $CONFIGURATION -sdk iphonesimulator -destination '$destination' test"
}

plist_get() {
    /usr/libexec/PlistBuddy -c "Print :$2" $1 2> /dev/null
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

download_common() {
    local download_type=$1 tries_left=3 version url error temp_dir temp_path tar_path

    if [ "$download_type" == "core" ]; then
        version=$REALM_CORE_VERSION
        url="${REALM_BASE_URL}/core/realm-core-${version}.tar.xz"
    elif [ "$download_type" == "sync" ]; then
        version=$REALM_SYNC_VERSION
        url="${REALM_BASE_URL}/sync/realm-sync-cocoa-${version}.tar.xz"
    else
        echo "Unknown dowload_type: $download_type"
        exit 1
    fi

    echo "Downloading dependency: ${download_type} ${version} from ${url}"

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
        xc "-scheme Realm -configuration $CONFIGURATION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/Realm.framework" "build/osx" "Realm.framework"
        exit 0
        ;;

    "osx-swift")
        sh build.sh osx
        xc "-scheme 'RealmSwift' -configuration $CONFIGURATION build"
        destination="build/osx/swift-$REALM_XCODE_VERSION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/RealmSwift.framework" "$destination" "RealmSwift.framework"
        rm -rf "$destination/Realm.framework"
        cp -R build/osx/Realm.framework "$destination"
        exit 0
        ;;

    "catalyst")
        if (( $(xcode_version_major) < 11 )); then
            echo 'Building for Catalyst requires Xcode 11'
            exit 1
        fi

        xc "-scheme Realm -configuration $CONFIGURATION \
            REALM_CATALYST_FLAGS='-target x86_64-apple-ios13.0-macabi' \
            REALM_PLATFORM_SUFFIX='maccatalyst' \
            IS_MACCATALYST=YES"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/Realm.framework" "build/catalyst" "Realm.framework"
        ;;

    "catalyst-swift")
        if (( $(xcode_version_major) < 11 )); then
            echo 'Building for Catalyst requires Xcode 11'
            exit 1
        fi

        sh build.sh catalyst
        # FIXME: change this to just "-destination variant='Mac Catalyst'" once the CI machines are running 10.15
        xc "-scheme 'RealmSwift' -configuration $CONFIGURATION build \
            REALM_CATALYST_FLAGS='-target x86_64-apple-ios13.0-macabi' \
            REALM_PLATFORM_SUFFIX='maccatalyst' \
            SWIFT_DEPLOYMENT_TARGET='13.0-macabi' \
            SWIFT_PLATFORM_TARGET_PREFIX='ios' \
            IS_MACCATALYST=YES"
        destination="build/catalyst/swift-$REALM_XCODE_VERSION"
        clean_retrieve "build/DerivedData/Realm/Build/Products/$CONFIGURATION/RealmSwift.framework" "$destination" "RealmSwift.framework"
        rm -rf "$destination/Realm.framework"
        cp -R build/catalyst/Realm.framework "$destination"
        ;;

    "xcframework")
        if (( $(xcode_version_major) < 11 )); then
            echo 'Building a xcframework requires Xcode 11'
            exit 1
        fi

        export REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS BUILD_LIBRARY_FOR_DISTRIBUTION=YES REALM_OBJC_MACH_O_TYPE=staticlib"

        # Build all of the requested frameworks
        shift
        PLATFORMS="${*:-osx ios watchos tvos catalyst}"
        for platform in $PLATFORMS; do
            sh build.sh $platform-swift
        done

        # Assemble them into xcframeworks
        rm -rf build/*.xcframework
        find build/DerivedData/Realm/Build/Products -name 'Realm.framework' \
            | grep -v '\-static' \
            | sed 's/.*/-framework &/' \
            | xargs xcodebuild -create-xcframework -output build/Realm.xcframework
        find build/DerivedData/Realm/Build/Products -name 'RealmSwift.framework' \
            | sed 's/.*/-framework &/' \
            | xargs xcodebuild -create-xcframework -output build/RealmSwift.xcframework

        # strip-frameworks.sh isn't needed with xcframeworks since we don't
        # lipo together device/simulator libs
        find build/Realm.xcframework -name 'strip-frameworks.sh' -delete
        find build/RealmSwift.xcframework -name 'strip-frameworks.sh' -delete

        # swiftinterface files currently have incorrect name resolution which
        # results in the RealmSwift.Realm class name clashing with the Realm
        # module name. Work around this by renaming the Realm module to
        # RealmObjc. This is safe to do with a pre-built library because the
        # module name is unrelated to what symbols are exported by an obj-c
        # library, and we're statically linking the obj-c library into the
        # swift library so it doesn't need to be loaded at runtime.
        cd build
        cp -R Realm.xcframework RealmObjc.xcframework
        find RealmObjc.xcframework -name 'Realm.framework' \
            -execdir mv {} RealmObjc.framework \; || true 2> /dev/null
        find RealmObjc.xcframework -name '*.h' \
            -exec sed -i '' 's/Realm\//RealmObjc\//' {} \;
        find RealmObjc.xcframework -name 'module.modulemap' \
            -exec sed -i '' 's/module Realm/module RealmObjc/' {} \;
        sed -i '' 's/Realm.framework/RealmObjc.framework/' RealmObjc.xcframework/Info.plist

        find RealmSwift.xcframework -name '*.swiftinterface' \
            -exec sed -i '' 's/import Realm/import RealmObjc/' {} \;
        find RealmSwift.xcframework -name '*.swiftinterface' \
            -exec sed -i '' 's/Realm.RLM/RealmObjc.RLM/g' {} \;

        # Realm is statically linked into RealmSwift so we no longer actually
        # need the obj-c static library, and just need the framework shell.
        # Remove everything but placeholder.o so that there's still a library
        # to link against that just doesn't define any symbols.
        find RealmObjc.xcframework -name 'Realm' | while read file; do
            (
                cd $(dirname $file)
                if readlink Realm > /dev/null; then
                    ln -sf Versions/Current/RealmObjc Realm
                elif lipo -info Realm | grep -q 'Non-fat'; then
                    ar -t Realm | grep -v placeholder | tr '\n' '\0' | xargs -0 ar -d Realm >/dev/null 2>&1
                    ranlib Realm >/dev/null 2>&1
                else
                    for arch in $(lipo -info Realm | cut -f3 -d':'); do
                        lipo Realm -thin $arch -output tmp.a
                        ar -t tmp.a | grep -v placeholder | tr '\n' '\0' | xargs -0 ar -d tmp.a >/dev/null 2>&1
                        ranlib tmp.a >/dev/null 2>&1
                        lipo Realm -replace $arch tmp.a -output Realm
                        rm tmp.a
                    done
                fi
                mv Realm RealmObjc
            )
        done

        # We built Realm.framework as a static framework so that we could link
        # it into RealmSwift.framework and not have to deal with the runtime
        # implications of renaming the shared library, but we want the end
        # result to be that Realm.xcframework is a dynamic framework. Our build
        # system isn't really set up to build both static and dynamic versions
        # of it, so instead just turn each of the static libraries in
        # Realm.xcframework into a shared library.
        cd Realm.xcframework
        i=0
        while plist_get Info.plist "AvailableLibraries:$i" > /dev/null; do
            arch_dir_name="$(plist_get Info.plist "AvailableLibraries:$i:LibraryIdentifier")"
            platform="$(plist_get Info.plist "AvailableLibraries:$i:SupportedPlatform")"
            variant="$(plist_get Info.plist "AvailableLibraries:$i:SupportedPlatformVariant" 2> /dev/null || echo 'os')"
            deployment_target_name="$platform"
            install_name='@rpath/Realm.framework/Realm'
            bitcode_flag='-fembed-bitcode'
            if [ "$variant" = 'simulator' ]; then
                bitcode_flag=''
            fi
            case "$platform" in
              "macos")   sdk='macosx'; install_name='@rpath/Realm.framework/Versions/A/Realm'; bitcode_flag='';;
              "ios")     sdk="iphone$variant"; deployment_target_name='iphoneos';;
              "watchos") sdk="watch$variant";;
              "tvos")    sdk="appletv$variant";;
            esac
            deployment_target=$(grep -i "$deployment_target_name.*_DEPLOYMENT_TARGET" ../../Configuration/Base.xcconfig \
                                | sed 's/.*= \(.*\);/\1/')
            architectures=""
            j=0
            while plist_get Info.plist "AvailableLibraries:$i:SupportedArchitectures:$j" > /dev/null; do
                architectures="${architectures} -arch $(plist_get Info.plist "AvailableLibraries:$i:SupportedArchitectures:$j")"
                j=$(($j + 1))
            done

            (
                cd $arch_dir_name/Realm.framework
                realm_lib=$(readlink Realm || echo 'Realm')
                # feature_token.cpp.o depends on PKey, which isn't actually
                # present in the macOS build of the sync library. This normally
                # works fine because we never reference any symbols from
                # feature_token.cpp.o so it doesn't get pulled in at all, but
                # -all_load makes every object file in the input get linked
                # into the shared library.
                ar -d $realm_lib feature_token.cpp.o 2> /dev/null || true
                clang++ -shared $architectures \
                    -target ${platform}${deployment_target} \
                    -isysroot $(xcrun --sdk ${sdk} --show-sdk-path) \
                    -install_name "$install_name" \
                    -compatibility_version 1 -current_version 1 \
                    -fapplication-extension \
                    $bitcode_flag \
                    -Wl,-all_load \
                    -Wl,-unexported_symbol,'__Z*' \
                    -o realm.dylib \
                    Realm -lz
                mv realm.dylib $realm_lib
            )

            i=$(($i + 1))
        done

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
        if (( $(xcode_version_major) >= 11 )); then
            sh build.sh test-catalyst || failed=1
            sh build.sh test-catalyst-swift || failed=1
        fi
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
        xc "-scheme Realm -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 8' build-for-testing"
        xc "-scheme Realm -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 8' test"
        exit 0
        ;;

    "test-ios-swift")
        xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 8' build-for-testing"
        xc "-scheme RealmSwift -configuration $CONFIGURATION -sdk iphonesimulator -destination 'name=iPhone 8' test"
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
        xctest "-scheme Realm -configuration $CONFIGURATION -sdk appletvsimulator -destination 'name=$destination'"
        exit $?
        ;;

    "test-tvos-swift")
        destination="Apple TV"
        xctest "-scheme RealmSwift -configuration $CONFIGURATION -sdk appletvsimulator -destination 'name=$destination'"
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
        xctest "-scheme Realm -configuration $CONFIGURATION $COVERAGE_PARAMS"
        exit 0
        ;;

    "test-osx-swift")
        xctest "-scheme RealmSwift -configuration $CONFIGURATION"
        exit 0
        ;;

    "test-osx-object-server")
        xctest "-scheme 'Object Server Tests' -configuration $CONFIGURATION -sdk macosx"
        exit 0
        ;;

    test-swiftpm*)
        SANITIZER=$(echo $COMMAND | cut -d - -f 3)
        if [ -n "$SANITIZER" ]; then
            SANITIZER="--sanitize $SANITIZER"
            export ASAN_OPTIONS='check_initialization_order=true:detect_stack_use_after_return=true'
        fi
        xcrun swift test --configuration $(echo $CONFIGURATION | tr "[:upper:]" "[:lower:]") $SANITIZER
        exit 0
        ;;

    "test-catalyst")
        export REALM_SDKROOT=iphoneos
        xc "-scheme Realm -configuration $CONFIGURATION -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY='' build-for-testing"
        xc "-scheme Realm -configuration $CONFIGURATION -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY='' test"
        exit 0
        ;;

    "test-catalyst-swift")
        export REALM_SDKROOT=iphoneos
        xc "-scheme RealmSwift -configuration $CONFIGURATION -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY='' build-for-testing"
        xc "-scheme RealmSwift -configuration $CONFIGURATION -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGN_IDENTITY='' test"
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
        if (( $(xcode_version_major) >= 11 )); then
            sh build.sh verify-catalyst
            sh build.sh verify-catalyst-swift
        fi
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
        sh build.sh test-watchos-objc-cocoapods
        sh build.sh test-watchos-swift-cocoapods
        ;;

    verify-cocoapods-ios-dynamic)
        PLATFORM=$(echo $COMMAND | cut -d - -f 3)
        # https://github.com/CocoaPods/CocoaPods/issues/7708
        export EXPANDED_CODE_SIGN_IDENTITY=''
        cd examples/installation
        sh build.sh test-ios-objc-cocoapods-dynamic
        ;;

    verify-cocoapods-*)
        PLATFORM=$(echo $COMMAND | cut -d - -f 3)
        # https://github.com/CocoaPods/CocoaPods/issues/7708
        export EXPANDED_CODE_SIGN_IDENTITY=''
        cd examples/installation
        sh build.sh test-$PLATFORM-objc-cocoapods
        sh build.sh test-$PLATFORM-swift-cocoapods
        ;;

    "verify-osx-encryption")
        REALM_ENCRYPT_ALL=YES sh build.sh test-osx
        exit 0
        ;;

    "verify-osx")
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

    "verify-ios-static")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/ios/objc/RealmExamples.xcworkspace" sh build.sh test-ios-static
        sh build.sh examples-ios
        ;;

    "verify-ios-dynamic")
        sh build.sh test-ios-dynamic
        ;;

    "verify-ios-swift")
        REALM_EXTRA_BUILD_ARGUMENTS="$REALM_EXTRA_BUILD_ARGUMENTS -workspace examples/ios/swift/RealmExamples.xcworkspace" sh build.sh test-ios-swift
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
        sh build.sh examples-tvos
        exit 0
        ;;

    "verify-tvos-swift")
        sh build.sh test-tvos-swift
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

    verify-swiftpm*)
        sh build.sh test-$(echo $COMMAND | cut -d - -f 2-)
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
        xc "-workspace $workspace -scheme Simple -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme TableView -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Migration -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Backlink -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme GroupedTableView -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme RACTableView -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Encryption -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Draw -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"

        if [ ! -z "${JENKINS_HOME}" ]; then
            xc "-workspace $workspace -scheme Extension -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        fi

        exit 0
        ;;

    "examples-ios-swift")
        sh build.sh prelaunch-simulator
        workspace="examples/ios/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_XCODE_VERSION}"
        fi

        xc "-workspace $workspace -scheme Simple -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme TableView -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Migration -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Encryption -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme Backlink -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme GroupedTableView -configuration $CONFIGURATION -destination 'name=iPhone 8' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    "examples-osx")
        xc "-workspace examples/osx/objc/RealmExamples.xcworkspace -scheme JSONImport -configuration ${CONFIGURATION} build ${CODESIGN_PARAMS}"
        ;;

    "examples-tvos")
        workspace="examples/tvos/objc/RealmExamples.xcworkspace"
        destination="Apple TV"

        xc "-workspace $workspace -scheme DownloadCache -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme PreloadedData -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    "examples-tvos-swift")
        workspace="examples/tvos/swift/RealmExamples.xcworkspace"
        if [[ ! -d "$workspace" ]]; then
            workspace="${workspace/swift/swift-$REALM_XCODE_VERSION}"
        fi

        destination="Apple TV"
        xc "-workspace $workspace -scheme DownloadCache -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        xc "-workspace $workspace -scheme PreloadedData -configuration $CONFIGURATION -destination 'name=$destination' build ${CODESIGN_PARAMS}"
        exit 0
        ;;

    ######################################
    # Versioning
    ######################################
    "get-version")
        echo "$(plist_get 'Realm/Realm-Info.plist' 'CFBundleShortVersionString')"
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

          echo '' > Realm/RLMPlatform.h
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
        export REALM_DISABLE_ANALYTICS=1
        export REALM_DISABLE_UPDATE_CHECKER=1
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
            export REALM_EXTRA_BUILD_ARGUMENTS='GCC_GENERATE_DEBUGGING_SYMBOLS=NO -allowProvisioningUpdates'
            if [[ ${target} != *"osx"* ]];then
                sh build.sh prelaunch-simulator
            fi

            source $(brew --prefix nvm)/nvm.sh --no-use
            export REALM_NODE_PATH="$(nvm which 8)"

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

    "package-test-examples-objc")
        if ! VERSION=$(echo realm-objc-*.zip | egrep -o '\d*\.\d*\.\d*-[a-z]*(\.\d*)?'); then
            VERSION=$(echo realm-objc-*.zip | egrep -o '\d*\.\d*\.\d*')
        fi
        OBJC="realm-objc-${VERSION}"
        unzip ${OBJC}.zip

        cp $0 ${OBJC}
        cp -r ${source_root}/scripts ${OBJC}
        cd ${OBJC}
        sh build.sh examples-ios
        sh build.sh examples-tvos
        sh build.sh examples-osx
        cd ..
        rm -rf ${OBJC}
        ;;

    "package-test-examples-swift")
        if ! VERSION=$(echo realm-swift-*.zip | egrep -o '\d*\.\d*\.\d*-[a-z]*(\.\d*)?'); then
            VERSION=$(echo realm-swift-*.zip | egrep -o '\d*\.\d*\.\d*')
        fi
        SWIFT="realm-swift-${VERSION}"
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

    "package")
        PLATFORM="$2"
        REALM_SWIFT_VERSION=

        set_xcode_and_swift_versions

        if [[ "$PLATFORM" = "catalyst" ]] && (( $(xcode_version_major) < 11 )); then
            mkdir -p build/catalyst/swift-$REALM_XCODE_VERSION
        else
            sh build.sh prelaunch-simulator
            sh build.sh $PLATFORM-swift
        fi

        cd build/$PLATFORM
        zip --symlinks -r realm-framework-$PLATFORM-$REALM_XCODE_VERSION.zip swift-$REALM_XCODE_VERSION
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

            unzip ${WORKSPACE}/realm-framework-ios-static.zip -d ${FOLDER}/ios/static
            for platform in osx ios watchos tvos catalyst; do
                unzip ${WORKSPACE}/realm-framework-${platform}-${REALM_XCODE_VERSION}.zip -d ${FOLDER}/${platform}
                mv ${FOLDER}/${platform}/swift-*/Realm.framework ${FOLDER}/${platform}
                rm -r ${FOLDER}/${platform}/swift-*
            done

            mv ${FOLDER}/ios/Realm.framework ${FOLDER}/ios/dynamic
        else
            for platform in osx ios watchos tvos catalyst; do
                find ${WORKSPACE} -name "realm-framework-$platform-*.zip" \
                                  -maxdepth 1 \
                                  -exec unzip {} -d ${FOLDER}/${platform} \;
            done
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
        cp build/ios-static/realm-framework-ios-static.zip .
        sh build.sh package ios
        cp build/ios/realm-framework-ios-$REALM_XCODE_VERSION.zip .

        echo 'Packaging macOS'
        sh build.sh package osx
        cp build/osx/realm-framework-osx-$REALM_XCODE_VERSION.zip .

        echo 'Packaging watchOS'
        sh build.sh package watchos
        cp build/watchos/realm-framework-watchos-$REALM_XCODE_VERSION.zip .

        echo 'Packaging tvOS'
        sh build.sh package tvos
        cp build/tvos/realm-framework-tvos-$REALM_XCODE_VERSION.zip .

        echo 'Packaging Catalyst'
        sh build.sh package catalyst
        cp build/catalyst/realm-framework-catalyst-$REALM_XCODE_VERSION.zip .

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
* <How to hit and notice issue? what was the impact?> ([#????](https://github.com/realm/realm-js/issues/????), since v?.?.?)
* None.

<!-- ### Breaking Changes - ONLY INCLUDE FOR NEW MAJOR version -->

### Compatibility
* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* APIs are backwards compatible with all previous releases in the 4.x.y series.
* Carthage release for Swift is built with Xcode 11.3.

### Internal
Upgraded realm-core from ? to ?
Upgraded realm-sync from ? to ?

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
