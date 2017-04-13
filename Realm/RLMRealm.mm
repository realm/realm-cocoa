////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMRealm_Private.hpp"

#import "RLMAnalytics.hpp"
#import "RLMArray_Private.hpp"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMMigration_Private.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMObjectStore.h"
#import "RLMObject_Private.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealmUtil.hpp"
#import "RLMSchema_Private.hpp"
#import "RLMSyncManager_Private.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUpdateChecker.hpp"
#import "RLMUtil.hpp"

#include "impl/realm_coordinator.hpp"
#include "object_store.hpp"
#include "schema.hpp"
#include "shared_realm.hpp"

#include <realm/disable_sync_to_disk.hpp>
#include <realm/util/scope_exit.hpp>
#include <realm/version.hpp>

#if REALM_IOS
#import <UIKit/UIKit.h>
#endif

using namespace realm;
using util::File;

@interface RLMRealmNotificationToken : RLMNotificationToken
@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, copy) RLMNotificationBlock block;
@end

@interface RLMRealm ()
@property (nonatomic, strong) NSHashTable<RLMRealmNotificationToken *> *notificationHandlers;
- (void)sendNotifications:(RLMNotification)notification;
@end

void RLMDisableSyncToDisk() {
    realm::disable_sync_to_disk();
}

@implementation RLMRealmNotificationToken
- (void)stop {
    [_realm verifyThread];
    [_realm.notificationHandlers removeObject:self];
    _realm = nil;
    _block = nil;
}

- (void)suppressNextNotification {
    // Temporarily replace the block with one which restores the old block
    // rather than producing a notification.

    // This briefly creates a retain cycle but it's fine because the block will
    // be synchronously called shortly after this method is called. Unlike with
    // collection notifications, this does not have to go through the object
    // store or do fancy things to handle transaction coalescing because it's
    // called synchronously by the obj-c code and not by the object store.
    auto notificationBlock = _block;
    _block = ^(RLMNotification, RLMRealm *) {
        _block = notificationBlock;
    };
}

- (void)dealloc {
    if (_realm || _block) {
        NSLog(@"RLMNotificationToken released without unregistering a notification. You must hold "
              @"on to the RLMNotificationToken returned from addNotificationBlock and call "
              @"-[RLMNotificationToken stop] when you no longer wish to receive RLMRealm notifications.");
    }
}
@end

static bool shouldForciblyDisableEncryption() {
    static bool disableEncryption = getenv("REALM_DISABLE_ENCRYPTION");
    return disableEncryption;
}

NSData *RLMRealmValidatedEncryptionKey(NSData *key) {
    if (shouldForciblyDisableEncryption()) {
        return nil;
    }

    if (key) {
        if (key.length != 64) {
            @throw RLMException(@"Encryption key must be exactly 64 bytes long");
        }
#if TARGET_OS_WATCH
        @throw RLMException(@"Cannot open an encrypted Realm on watchOS.");
#endif
    }

    return key;
}

@implementation RLMRealm {
    NSHashTable<RLMFastEnumerator *> *_collectionEnumerators;
    bool _sendingNotifications;

    // Needs to be atomic because the timeout callback is called on the main
    // thread and not the RLMRealm's thread, so we could try to end the task
    // from multiple threads at once
    std::atomic<NSUInteger> _backgroundTaskIdentifier;
    bool _addedBackgroundNotification;
}

+ (BOOL)isCoreDebug {
    return realm::Version::has_feature(realm::feature_Debug);
}

id g_sharedApplication;
+ (void)initialize {
    static bool initialized;
    if (initialized) {
        return;
    }
    initialized = true;

#if REALM_IOS
    // Using NSClassFromString rather than directly referencing UIApplication
    // avoids the need to link UIKit.framework, and we can't actually write
    // `[UIApplication sharedApplication]` due to compiling as extension-safe
    g_sharedApplication = [NSClassFromString(@"UIApplication") sharedApplication];

    // Background tasks aren't supported if we're running inside an extension
    if (![g_sharedApplication respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
        g_sharedApplication = nil;
    }
#endif

    RLMCheckForUpdates();
    RLMSendAnalytics();
}

#if REALM_IOS
// On iOS we want to wrap our write transactions in background tasks so that the
// OS doesn't suspend the app while we hold the write lock, as that will block
// any other apps in the same app group from using the Realm. Doing this
// unconditionally is extremely slow, so instead we only do it if we're already
// in the background, and just register for the background state transition
// notification otherwise
- (void)beginBackgroundTask {
    if (!g_sharedApplication) {
        return;
    }

    if ([g_sharedApplication applicationState] == UIApplicationStateBackground) {
        [self applicationDidEnterBackground:nil];
        return;
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:@"UIApplicationDidEnterBackground"
                                             object:nil];
    _addedBackgroundNotification = true;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (notification && !self.inWriteTransaction) {
        // No need for a task if we got the notification when not actually in
        // a write transaction
        return;
    }

    // The block needs to not retain `self` or we'll leak any Realms which the
    // user fails to commit/cancel
    __weak RLMRealm *weakSelf = self;
    _backgroundTaskIdentifier = [g_sharedApplication beginBackgroundTaskWithExpirationHandler:^{
        // If we time out just end the task and let the OS suspend us rather
        // than terminating
        if (auto self = weakSelf) {
            [self endBackgroundTask];
        }
    }];
}

- (void)endBackgroundTask {
    if (auto identifier = _backgroundTaskIdentifier.exchange(0)) {
        [g_sharedApplication endBackgroundTask:identifier];
    }
}
#else
- (void)beginBackgroundTask {
}

- (void)endBackgroundTask {
}
#endif // REALM_IOS

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

- (BOOL)isEmpty {
    return realm::ObjectStore::is_empty(self.group);
}

- (void)verifyThread {
    try {
        _realm->verify_thread();
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

- (BOOL)inWriteTransaction {
    return _realm->is_in_transaction();
}

- (realm::Group &)group {
    return _realm->read_group();
}

- (BOOL)autorefresh {
    return _realm->auto_refresh();
}

- (void)setAutorefresh:(BOOL)autorefresh {
    _realm->set_auto_refresh(autorefresh);
}

+ (instancetype)defaultRealm {
    return [RLMRealm realmWithConfiguration:[RLMRealmConfiguration rawDefaultConfiguration] error:nil];
}

+ (instancetype)realmWithURL:(NSURL *)fileURL {
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.fileURL = fileURL;
    return [RLMRealm realmWithConfiguration:configuration error:nil];
}
// ARC tries to eliminate calls to autorelease when the value is then immediately
// returned, but this results in significantly different semantics between debug
// and release builds for RLMRealm, so force it to always autorelease.
static id RLMAutorelease(__unsafe_unretained id value) {
    // +1 __bridge_retained, -1 CFAutorelease
    return value ? (__bridge id)CFAutorelease((__bridge_retained CFTypeRef)value) : nil;
}

+ (instancetype)realmWithSharedRealm:(SharedRealm)sharedRealm schema:(RLMSchema *)schema {
    RLMRealm *realm = [[RLMRealm alloc] initPrivate];
    realm->_realm = sharedRealm;
    realm->_dynamic = YES;
    realm->_schema = schema;
    realm->_info = RLMSchemaInfo(realm);
    return RLMAutorelease(realm);
}

REALM_NOINLINE void RLMRealmTranslateException(NSError **error) {
    try {
        throw;
    }
    catch (RealmFileException const& ex) {
        switch (ex.kind()) {
            case RealmFileException::Kind::PermissionDenied:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFilePermissionDenied, ex), error);
                break;
            case RealmFileException::Kind::IncompatibleLockFile: {
                NSString *err = @"Realm file is currently open in another process "
                                 "which cannot share access with this process. All "
                                 "processes sharing a single file must be the same "
                                 "architecture. For sharing files between the Realm "
                                 "Browser and an iOS simulator, this means that you "
                                 "must use a 64-bit simulator.";
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorIncompatibleLockFile,
                                                File::PermissionDenied(err.UTF8String, ex.path())), error);
                break;
            }
            case RealmFileException::Kind::NotFound:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFileNotFound, ex), error);
                break;
            case RealmFileException::Kind::Exists:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFileExists, ex), error);
                break;
            case RealmFileException::Kind::BadHistoryError: {
                NSString *err = @"Realm file's history format is incompatible with the "
                                 "settings in the configuration object being used to open "
                                 "the Realm. Note that Realms configured for sync cannot be "
                                 "opened as non-synced Realms, and vice versa. Otherwise, the "
                                 "file may be corrupt.";
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFileAccess,
                                                File::AccessError(err.UTF8String, ex.path())), error);
                break;
            }
            case RealmFileException::Kind::AccessError:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFileAccess, ex), error);
                break;
            case RealmFileException::Kind::FormatUpgradeRequired:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFileFormatUpgradeRequired, ex), error);
                break;
            default:
                RLMSetErrorOrThrow(RLMMakeError(RLMErrorFail, ex), error);
                break;
        }
    }
    catch (AddressSpaceExhausted const &ex) {
        RLMSetErrorOrThrow(RLMMakeError(RLMErrorAddressSpaceExhausted, ex), error);
    }
    catch (SchemaMismatchException const& ex) {
        RLMSetErrorOrThrow(RLMMakeError(RLMErrorSchemaMismatch, ex), error);
    }
    catch (std::system_error const& ex) {
        RLMSetErrorOrThrow(RLMMakeError(ex), error);
    }
    catch (const std::exception &exp) {
        RLMSetErrorOrThrow(RLMMakeError(RLMErrorFail, exp), error);
    }
}

+ (instancetype)realmWithConfiguration:(RLMRealmConfiguration *)configuration error:(NSError **)error {
    bool dynamic = configuration.dynamic;
    bool cache = configuration.cache;
    bool readOnly = configuration.readOnly;

    {
        Realm::Config& config = configuration.config;

        // try to reuse existing realm first
        if (cache || dynamic) {
            if (RLMRealm *realm = RLMGetThreadLocalCachedRealmForPath(config.path)) {
                auto const& old_config = realm->_realm->config();
                if (old_config.read_only() != config.read_only()) {
                    @throw RLMException(@"Realm at path '%s' already opened with different read permissions", config.path.c_str());
                }
                if (old_config.in_memory != config.in_memory) {
                    @throw RLMException(@"Realm at path '%s' already opened with different inMemory settings", config.path.c_str());
                }
                if (realm->_dynamic != dynamic) {
                    @throw RLMException(@"Realm at path '%s' already opened with different dynamic settings", config.path.c_str());
                }
                if (old_config.encryption_key != config.encryption_key) {
                    @throw RLMException(@"Realm at path '%s' already opened with different encryption key", config.path.c_str());
                }
                return RLMAutorelease(realm);
            }
        }
    }

    configuration = [configuration copy];
    Realm::Config& config = configuration.config;

    RLMRealm *realm = [[RLMRealm alloc] initPrivate];
    realm->_dynamic = dynamic;

    // protects the realm cache and accessors cache
    static std::mutex& initLock = *new std::mutex();
    std::lock_guard<std::mutex> lock(initLock);

    try {
        realm->_realm = Realm::get_shared_realm(config);
    }
    catch (...) {
        RLMRealmTranslateException(error);
        return nil;
    }

    // if we have a cached realm on another thread we can skip a few steps and
    // just grab its schema
    @autoreleasepool {
        // ensure that cachedRealm doesn't end up in this thread's autorelease pool
        if (auto cachedRealm = RLMGetAnyCachedRealmForPath(config.path)) {
            realm->_realm->set_schema_subset(cachedRealm->_realm->schema());
            realm->_schema = cachedRealm.schema;
            realm->_info = cachedRealm->_info.clone(cachedRealm->_realm->schema(), realm);
        }
    }

    if (realm->_schema) { }
    else if (dynamic) {
        realm->_schema = [RLMSchema dynamicSchemaFromObjectStoreSchema:realm->_realm->schema()];
        realm->_info = RLMSchemaInfo(realm);
    }
    else {
        // set/align schema or perform migration if needed
        RLMSchema *schema = configuration.customSchema ?: RLMSchema.sharedSchema;

        Realm::MigrationFunction migrationFunction;
        auto migrationBlock = configuration.migrationBlock;
        if (migrationBlock && configuration.schemaVersion > 0) {
            migrationFunction = [=](SharedRealm old_realm, SharedRealm realm, Schema& mutableSchema) {
                RLMSchema *oldSchema = [RLMSchema dynamicSchemaFromObjectStoreSchema:old_realm->schema()];
                RLMRealm *oldRealm = [RLMRealm realmWithSharedRealm:old_realm schema:oldSchema];

                // The destination RLMRealm can't just use the schema from the
                // SharedRealm because it doesn't have information about whether or
                // not a class was defined in Swift, which effects how new objects
                // are created
                RLMRealm *newRealm = [RLMRealm realmWithSharedRealm:realm schema:schema.copy];

                [[[RLMMigration alloc] initWithRealm:newRealm oldRealm:oldRealm schema:mutableSchema] execute:migrationBlock];

                oldRealm->_realm = nullptr;
                newRealm->_realm = nullptr;
            };
        }

        try {
            realm->_realm->update_schema(schema.objectStoreCopy, config.schema_version,
                                         std::move(migrationFunction));
        }
        catch (...) {
            RLMRealmTranslateException(error);
            return nil;
        }

        realm->_schema = schema;
        realm->_info = RLMSchemaInfo(realm);
        RLMRealmCreateAccessors(realm.schema);

        if (!readOnly) {
            // initializing the schema started a read transaction, so end it
            [realm invalidate];
        }
    }

    if (cache) {
        RLMCacheRealm(config.path, realm);
    }

    if (!readOnly) {
        realm->_realm->m_binding_context = RLMCreateBindingContext(realm);
        realm->_realm->m_binding_context->realm = realm->_realm;
    }

    return RLMAutorelease(realm);
}

+ (void)resetRealmState {
    RLMClearRealmCache();
    realm::_impl::RealmCoordinator::clear_cache();
    [RLMRealmConfiguration resetRealmConfigurationState];
}

- (void)verifyNotificationsAreSupported {
    [self verifyThread];
    if (_realm->config().read_only()) {
        @throw RLMException(@"Read-only Realms do not change and do not have change notifications");
    }
    if (!_realm->can_deliver_notifications()) {
        @throw RLMException(@"Can only add notification blocks from within runloops.");
    }
}

- (RLMNotificationToken *)addNotificationBlock:(RLMNotificationBlock)block {
    if (!block) {
        @throw RLMException(@"The notification block should not be nil");
    }
    [self verifyNotificationsAreSupported];

    _realm->read_group();

    if (!_notificationHandlers) {
        _notificationHandlers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }

    RLMRealmNotificationToken *token = [[RLMRealmNotificationToken alloc] init];
    token.realm = self;
    token.block = block;
    [_notificationHandlers addObject:token];
    return token;
}

- (void)sendNotifications:(RLMNotification)notification {
    NSAssert(!_realm->config().read_only(), @"Read-only realms do not have notifications");
    if (_sendingNotifications) {
        return;
    }
    NSUInteger count = _notificationHandlers.count;
    if (count == 0) {
        return;
    }

    _sendingNotifications = true;
    auto cleanup = realm::util::make_scope_exit([&]() noexcept {
        _sendingNotifications = false;
    });

    // call this realm's notification blocks
    if (count == 1) {
        if (auto block = [_notificationHandlers.anyObject block]) {
            block(notification, self);
        }
    }
    else {
        for (RLMRealmNotificationToken *token in _notificationHandlers.allObjects) {
            if (auto block = token.block) {
                block(notification, self);
            }
        }
    }
}

- (RLMRealmConfiguration *)configuration {
    RLMRealmConfiguration *configuration = [[RLMRealmConfiguration alloc] init];
    configuration.config = _realm->config();
    configuration.dynamic = _dynamic;
    configuration.customSchema = _schema;
    return configuration;
}

- (void)beginWriteTransaction {
    [self beginBackgroundTask];
    try {
        _realm->begin_transaction();
    }
    catch (std::exception &ex) {
        [self endBackgroundTask];
        @throw RLMException(ex);
    }
}

- (void)commitWriteTransaction {
    [self commitWriteTransaction:nil];
}

- (BOOL)commitWriteTransaction:(NSError **)outError {
    try {
        _realm->commit_transaction();
        [self endBackgroundTask];
        return YES;
    }
    catch (...) {
        [self endBackgroundTask];
        RLMRealmTranslateException(outError);
        return NO;
    }
}

- (BOOL)commitWriteTransactionWithoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
                                         error:(NSError **)error {
    for (RLMNotificationToken *token in tokens) {
        if (token.realm != self) {
            @throw RLMException(@"Incorrect Realm: only notifications for the Realm being modified can be skipped.");
        }
        [token suppressNextNotification];
    }

    try {
        _realm->commit_transaction();
        [self endBackgroundTask];
        return YES;
    }
    catch (...) {
        [self endBackgroundTask];
        RLMRealmTranslateException(error);
        return NO;
    }
}

- (void)transactionWithBlock:(void(^)(void))block {
    [self transactionWithBlock:block error:nil];
}

- (BOOL)transactionWithBlock:(void(^)(void))block error:(NSError **)outError {
    [self beginWriteTransaction];
    block();
    if (_realm->is_in_transaction()) {
        return [self commitWriteTransaction:outError];
    }
    return YES;
}

- (void)cancelWriteTransaction {
    try {
        _realm->cancel_transaction();
        [self endBackgroundTask];
    }
    catch (std::exception &ex) {
        @throw RLMException(ex);
    }
}

- (void)invalidate {
    if (_realm->is_in_transaction()) {
        NSLog(@"WARNING: An RLMRealm instance was invalidated during a write "
              "transaction and all pending changes have been rolled back.");
    }

    [self detachAllEnumerators];

    for (auto& objectInfo : _info) {
        for (RLMObservationInfo *info : objectInfo.second.observedObjects) {
            info->willChange(RLMInvalidatedKey);
        }
    }

    _realm->invalidate();
    [self endBackgroundTask];

    for (auto& objectInfo : _info) {
        for (RLMObservationInfo *info : objectInfo.second.observedObjects) {
            info->didChange(RLMInvalidatedKey);
        }
        objectInfo.second.releaseTable();
    }
}

- (nullable id)resolveThreadSafeReference:(RLMThreadSafeReference *)reference {
    return [reference resolveReferenceInRealm:self];
}

/**
 Replaces all string columns in this Realm with a string enumeration column and compacts the
 database file.

 Cannot be called from a write transaction.

 Compaction will not occur if other `RLMRealm` instances exist.

 While compaction is in progress, attempts by other threads or processes to open the database will
 wait.

 Be warned that resource requirements for compaction is proportional to the amount of live data in
 the database.

 Compaction works by writing the database contents to a temporary database file and then replacing
 the database with the temporary one. The name of the temporary file is formed by appending
 `.tmp_compaction_space` to the name of the database.

 @return YES if the compaction succeeded.
 */
- (BOOL)compact {
    // compact() automatically ends the read transaction, but we need to clean
    // up cached state and send invalidated notifications when that happens, so
    // explicitly end it first unless we're in a write transaction (in which
    // case compact() will throw an exception)
    if (!_realm->is_in_transaction()) {
        [self invalidate];
    }

    try {
        return _realm->compact();
    }
    catch (std::exception const& ex) {
        @throw RLMException(ex);
    }
}

- (void)dealloc {
    if (_realm && _realm->is_in_transaction()) {
        [self cancelWriteTransaction];
        NSLog(@"WARNING: An RLMRealm instance was deallocated during a write transaction and all "
              "pending changes have been rolled back. Make sure to retain a reference to the "
              "RLMRealm for the duration of the write transaction.");
    }
    if (_addedBackgroundNotification) {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:@"UIApplicationDidEnterBackground"
                                                    object:nil];
    }
}

- (BOOL)refresh {
    return _realm->refresh();
}

- (void)addObject:(__unsafe_unretained RLMObject *const)object {
    RLMAddObjectToRealm(object, self, false);
}

- (void)addObjects:(id<NSFastEnumeration>)array {
    for (RLMObject *obj in array) {
        if (![obj isKindOfClass:[RLMObject class]]) {
            @throw RLMException(@"Cannot insert objects of type %@ with addObjects:. Only RLMObjects are supported.",
                                NSStringFromClass(obj.class));
        }
        [self addObject:obj];
    }
}

- (void)addOrUpdateObject:(RLMObject *)object {
    // verify primary key
    if (!object.objectSchema.primaryKeyProperty) {
        @throw RLMException(@"'%@' does not have a primary key and can not be updated", object.objectSchema.className);
    }

    RLMAddObjectToRealm(object, self, true);
}

- (void)addOrUpdateObjectsFromArray:(id)array {
    for (RLMObject *obj in array) {
        [self addOrUpdateObject:obj];
    }
}

- (void)deleteObject:(RLMObject *)object {
    RLMDeleteObjectFromRealm(object, self);
}

- (void)deleteObjects:(id)array {
    if ([array respondsToSelector:@selector(realm)] && [array respondsToSelector:@selector(deleteObjectsFromRealm)]) {
        if (self != (RLMRealm *)[array realm]) {
            @throw RLMException(@"Can only delete objects from the Realm they belong to.");
        }
        [array deleteObjectsFromRealm];
    }
    else if ([array conformsToProtocol:@protocol(NSFastEnumeration)]) {
        for (id obj in array) {
            if ([obj isKindOfClass:RLMObjectBase.class]) {
                RLMDeleteObjectFromRealm(obj, self);
            }
        }
    }
    else {
        @throw RLMException(@"Invalid array type - container must be an RLMArray, RLMArray, or NSArray of RLMObjects");
    }
}

- (void)deleteAllObjects {
    RLMDeleteAllObjectsFromRealm(self);
}

- (RLMResults *)allObjects:(NSString *)objectClassName {
    return RLMGetObjects(self, objectClassName, nil);
}

- (RLMResults *)objects:(NSString *)objectClassName where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objects:objectClassName where:predicateFormat args:args];
    va_end(args);
    return results;
}

- (RLMResults *)objects:(NSString *)objectClassName where:(NSString *)predicateFormat args:(va_list)args {
    return [self objects:objectClassName withPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (RLMResults *)objects:(NSString *)objectClassName withPredicate:(NSPredicate *)predicate {
    return RLMGetObjects(self, objectClassName, predicate);
}

- (RLMObject *)objectWithClassName:(NSString *)className forPrimaryKey:(id)primaryKey {
    return RLMGetObject(self, className, primaryKey);
}

+ (uint64_t)schemaVersionAtURL:(NSURL *)fileURL encryptionKey:(NSData *)key error:(NSError **)error {
    try {
        RLMRealmConfiguration *config = [[RLMRealmConfiguration alloc] init];
        config.fileURL = fileURL;
        config.encryptionKey = RLMRealmValidatedEncryptionKey(key);

        uint64_t version = Realm::get_schema_version(config.config);
        if (version == realm::ObjectStore::NotVersioned) {
            RLMSetErrorOrThrow([NSError errorWithDomain:RLMErrorDomain code:RLMErrorFail userInfo:@{NSLocalizedDescriptionKey:@"Cannot open an uninitialized realm in read-only mode"}], error);
        }
        return version;
    }
    catch (std::exception &exp) {
        RLMSetErrorOrThrow(RLMMakeError(RLMErrorFail, exp), error);
        return RLMNotVersioned;
    }
}

+ (nullable NSError *)migrateRealm:(RLMRealmConfiguration *)configuration {
    // Preserves backwards compatibility
    NSError *error;
    [self performMigrationForConfiguration:configuration error:&error];
    return error;
}

+ (BOOL)performMigrationForConfiguration:(RLMRealmConfiguration *)configuration error:(NSError **)error {
    if (RLMGetAnyCachedRealmForPath(configuration.config.path)) {
        @throw RLMException(@"Cannot migrate Realms that are already open.");
    }

    NSError *localError; // Prevents autorelease
    BOOL success;
    @autoreleasepool {
        success = [RLMRealm realmWithConfiguration:configuration error:&localError] != nil;
    }
    if (!success && error) {
        *error = localError; // Must set outside pool otherwise will free anyway
    }
    return success;
}

- (RLMObject *)createObject:(NSString *)className withValue:(id)value {
    return (RLMObject *)RLMCreateObjectInRealmWithValue(self, className, value, false);
}

- (BOOL)writeCopyToURL:(NSURL *)fileURL encryptionKey:(NSData *)key error:(NSError **)error {
    key = RLMRealmValidatedEncryptionKey(key);
    NSString *path = fileURL.path;

    try {
        _realm->write_copy(path.UTF8String, {static_cast<const char *>(key.bytes), key.length});
        return YES;
    }
    catch (...) {
        __autoreleasing NSError *dummyError;
        if (!error) {
            error = &dummyError;
        }
        RLMRealmTranslateException(error);
        return NO;
    }

    return NO;
}

- (void)registerEnumerator:(RLMFastEnumerator *)enumerator {
    if (!_collectionEnumerators) {
        _collectionEnumerators = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    [_collectionEnumerators addObject:enumerator];
}

- (void)unregisterEnumerator:(RLMFastEnumerator *)enumerator {
    [_collectionEnumerators removeObject:enumerator];
}

- (void)detachAllEnumerators {
    for (RLMFastEnumerator *enumerator in _collectionEnumerators) {
        [enumerator detach];
    }
    _collectionEnumerators = nil;
}

@end
