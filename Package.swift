// swift-tools-version:5.3

import PackageDescription
import Foundation

let coreVersionStr = "11.0.4"
let cocoaVersionStr = "10.10.0"

let coreVersionPieces = coreVersionStr.split(separator: ".")
let coreVersionExtra = coreVersionPieces[2].split(separator: "-")
let cxxSettings: [CXXSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .define("REALM_SPM", to: "1"),
    .define("REALM_ENABLE_SYNC", to: "1"),
    .define("REALM_COCOA_VERSION", to: "@\"\(cocoaVersionStr)\""),
    .define("REALM_VERSION", to: "\"\(coreVersionStr)\""),

    .define("REALM_DEBUG", .when(configuration: .debug)),
    .define("REALM_NO_CONFIG"),
    .define("REALM_INSTALL_LIBEXECDIR", to: ""),
    .define("REALM_ENABLE_ASSERTIONS", to: "1"),
    .define("REALM_ENABLE_ENCRYPTION", to: "1"),

    .define("REALM_VERSION_MAJOR", to: String(coreVersionPieces[0])),
    .define("REALM_VERSION_MINOR", to: String(coreVersionPieces[1])),
    .define("REALM_VERSION_PATCH", to: String(coreVersionExtra[0])),
    .define("REALM_VERSION_EXTRA", to: "\"\(coreVersionExtra.count > 1 ? String(coreVersionExtra[1]) : "")\""),
    .define("REALM_VERSION_STRING", to: "\"\(coreVersionStr)\""),
]
let testCxxSettings: [CXXSetting] = cxxSettings + [
    // Command-line `swift build` resolves header search paths
    // relative to the package root, while Xcode resolves them
    // relative to the target root, so we need both.
    .headerSearchPath("Realm"),
    .headerSearchPath(".."),
]

// Xcode 12.5's xctest crashes when reading obj-c metadata if the Swift tests
// aren't built targeting macOS 11. We still want all of the non-test code to
// target the normal lower version, though.
func hostMachineArch() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineBytes = Mirror(reflecting: systemInfo.machine).children.map { UInt8($0.value as! Int8) }.prefix { $0 != 0 }
    return String(bytes: machineBytes, encoding: .utf8)!
}
let testSwiftSettings: [SwiftSetting]?
#if swift(>=5.4)
testSwiftSettings = [.unsafeFlags(["-target", "\(hostMachineArch())-apple-macosx11.0"])]
#else
testSwiftSettings = nil
#endif

// SPM requires all targets to explicitly include or exclude every file, which
// gets very awkward when we have four targets building from a single directory
let objectServerTestSources = [
    "Object-Server-Tests-Bridging-Header.h",
    "ObjectServerTests-Info.plist",
    "RLMBSONTests.mm",
    "RLMCollectionSyncTests.mm",
    "RLMObjectServerPartitionTests.mm",
    "RLMObjectServerTests.mm",
    "RLMSyncTestCase.h",
    "RLMSyncTestCase.mm",
    "RLMTestUtils.h",
    "RLMTestUtils.m",
    "RLMUser+ObjectServerTests.h",
    "RLMUser+ObjectServerTests.mm",
    "RLMWatchTestUtility.h",
    "RLMWatchTestUtility.m",
    "RealmServer.swift",
    "SwiftCollectionSyncTests.swift",
    "SwiftObjectServerPartitionTests.swift",
    "SwiftObjectServerTests.swift",
    "SwiftSyncTestCase.swift",
    "TimeoutProxyServer.swift",
    "WatchTestUtility.swift",
    "certificates",
    "include",
    "setup_baas.rb",
]

func objectServerTestSupportTarget(name: String, dependencies: [Target.Dependency], sources: [String]) -> Target {
    .target(
        name: name,
        dependencies: dependencies,
        path: "Realm/ObjectServerTests",
        exclude: objectServerTestSources.filter { !sources.contains($0) },
        sources: sources,
        cxxSettings: testCxxSettings,
        swiftSettings: testSwiftSettings
    )
}

func objectServerTestTarget(name: String, sources: [String]) -> Target {
    .testTarget(
        name: name,
        dependencies: ["RealmSwift", "RealmTestSupport", "RealmSyncTestSupport", "RealmSwiftSyncTestSupport"],
        path: "Realm/ObjectServerTests",
        exclude: objectServerTestSources.filter { !sources.contains($0) },
        sources: sources,
        cxxSettings: testCxxSettings,
        swiftSettings: testSwiftSettings
    )
}

let package = Package(
    name: "Realm",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v11),
        .tvOS(.v9),
        .watchOS(.v2)
    ],
    products: [
        .library(
            name: "Realm",
            targets: ["Realm"]),
        .library(
            name: "RealmSwift",
            targets: ["Realm", "RealmSwift"]),
    ],
    dependencies: [
        .package(name: "RealmDatabase", url: "https://github.com/realm/realm-core", .exact(Version(coreVersionStr)!))
    ],
    targets: [
      .target(
            name: "Realm",
            dependencies: [.product(name: "RealmCore", package: "RealmDatabase")],
            path: ".",
            exclude: [
                "CHANGELOG.md",
                "CONTRIBUTING.md",
                "Carthage",
                "Configuration",
                "Jenkinsfile.releasability",
                "LICENSE",
                "Package.swift",
                "README.md",
                "Realm.podspec",
                "Realm.xcodeproj",
                "Realm/ObjectServerTests",
                "Realm/RLMPlatform.h.in",
                "Realm/Realm-Info.plist",
                "Realm/Swift/RLMSupport.swift",
                "Realm/TestUtils",
                "Realm/Tests",
                "RealmSwift",
                "RealmSwift.podspec",
                "SUPPORT.md",
                "build.sh",
                "contrib",
                "dependencies.list",
                "docs",
                "examples",
                "include",
                "logo.png",
                "plugin",
                "scripts",
                "tools",
            ],
            sources: [
                "Realm/RLMAccessor.mm",
                "Realm/RLMAnalytics.mm",
                "Realm/RLMArray.mm",
                "Realm/RLMClassInfo.mm",
                "Realm/RLMCollection.mm",
                "Realm/RLMConstants.m",
                "Realm/RLMDecimal128.mm",
                "Realm/RLMDictionary.mm",
                "Realm/RLMEmbeddedObject.mm",
                "Realm/RLMManagedArray.mm",
                "Realm/RLMManagedDictionary.mm",
                "Realm/RLMManagedSet.mm",
                "Realm/RLMMigration.mm",
                "Realm/RLMObject.mm",
                "Realm/RLMObjectBase.mm",
                "Realm/RLMObjectId.mm",
                "Realm/RLMObjectSchema.mm",
                "Realm/RLMObjectStore.mm",
                "Realm/RLMObservation.mm",
                "Realm/RLMPredicateUtil.mm",
                "Realm/RLMProperty.mm",
                "Realm/RLMQueryUtil.mm",
                "Realm/RLMRealm.mm",
                "Realm/RLMRealmConfiguration.mm",
                "Realm/RLMRealmUtil.mm",
                "Realm/RLMResults.mm",
                "Realm/RLMSchema.mm",
                "Realm/RLMSet.mm",
                "Realm/RLMSwiftCollectionBase.mm",
                "Realm/RLMSwiftSupport.m",
                "Realm/RLMSwiftValueStorage.mm",
                "Realm/RLMThreadSafeReference.mm",
                "Realm/RLMUpdateChecker.mm",
                "Realm/RLMUtil.mm",
                "Realm/RLMUUID.mm",
                "Realm/RLMValue.mm",

                // Sync source files
                "Realm/NSError+RLMSync.m",
                "Realm/RLMApp.mm",
                "Realm/RLMAPIKeyAuth.mm",
                "Realm/RLMBSON.mm",
                "Realm/RLMCredentials.mm",
                "Realm/RLMEmailPasswordAuth.mm",
                "Realm/RLMFindOneAndModifyOptions.mm",
                "Realm/RLMFindOptions.mm",
                "Realm/RLMMongoClient.mm",
                "Realm/RLMMongoCollection.mm",
                "Realm/RLMNetworkTransport.mm",
                "Realm/RLMProviderClient.mm",
                "Realm/RLMPushClient.mm",
                "Realm/RLMRealm+Sync.mm",
                "Realm/RLMRealmConfiguration+Sync.mm",
                "Realm/RLMSyncConfiguration.mm",
                "Realm/RLMSyncManager.mm",
                "Realm/RLMSyncSession.mm",
                "Realm/RLMSyncUtil.mm",
                "Realm/RLMUpdateResult.mm",
                "Realm/RLMUser.mm",
                "Realm/RLMUserAPIKey.mm"
            ],
            publicHeadersPath: "include",
            cxxSettings: cxxSettings
        ),
        .target(
            name: "RealmSwift",
            dependencies: ["Realm"],
            path: "RealmSwift",
            exclude: [
                "Nonsync.swift",
                "RealmSwift-Info.plist",
                "Tests",
            ]
        ),
        .target(
            name: "RealmTestSupport",
            dependencies: ["Realm"],
            path: "Realm/TestUtils",
            cxxSettings: testCxxSettings
        ),
        .testTarget(
            name: "RealmTests",
            dependencies: ["Realm", "RealmTestSupport"],
            path: "Realm/Tests",
            exclude: [
                "PrimitiveArrayPropertyTests.tpl.m",
                "PrimitiveDictionaryPropertyTests.tpl.m",
                "PrimitiveRLMValuePropertyTests.tpl.m",
                "PrimitiveSetPropertyTests.tpl.m",
                "RealmTests-Info.plist",
                "Swift",
                "SwiftUITestHost",
                "SwiftUITestHostUITests",
                "TestHost",
                "array_tests.py",
                "dictionary_tests.py",
                "fileformat-pre-null.realm",
                "mixed_tests.py",
                "set_tests.py",
                "SwifttUISyncTestHost",
                "SwifttUISyncTestHostUITests"
            ],
            cxxSettings: testCxxSettings
        ),
        .testTarget(
            name: "RealmObjcSwiftTests",
            dependencies: ["Realm", "RealmTestSupport"],
            path: "Realm/Tests/Swift",
            exclude: ["RealmObjcSwiftTests-Info.plist"],
            swiftSettings: testSwiftSettings
        ),
        .testTarget(
            name: "RealmSwiftTests",
            dependencies: ["RealmSwift", "RealmTestSupport"],
            path: "RealmSwift/Tests",
            exclude: ["RealmSwiftTests-Info.plist"],
            swiftSettings: testSwiftSettings
        ),

        // Object server tests have support code written in both obj-c and
        // Swift which is used by both the obj-c and swift test code. SPM
        // doesn't support mixed targets, so this ends up requiring four
        // different targest.
        objectServerTestSupportTarget(
            name: "RealmSyncTestSupport",
            dependencies: ["Realm", "RealmSwift", "RealmTestSupport"],
            sources: ["RLMSyncTestCase.mm", "RLMUser+ObjectServerTests.mm"]
        ),
        objectServerTestSupportTarget(
            name: "RealmSwiftSyncTestSupport",
            dependencies: ["RealmSwift", "RealmTestSupport", "RealmSyncTestSupport"],
            sources: [
                 "SwiftSyncTestCase.swift",
                 "TimeoutProxyServer.swift",
                 "WatchTestUtility.swift",
                 "RealmServer.swift"
            ]
        ),
        objectServerTestTarget(
            name: "SwiftObjectServerTests",
            sources: [
                "SwiftObjectServerTests.swift",
                "SwiftCollectionSyncTests.swift",
                "SwiftObjectServerPartitionTests.swift",
            ]
        ),
        objectServerTestTarget(
            name: "ObjcObjectServerTests",
            sources: [
                "RLMBSONTests.mm",
                "RLMCollectionSyncTests.mm",
                "RLMObjectServerPartitionTests.mm",
                "RLMObjectServerTests.mm",
                "RLMWatchTestUtility.m",
            ]
        )
    ],
    cxxLanguageStandard: .cxx1z
)
