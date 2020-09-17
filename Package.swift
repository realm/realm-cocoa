// swift-tools-version:5.3

import PackageDescription
import Foundation

let coreVersionStr = "6.0.26"
let syncVersionStr = "5.0.23"
let cocoaVersionStr = "5.3.5"

let buildFromSource = ProcessInfo.processInfo.environment["REALM_BUILD_FROM_SOURCE"] != nil
let baseUrl = ProcessInfo.processInfo.environment["REALM_BASE_URL"] ?? "https://static.realm.io/downloads"

let coreVersionPieces = coreVersionStr.split(separator: ".")
let coreVersionExtra = coreVersionPieces[2].split(separator: "-")
var cxxSettings: [CXXSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .headerSearchPath("Realm/ObjectStore/src"),
    .define("REALM_SPM", to: "1"),
    .define("REALM_COCOA_VERSION", to: "@\"\(cocoaVersionStr)\""),
    .define("REALM_VERSION", to: "\"\(coreVersionStr)\""),

    .define("REALM_NO_CONFIG"),
    .define("REALM_INSTALL_LIBEXECDIR", to: ""),
    .define("REALM_ENABLE_ASSERTIONS", to: "1"),
    .define("REALM_ENABLE_ENCRYPTION", to: "1"),

    .define("REALM_VERSION_MAJOR", to: String(coreVersionPieces[0])),
    .define("REALM_VERSION_MINOR", to: String(coreVersionPieces[1])),
    .define("REALM_VERSION_PATCH", to: String(coreVersionExtra[0])),
    .define("REALM_VERSION_EXTRA", to: "\"\(coreVersionExtra.count > 1 ? String(coreVersionExtra[1]) : "")\""),
    .define("REALM_VERSION_STRING", to: "\"\(coreVersionStr)\"")
]
if !buildFromSource {
    cxxSettings.append(.define("REALM_ENABLE_SYNC", to: "1"))
}

var sourceFiles: [String] = [
    "Realm/ObjectStore/src/binding_callback_thread_observer.cpp",
    "Realm/ObjectStore/src/collection_notifications.cpp",
    "Realm/ObjectStore/src/impl/apple/external_commit_helper.cpp",
    "Realm/ObjectStore/src/impl/apple/keychain_helper.cpp",
    "Realm/ObjectStore/src/impl/collection_change_builder.cpp",
    "Realm/ObjectStore/src/impl/collection_notifier.cpp",
    "Realm/ObjectStore/src/impl/list_notifier.cpp",
    "Realm/ObjectStore/src/impl/object_notifier.cpp",
    "Realm/ObjectStore/src/impl/primitive_list_notifier.cpp",
    "Realm/ObjectStore/src/impl/realm_coordinator.cpp",
    "Realm/ObjectStore/src/impl/results_notifier.cpp",
    "Realm/ObjectStore/src/impl/transact_log_handler.cpp",
    "Realm/ObjectStore/src/impl/weak_realm_notifier.cpp",
    "Realm/ObjectStore/src/index_set.cpp",
    "Realm/ObjectStore/src/list.cpp",
    "Realm/ObjectStore/src/object.cpp",
    "Realm/ObjectStore/src/object_changeset.cpp",
    "Realm/ObjectStore/src/object_schema.cpp",
    "Realm/ObjectStore/src/object_store.cpp",
    "Realm/ObjectStore/src/results.cpp",
    "Realm/ObjectStore/src/schema.cpp",
    "Realm/ObjectStore/src/shared_realm.cpp",
    "Realm/ObjectStore/src/thread_safe_reference.cpp",
    "Realm/ObjectStore/src/util/scheduler.cpp",
    "Realm/ObjectStore/src/util/uuid.cpp",

    "Realm/RLMAccessor.mm",
    "Realm/RLMAnalytics.mm",
    "Realm/RLMArray.mm",
    "Realm/RLMClassInfo.mm",
    "Realm/RLMCollection.mm",
    "Realm/RLMConstants.m",
    "Realm/RLMListBase.mm",
    "Realm/RLMManagedArray.mm",
    "Realm/RLMMigration.mm",
    "Realm/RLMObject.mm",
    "Realm/RLMObjectBase.mm",
    "Realm/RLMObjectSchema.mm",
    "Realm/RLMObjectStore.mm",
    "Realm/RLMObservation.mm",
    "Realm/RLMOptionalBase.mm",
    "Realm/RLMPredicateUtil.mm",
    "Realm/RLMProperty.mm",
    "Realm/RLMQueryUtil.mm",
    "Realm/RLMRealm.mm",
    "Realm/RLMRealmConfiguration.mm",
    "Realm/RLMRealmUtil.mm",
    "Realm/RLMResults.mm",
    "Realm/RLMSchema.mm",
    "Realm/RLMSwiftSupport.m",
    "Realm/RLMThreadSafeReference.mm",
    "Realm/RLMUpdateChecker.mm",
    "Realm/RLMUtil.mm"
]

var excludes: [String] = [
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
    "Realm/ObjectStore/CMake",
    "Realm/ObjectStore/CMakeLists.txt",
    "Realm/ObjectStore/Dockerfile",
    "Realm/ObjectStore/Jenkinsfile",
    "Realm/ObjectStore/LICENSE",
    "Realm/ObjectStore/README.md",
    "Realm/ObjectStore/android.Dockerfile",
    "Realm/ObjectStore/dependencies.list",
    "Realm/ObjectStore/external",
    "Realm/ObjectStore/src/CMakeLists.txt",
    "Realm/ObjectStore/src/audit.hpp",
    "Realm/ObjectStore/src/binding_callback_thread_observer.hpp",
    "Realm/ObjectStore/src/binding_context.hpp",
    "Realm/ObjectStore/src/collection_notifications.hpp",
    "Realm/ObjectStore/src/feature_checks.hpp",
    "Realm/ObjectStore/src/impl/apple/external_commit_helper.hpp",
    "Realm/ObjectStore/src/impl/apple/keychain_helper.hpp",
    "Realm/ObjectStore/src/impl/collection_change_builder.hpp",
    "Realm/ObjectStore/src/impl/collection_notifier.hpp",
    "Realm/ObjectStore/src/impl/epoll",
    "Realm/ObjectStore/src/impl/epoll/external_commit_helper.hpp",
    "Realm/ObjectStore/src/impl/external_commit_helper.hpp",
    "Realm/ObjectStore/src/impl/generic",
    "Realm/ObjectStore/src/impl/generic/external_commit_helper.hpp",
    "Realm/ObjectStore/src/impl/list_notifier.hpp",
    "Realm/ObjectStore/src/impl/notification_wrapper.hpp",
    "Realm/ObjectStore/src/impl/object_accessor_impl.hpp",
    "Realm/ObjectStore/src/impl/object_notifier.hpp",
    "Realm/ObjectStore/src/impl/realm_coordinator.hpp",
    "Realm/ObjectStore/src/impl/results_notifier.hpp",
    "Realm/ObjectStore/src/impl/transact_log_handler.hpp",
    "Realm/ObjectStore/src/impl/weak_realm_notifier.hpp",
    "Realm/ObjectStore/src/impl/windows",
    "Realm/ObjectStore/src/impl/windows/external_commit_helper.hpp",
    "Realm/ObjectStore/src/index_set.hpp",
    "Realm/ObjectStore/src/keypath_helpers.hpp",
    "Realm/ObjectStore/src/list.hpp",
    "Realm/ObjectStore/src/object.hpp",
    "Realm/ObjectStore/src/object_accessor.hpp",
    "Realm/ObjectStore/src/object_changeset.hpp",
    "Realm/ObjectStore/src/object_schema.hpp",
    "Realm/ObjectStore/src/object_store.hpp",
    "Realm/ObjectStore/src/placeholder.cpp",
    "Realm/ObjectStore/src/property.hpp",
    "Realm/ObjectStore/src/results.hpp",
    "Realm/ObjectStore/src/schema.hpp",
    "Realm/ObjectStore/src/server",
    "Realm/ObjectStore/src/server/adapter.hpp",
    "Realm/ObjectStore/src/server/admin_realm.hpp",
    "Realm/ObjectStore/src/server/global_notifier.hpp",
    "Realm/ObjectStore/src/shared_realm.hpp",
    "Realm/ObjectStore/src/sync/async_open_task.hpp",
    "Realm/ObjectStore/src/sync/impl/apple/network_reachability_observer.hpp",
    "Realm/ObjectStore/src/sync/impl/apple/system_configuration.hpp",
    "Realm/ObjectStore/src/sync/impl/network_reachability.hpp",
    "Realm/ObjectStore/src/sync/impl/sync_client.hpp",
    "Realm/ObjectStore/src/sync/impl/sync_file.hpp",
    "Realm/ObjectStore/src/sync/impl/sync_metadata.hpp",
    "Realm/ObjectStore/src/sync/impl/work_queue.hpp",
    "Realm/ObjectStore/src/sync/partial_sync.hpp",
    "Realm/ObjectStore/src/sync/subscription_state.hpp",
    "Realm/ObjectStore/src/sync/sync_config.hpp",
    "Realm/ObjectStore/src/sync/sync_manager.hpp",
    "Realm/ObjectStore/src/sync/sync_session.hpp",
    "Realm/ObjectStore/src/sync/sync_user.hpp",
    "Realm/ObjectStore/src/thread_safe_reference.hpp",
    "Realm/ObjectStore/src/util/aligned_union.hpp",
    "Realm/ObjectStore/src/util/android/scheduler.hpp",
    "Realm/ObjectStore/src/util/apple/scheduler.hpp",
    "Realm/ObjectStore/src/util/atomic_shared_ptr.hpp",
    "Realm/ObjectStore/src/util/checked_mutex.hpp",
    "Realm/ObjectStore/src/util/copyable_atomic.hpp",
    "Realm/ObjectStore/src/util/event_loop_dispatcher.hpp",
    "Realm/ObjectStore/src/util/generic/scheduler.hpp",
    "Realm/ObjectStore/src/util/scheduler.hpp",
    "Realm/ObjectStore/src/util/tagged_bool.hpp",
    "Realm/ObjectStore/src/util/uuid.hpp",
    "Realm/ObjectStore/src/util/uv/scheduler.hpp",
    "Realm/ObjectStore/tests",
    "Realm/ObjectStore/workflow",
    "Realm/RLMAccessor.hpp",
    "Realm/RLMAnalytics.hpp",
    "Realm/RLMArray_Private.hpp",
    "Realm/RLMClassInfo.hpp",
    "Realm/RLMCollection_Private.hpp",
    "Realm/RLMObjectSchema_Private.hpp",
    "Realm/RLMObject_Private.hpp",
    "Realm/RLMObservation.hpp",
    "Realm/RLMPlatform.h.in",
    "Realm/RLMPredicateUtil.hpp",
    "Realm/RLMProperty_Private.hpp",
    "Realm/RLMQueryUtil.hpp",
    "Realm/RLMRealmConfiguration_Private.hpp",
    "Realm/RLMRealmUtil.hpp",
    "Realm/RLMRealm_Private.hpp",
    "Realm/RLMResults_Private.hpp",
    "Realm/RLMSchema_Private.hpp",
    "Realm/RLMSyncConfiguration_Private.hpp",
    "Realm/RLMSyncSessionRefreshHandle.hpp",
    "Realm/RLMSyncSession_Private.hpp",
    "Realm/RLMSyncUser_Private.hpp",
    "Realm/RLMSyncUtil_Private.hpp",
    "Realm/RLMThreadSafeReference_Private.hpp",
    "Realm/RLMUpdateChecker.hpp",
    "Realm/RLMUtil.hpp",
    "Realm/Realm-Info.plist",
    "Realm/Swift/RLMSupport.swift",
    "Realm/TestUtils",
    "Realm/Tests",
    "Realm/Tests/RealmTests-Info.plist",
    "Realm/Tests/fileformat-pre-null.realm",
    "Realm/Tests/tests.py",
    "RealmSwift",
    "RealmSwift.podspec",
    "RealmSwift/RealmSwift-Info.plist",
    "RealmSwift/Tests/RealmSwiftTests-Info.plist",
    "SUPPORT.md",
    "build.sh",
    "contrib",
    "core",
    "dependencies.list",
    "docs",
    "examples",
    "logo.png",
    "plugin",
    "scripts",
    "tools"
]

let syncSourceFiles = [
    "Realm/ObjectStore/src/sync/async_open_task.cpp",
    "Realm/ObjectStore/src/sync/impl/apple/network_reachability_observer.cpp",
    "Realm/ObjectStore/src/sync/impl/apple/system_configuration.cpp",
    "Realm/ObjectStore/src/sync/impl/sync_file.cpp",
    "Realm/ObjectStore/src/sync/impl/sync_metadata.cpp",
    "Realm/ObjectStore/src/sync/impl/work_queue.cpp",
    "Realm/ObjectStore/src/sync/partial_sync.cpp",
    "Realm/ObjectStore/src/sync/sync_config.cpp",
    "Realm/ObjectStore/src/sync/sync_manager.cpp",
    "Realm/ObjectStore/src/sync/sync_session.cpp",
    "Realm/ObjectStore/src/sync/sync_user.cpp",

    "Realm/NSError+RLMSync.m",
    "Realm/RLMJSONModels.m",
    "Realm/RLMNetworkClient.mm",
    "Realm/RLMRealm+Sync.mm",
    "Realm/RLMRealmConfiguration+Sync.mm",
    "Realm/RLMSyncConfiguration.mm",
    "Realm/RLMSyncCredentials.m",
    "Realm/RLMSyncManager.mm",
    "Realm/RLMSyncPermission.mm",
    "Realm/RLMSyncSession.mm",
    "Realm/RLMSyncSessionRefreshHandle.mm",
    "Realm/RLMSyncSubscription.mm",
    "Realm/RLMSyncUser.mm",
    "Realm/RLMSyncUtil.mm"
]

var swiftExcludes: [String] = ["Tests", "RealmSwift-Info.plist"]

if buildFromSource {
    excludes += syncSourceFiles
    swiftExcludes += [
        "Sync.swift",
        "ObjectiveCSupport+Sync.swift"
    ]
} else {
    sourceFiles += syncSourceFiles
    swiftExcludes += ["Nonsync.swift"]
}

let platforms: [SupportedPlatform] = [
    .macOS(.v10_10),
    .iOS(.v11),
    .tvOS(.v9),
    .watchOS(.v2)
]
let products: [Product] = [
    .library(name: "Realm", targets: ["Realm"]),
    .library(name: "RealmSwift", targets: ["Realm", "RealmSwift"])
]
var dependencies: [Package.Dependency] = []
if buildFromSource {
    dependencies += [.package(name: "RealmCore", url: "https://github.com/realm/realm-core", .exact(Version(coreVersionStr)!))]
}
var targets: [Target] = [
    .systemLibrary(name: "zlib", path: "Realm/zlib", pkgConfig: "zlib"),
    .target(
        name: "Realm",
        dependencies: ["RealmCore", "zlib"],
        path: ".",
        exclude: excludes,
        sources: sourceFiles,
        publicHeadersPath: "include",
        cxxSettings: cxxSettings
    ),
    .target(
        name: "RealmSwift",
        dependencies: ["Realm"],
        path: "RealmSwift",
        exclude: swiftExcludes
    ),
    .target(
        name: "RealmTestSupport",
        dependencies: ["Realm"],
        path: "Realm/TestUtils",
        cxxSettings: cxxSettings + [
            // Command-line `swift build` resolves header search paths
            // relative to the package root, while Xcode resolves them
            // relative to the target root, so we need both.
            .headerSearchPath("Realm"),
            .headerSearchPath("..")
        ]
    ),
    .testTarget(
        name: "RealmTests",
        dependencies: ["Realm", "RealmTestSupport"],
        path: "Realm/Tests",
        exclude: [
            "PrimitiveArrayPropertyTests.tpl.m",
            "RealmTests-Info.plist",
            "Swift",
            "TestHost",
            "fileformat-pre-null.realm",
            "tests.py"
        ],
        cxxSettings: cxxSettings + [
            .headerSearchPath("Realm"),
            .headerSearchPath(".."),
            .headerSearchPath("../ObjectStore/src")
        ]
    ),
    .testTarget(
        name: "RealmObjcSwiftTests",
        dependencies: ["Realm", "RealmTestSupport"],
        path: "Realm/Tests/Swift"
    ),
    .testTarget(
        name: "RealmSwiftTests",
        dependencies: ["RealmSwift", "RealmTestSupport"],
        path: "RealmSwift/Tests",
        exclude: ["TestUtils.mm", "RealmSwiftTests-Info.plist"]
    )
]

if !buildFromSource {
    targets += [.binaryTarget(
        name: "RealmCore",
        url: "\(baseUrl)/sync/realm-sync-\(syncVersionStr).xcframework.zip",
        checksum: "5133eba05103cfb9277536986f6f0b67161a5ffdef86a679ac798924385aa30c"
    )]
}

let package = Package(
    name: "Realm",
    platforms: platforms,
    products: products,
    dependencies: dependencies,
    targets: targets,
    cxxLanguageStandard: .cxx1z
)
