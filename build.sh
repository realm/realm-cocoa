#!/bin/sh

##################################################################################
# Custom build tool for Realm Objective C binding.
#
# (C) Copyright 2011-2014 by realm.io.
##################################################################################

# Warning: pipefail is not a POSIX compatible option, but on OS X it works just fine.
#          OS X uses a POSIX complain version of bash as /bin/sh, but apparently it does
#          not strip away this feature. Also, this will fail if somebody forces the script
#          to be run with zsh.
set -o pipefail

# You can override the version of the core library
# Otherwise, use the default value
if [ -z "$REALM_CORE_VERSION" ]; then
    REALM_CORE_VERSION=0.80.3
fi

PATH=/usr/local/bin:/usr/bin:/bin:/usr/libexec:$PATH

if ! [ -z "${JENKINS_HOME}" ]; then
    XCPRETTY_PARAMS="--no-utf --report junit --output build/reports/junit.xml"
    CODESIGN_PARAMS="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO"
fi

usage() {
cat <<EOF
Usage: sh $0 command [argument]

command:
  download-core:           downloads core library (binary version)
  clean [xcmode]:          clean up/remove all generated files
  build [xcmode]:          builds iOS and OS X frameworks with release configuration
  build-debug [xcmode]:    builds iOS and OS X frameworks with debug configuration
  ios [xcmode]:            builds iOS framework with release configuration
  ios-debug [xcmode]:      builds iOS framework with debug configuration
  osx [xcmode]:            builds OS X framework with release configuration
  osx-debug [xcmode]:      builds OS X framework with debug configuration
  test-ios [xcmode]:       tests iOS framework with release configuration
  test-osx [xcmode]:       tests OSX framework with release configuration
  test [xcmode]:           tests iOS and OS X frameworks with release configuration
  test-debug [xcmode]:     tests iOS and OS X frameworks with debug configuration
  test-all [xcmode]:       tests iOS and OS X frameworks with debug and release configurations, on Xcode 5 and Xcode 6
  examples [xcmode]:       builds all examples in examples/ in release configuration
  examples-debug [xcmode]: builds all examples in examples/ in debug configuration
  browser [xcmode]:        builds the RealmBrowser OSX app
  verify [xcmode]:         cleans, removes docs/output/, then runs docs, test-all and examples
  docs:                    builds docs in docs/output
  get-version:             get the current version
  set-version version:     set the version

argument:
  xcmode:  xcodebuild (default), xcpretty or xctool
  version: version in the x.y.z format
EOF
}

######################################
# Variables
######################################

# Xcode sets this variable - set to current directory if running standalone
if [ -z "$SRCROOT" ]; then
    SRCROOT="$(pwd)"
fi

COMMAND="$1"
XCMODE="$2"
: ${XCMODE:=xcodebuild} # must be one of: xcodebuild (default), xcpretty, xctool

######################################
# Xcode Helpers
######################################

if [ -z "$XCODE_VERSION" ]; then
    XCODE_VERSION=5
fi

xcode5() {
    ln -s /Applications/Xcode.app/Contents/Developer/usr/bin build/bin || exit 1
    PATH=./build/bin:$PATH xcodebuild -IDECustomDerivedDataLocation="${SRCROOT}/build/DerivedData" $@
}

xcode6() {
    ln -s /Applications/Xcode6-Beta3.app/Contents/Developer/usr/bin build/bin || exit 1
    PATH=./build/bin:$PATH xcodebuild -IDECustomDerivedDataLocation="${SRCROOT}/build/DerivedData" $@
}

xcode() {
    rm -rf build/bin
    mkdir -p build/DerivedData
    case "$XCODE_VERSION" in
        5)
            xcode5 $@
            ;;
        6)
            xcode6 $@
            ;;
        *)
            echo "Unsupported version of xcode specified"
            exit 1
    esac
}

xc() {
    echo "Building target \"$1\" with xcode${XCODE_VERSION}"
    if [[ "$XCMODE" == "xcodebuild" ]]; then
        xcode $1 || exit 1
    elif [[ "$XCMODE" == "xcpretty" ]]; then
        mkdir -p build
        xcode $1 | tee build/build.log | xcpretty -c ${XCPRETTY_PARAMS}
        if [ "$?" -ne 0 ]; then
            echo "The raw xcodebuild output is available in build/build.log"
            exit 1
        fi
    elif [[ "$XCMODE" == "xctool" ]]; then
        xctool $1 || exit 1
    fi
}

xcrealm() {
    PROJECT=Realm.xcodeproj
    if [[ "$XCODE_VERSION" == "6" ]]; then
        PROJECT=Realm-Xcode6.xcodeproj
    fi
    xc "-project $PROJECT $1"
}

######################################
# Input Validation
######################################

if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
    usage
    exit 1
fi

######################################
# Download Core
######################################

download_core() {
    echo "Downloading dependency: core ${REALM_CORE_VERSION}"
    TMP_DIR="$(mktemp -dt "$0")"
    curl -L -s "http://static.realm.io/downloads/core/realm-core-${REALM_CORE_VERSION}.zip" -o "${TMP_DIR}/core-${REALM_CORE_VERSION}.zip" || exit 1
    (
        cd "${TMP_DIR}"
        unzip "core-${REALM_CORE_VERSION}.zip" || exit 1
        mv core core-${REALM_CORE_VERSION} || exit 1
        rm -f "core-${REALM_CORE_VERSION}.zip" || exit 1
    )
    rm -rf core-${REALM_CORE_VERSION} core || exit 1
    mv ${TMP_DIR}/core-${REALM_CORE_VERSION} . || exit 1
    ln -s core-${REALM_CORE_VERSION} core || exit 1
}

######################################
# Command Handling
######################################

case "$COMMAND" in

    ######################################
    # Clean
    ######################################
    "clean")
        rm -rf build || exit 1
        exit 0
        ;;

    ######################################
    # Download Core Library
    ######################################
    "download-core")
        if ! [ -L core ]; then
            echo "core is not a symlink. Deleting..."
            rm -rf core
            download_core
        elif ! $(head -n 1 core/release_notes.txt | grep ${REALM_CORE_VERSION} >/dev/null); then
            download_core
        else
            echo "The core library seems to be up to date."
            echo "To force an update remove the folder 'core' and rerun."
        fi
        exit 0
        ;;

    ######################################
    # Building
    ######################################
    "build")
        sh build.sh ios "$XCMODE" || exit 1
        sh build.sh osx "$XCMODE" || exit 1
        exit 0
        ;;

    "build-debug")
        sh build.sh ios-debug "$XCMODE" || exit 1
        sh build.sh osx-debug "$XCMODE" || exit 1
        exit 0
        ;;

    "ios")
        xcrealm "-scheme iOS -configuration Release"
        exit 0
        ;;

    "osx")
        xcrealm "-scheme OSX -configuration Release"
        exit 0
        ;;

    "ios-debug")
        xcrealm "-scheme iOS -configuration Debug"
        exit 0
        ;;

    "osx-debug")
        xcrealm "-scheme OSX -configuration Debug"
        exit 0
        ;;

    "docs")
        sh scripts/build-docs.sh || exit 1
        exit 0
        ;;

    ######################################
    # Testing
    ######################################
    "test")
        sh build.sh test-ios "$XCMODE"
        sh build.sh test-osx "$XCMODE"
        exit 0
        ;;

    "test-debug")
        sh build.sh test-osx-debug "$XCMODE"
        sh build.sh test-ios-debug "$XCMODE"
        exit 0
        ;;

    "test-all")
        sh build.sh test "$XCMODE" || exit 1
        sh build.sh test-debug "$XCMODE" || exit 1
        XCODE_VERSION=6 sh build.sh test "$XCMODE" || exit 1
        XCODE_VERSION=6 sh build.sh test-debug "$XCMODE" || exit 1
        ;;

    "test-ios")
        xcrealm "-scheme iOS -configuration Release -sdk iphonesimulator test"
        exit 0
        ;;

    "test-osx")
        xcrealm "-scheme OSX -configuration Release test"
        exit 0
        ;;

    "test-ios-debug")
        xcrealm "-scheme iOS -configuration Debug -sdk iphonesimulator test"
        exit 0
        ;;

    "test-osx-debug")
        xcrealm "-scheme OSX -configuration Debug test"
        exit 0
        ;;

    "test-cover")
        echo "Not yet implemented"
        exit 0
        ;;

    "verify")
        sh build.sh docs || exit 1
        sh build.sh test-all "$XCMODE" || exit 1
        sh build.sh examples "$XCMODE" || exit 1
        exit 0
        ;;

    ######################################
    # Docs
    ######################################
    "docs")
        sh scripts/build-docs.sh || exit 1
        exit 0
        ;;

    ######################################
    # Examples
    ######################################
    "examples")
        cd examples
        if [[ "$XCODE_VERSION" == "6" ]]; then
            xc "-project swift/RealmSwiftSimpleExample/RealmSwiftSimpleExample.xcodeproj -scheme RealmSwiftSimpleExample -configuration Release clean build ${CODESIGN_PARAMS}"
        	xc "-project swift/RealmSwiftTableViewExample/RealmSwiftTableViewExample.xcodeproj -scheme RealmSwiftTableViewExample -configuration Release clean build ${CODESIGN_PARAMS}"
        fi
        xc "-project objc/RealmSimpleExample/RealmSimpleExample.xcodeproj -scheme RealmSimpleExample -configuration Release clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmTableViewExample/RealmTableViewExample.xcodeproj -scheme RealmTableViewExample -configuration Release clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmMigrationExample/RealmMigrationExample.xcodeproj -scheme RealmMigrationExample -configuration Release clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmRestExample/RealmRestExample.xcodeproj -scheme RealmRestExample -configuration Release clean build ${CODESIGN_PARAMS}"

        # Not all examples can be built using Xcode 6
        if [[ "$XCODE_VERSION" != "6" ]]; then
            xc "-project objc/RealmJSONImportExample/RealmJSONImportExample.xcodeproj -scheme RealmJSONImportExample -configuration Release clean build ${CODESIGN_PARAMS}"
        fi
        exit 0
        ;;

    "examples-debug")
        cd examples
        if [[ "$XCODE_VERSION" == "6" ]]; then
            xc "-project swift/RealmSwiftSimpleExample/RealmSwiftSimpleExample.xcodeproj -scheme RealmSwiftSimpleExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        	xc "-project swift/RealmSwiftTableViewExample/RealmSwiftTableViewExample.xcodeproj -scheme RealmSwiftTableViewExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        fi
        xc "-project objc/RealmSimpleExample/RealmSimpleExample.xcodeproj -scheme RealmSimpleExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmTableViewExample/RealmTableViewExample.xcodeproj -scheme RealmTableViewExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmMigrationExample/RealmMigrationExample.xcodeproj -scheme RealmMigrationExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        xc "-project objc/RealmRestExample/RealmRestExample.xcodeproj -scheme RealmRestExample -configuration Debug clean build ${CODESIGN_PARAMS}"

        # Not all examples can be built using Xcode 6
        if [[ "$XCODE_VERSION" != "6" ]]; then
            xc "-project objc/RealmJSONImportExample/RealmJSONImportExample.xcodeproj -scheme RealmJSONImportExample -configuration Debug clean build ${CODESIGN_PARAMS}"
        fi 
        exit 0
        ;;

    ######################################
    # Browser
    ######################################
    "browser")
        if [[ "$XCODE_VERSION" != "6" ]]; then
            xc "-project tools/RealmBrowser/RealmBrowser.xcodeproj -scheme RealmBrowser -configuration Release clean build ${CODESIGN_PARAMS}"
        else
            echo "Realm Browser can only be built with Xcode 5."
            exit 1
        fi
        exit 0
        ;;

    ######################################
    # Versioning
    ######################################
    "get-version")
        version_file="Realm/Realm-Info.plist"
        echo "$(PlistBuddy -c "Print :CFBundleVersion" "$version_file")"
        exit 0
        ;;

    "set-version")
        realm_version="$2"
        version_file="Realm/Realm-Info.plist"

        if [ -z "$realm_version" ]; then
            echo "You must specify a version."
            exit 1
        fi 
        PlistBuddy -c "Set :CFBundleVersion $realm_version" "$version_file"
        PlistBuddy -c "Set :CFBundleShortVersionString $realm_version" "$version_file"
        exit 0
        ;;

    ######################################
    # Releasing
    ######################################
    "prepare-release")
        # Clean & Build iOS/OSX
        sh build.sh clean "$XCMODE" || exit 1
        sh build.sh test "$XCMODE" || exit 1
        
        # Build Browser
        sh build.sh browser "$XCMODE" || exit 1

        # Build and upload docs
        sh build.sh docs || exit 1
        VERSION=$(sh build.sh get-version)
        s3cmd put -r docs/output/$VERSION s3://static.realm.io/docs/cocoa/ || exit 1
        
        # Zip & upload release
        RELEASE_DIR=$(mktemp -dt "$0")
        mkdir -p $RELEASE_DIR/browser $RELEASE_DIR/ios $RELEASE_DIR/osx $RELEASE_DIR/examples/objc $RELEASE_DIR/plugin || exit 1
        cp -R plugin $RELEASE_DIR || exit 1
        cp -R build/DerivedData/RealmBrowser-*/Build/Products/Release/Realm\ Browser.app "$RELEASE_DIR/browser/Realm Browser.app" || exit 1
        cp -R build/Release/Realm.framework $RELEASE_DIR/ios/Realm.framework || exit 1
        cp -R build/DerivedData/Realm-*/Build/Products/Release/Realm.framework $RELEASE_DIR/osx/Realm.framework || exit 1
        # TODO: Move examples in accordance with this structure: https://github.com/realm/realm-cocoa/pull/631#issuecomment-49680698
        cp -R examples/objc $RELEASE_DIR/examples || exit 1
        cp LICENSE $RELEASE_DIR/LICENSE.txt || exit 1
        # Generate docs.webloc
        echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\
        <plist version=\"1.0\"><dict><key>URL</key><string>http://realm.io/docs/cocoa/${VERSION}</string></dict></plist>" > $RELEASE_DIR/docs.webloc || exit 1

        # TODO: Update framework path in all example projects

        ZIPNAME=realm-cocoa-$VERSION.zip
        (cd $RELEASE_DIR && zip -r $ZIPNAME * || exit 1)
        s3cmd put $RELEASE_DIR/$ZIPNAME s3://static.realm.io/downloads/cocoa/ || exit 1

        # Zip & upload CocoaPods release
        COCOAPODS_RELEASE_DIR=$(mktemp -dt "$0")
        mkdir -p $COCOAPODS_RELEASE_DIR/ios $COCOAPODS_RELEASE_DIR/osx || exit 1
        cp -R build/Release/Realm.framework $COCOAPODS_RELEASE_DIR/ios/Realm.framework || exit 1
        cp -R build/DerivedData/Realm-*/Build/Products/Release/Realm.framework $RELEASE_DIR/osx/Realm.framework || exit 1

        COCOAPODS_ZIPNAME=realm-cocoapods-$VERSION.zip
        (cd $COCOAPODS_RELEASE_DIR && zip -r $COCOAPODS_ZIPNAME * || exit 1)
        s3cmd put $COCOAPODS_RELEASE_DIR/$COCOAPODS_ZIPNAME s3://static.realm.io/downloads/cocoapods/ || exit 1

        echo "Realm Cocoa $VERSION was successfully prepared for released.\nPlease perform manual tests and then run 'deploy-release' to finalize the release process."
        exit 0
        ;;

    "deploy-release")
        TMP_DIR=$(mktemp -dt "$0")
        VERSION=$(sh build.sh get-version)
        ZIPNAME=realm-cocoa-$VERSION.zip

        # Update "latest" redirect on static.realm.io
        touch $TMP_DIR/latest || exit 1
        s3cmd put $TMP_DIR/latest --add-header "x-amz-website-redirect-location:http://static.realm.io/downloads/cocoa/$ZIPNAME" s3://static.realm.io/downloads/cocoa/ || exit 1

        # Submit to CocoaPods
        sh build.sh pod-deploy || exit 1

        echo "Realm Cocoa $VERSION was successfully released"
        exit 0
        ;;

    "pod-deploy")
        pod spec lint || exit 1
        pod trunk push || exit 1
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac
