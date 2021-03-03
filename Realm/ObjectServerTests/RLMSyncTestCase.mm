////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "RLMSyncTestCase.h"

#import <XCTest/XCTest.h>
#import <Realm/Realm.h>

#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.hpp"
#import "RLMRealmConfiguration_Private.h"
#import "RLMSyncManager_Private.hpp"
#import "RLMSyncConfiguration_Private.h"
#import "RLMUtil.hpp"
#import "RLMApp_Private.hpp"

#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/sync/sync_session.hpp>
#import <realm/object-store/sync/sync_user.hpp>

#if TARGET_OS_OSX

@interface RealmServer : NSObject
+ (RealmServer *)shared;
+ (bool)haveServer;
- (NSString *)createAppAndReturnError:(NSError **)error;
@end

// Set this to 1 if you want the test ROS instance to log its debug messages to console.
#define LOG_ROS_OUTPUT 0

#if !TARGET_OS_MAC
#error These tests can only be run on a macOS host.
#endif

@interface RLMSyncManager ()
+ (void)_setCustomBundleID:(NSString *)customBundleID;
- (NSArray<RLMUser *> *)_allUsers;
@end

@interface RLMSyncTestCase ()
@property (nonatomic) NSTask *task;
@end

@interface RLMSyncSession ()
- (BOOL)waitForUploadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
- (BOOL)waitForDownloadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
@end

@interface RLMUser()
- (std::shared_ptr<realm::SyncUser>)_syncUser;
@end

#pragma mark Dog

@implementation Dog

+ (NSString *)primaryKey {
    return @"_id";
}

+ (NSArray *)requiredProperties {
    return @[@"name"];
}

+ (NSDictionary *)defaultPropertyValues {
    return @{@"_id": [RLMObjectId objectId]};
}

@end

#pragma mark Person

@implementation Person

+ (NSDictionary *)defaultPropertyValues {
    return @{@"_id": [RLMObjectId objectId]};
}

+ (NSString *)primaryKey {
    return @"_id";
}

+ (NSArray *)requiredProperties {
    return @[@"firstName", @"lastName", @"age"];
}

+ (instancetype)john {
    Person *john = [[Person alloc] init];
    john._id = [RLMObjectId objectId];
    john.age = 30;
    john.firstName = @"John";
    john.lastName = @"Lennon";
    return john;
}

+ (instancetype)paul {
    Person *paul = [[Person alloc] init];
    paul._id = [RLMObjectId objectId];
    paul.age = 30;
    paul.firstName = @"Paul";
    paul.lastName = @"McCartney";
    return paul;
}

+ (instancetype)ringo {
    Person *ringo = [[Person alloc] init];
    ringo._id = [RLMObjectId objectId];
    ringo.age = 30;
    ringo.firstName = @"Ringo";
    ringo.lastName = @"Starr";
    return ringo;
}

+ (instancetype)george {
    Person *george = [[Person alloc] init];
    george._id = [RLMObjectId objectId];
    george.age = 30;
    george.firstName = @"George";
    george.lastName = @"Harrison";
    return george;
}

@end

#pragma mark HugeSyncObject

@implementation HugeSyncObject

+ (NSDictionary *)defaultPropertyValues {
    return @{@"_id": [RLMObjectId objectId]};
}

+ (NSString *)primaryKey {
    return @"_id";
}

+ (instancetype)objectWithRealmId:(NSString *)realmId {
    const NSInteger fakeDataSize = 1000000;
    HugeSyncObject *object = [[self alloc] init];
    char fakeData[fakeDataSize];
    memset(fakeData, 16, sizeof(fakeData));
    object.dataProp = [NSData dataWithBytes:fakeData length:sizeof(fakeData)];
    object.realm_id = realmId;
    return object;
}

@end

#pragma mark AsyncOpenConnectionTimeoutTransport

@implementation AsyncOpenConnectionTimeoutTransport
- (void)sendRequestToServer:(RLMRequest *)request completion:(RLMNetworkTransportCompletionBlock)completionBlock {
    if ([request.url hasSuffix:@"location"]) {
        RLMResponse *r = [RLMResponse new];
        r.httpStatusCode = 200;
        r.body = @"{\"deployment_model\":\"GLOBAL\",\"location\":\"US-VA\",\"hostname\":\"http://localhost:5678\",\"ws_hostname\":\"ws://localhost:5678\"}";
        completionBlock(r);
    } else {
        [super sendRequestToServer:request completion:completionBlock];
    }
}
@end


static NSURL *syncDirectoryForChildProcess() {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = bundle.bundleIdentifier ?: bundle.executablePath.lastPathComponent;
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-child", bundleIdentifier]];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

#pragma mark RLMSyncTestCase

@implementation RLMSyncTestCase {
    NSString *_appId;
    RLMApp *_app;
}

#pragma mark - Helper methods

- (RLMUser *)anonymousUser {
    return [self logInUserForCredentials:[RLMCredentials anonymousCredentials]];
}

- (RLMCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister {
    if (shouldRegister) {
        XCTestExpectation *expectation = [self expectationWithDescription:@""];
        [self.app.emailPasswordAuth registerUserWithEmail:name password:@"password" completion:^(NSError *error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
        [self waitForExpectationsWithTimeout:4.0 handler:nil];
    }
    return [RLMCredentials credentialsWithEmail:name
                                       password:@"password"];
}

- (RLMAppConfiguration*)defaultAppConfiguration {
    return  [[RLMAppConfiguration alloc] initWithBaseURL:@"http://localhost:9090"
                                               transport:nil
                                            localAppName:nil
                                         localAppVersion:nil
                                 defaultRequestTimeoutMS:60];
}

- (void)addPersonsToRealm:(RLMRealm *)realm persons:(NSArray<Person *> *)persons {
    [realm beginWriteTransaction];
    [realm addObjects:persons];
    [realm commitWriteTransaction];
}

- (void)waitForDownloadsForUser:(RLMUser *)user
                         realms:(NSArray<RLMRealm *> *)realms
                partitionValues:(NSArray<NSString *> *)partitionValues
                 expectedCounts:(NSArray<NSNumber *> *)counts {
    NSAssert(realms.count == counts.count && realms.count == partitionValues.count,
             @"Test logic error: all array arguments must be the same size.");
    for (NSUInteger i = 0; i < realms.count; i++) {
        [self waitForDownloadsForUser:user partitionValue:partitionValues[i] expectation:nil error:nil];
        [realms[i] refresh];
        CHECK_COUNT([counts[i] integerValue], Person, realms[i]);
    }
}

- (RLMRealm *)openRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue user:(RLMUser *)user {
    return [self openRealmForPartitionValue:partitionValue
                                       user:user
                              encryptionKey:nil
                                 stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
}

- (RLMRealm *)openRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue
                                    user:(RLMUser *)user
                           encryptionKey:(nullable NSData *)encryptionKey
                              stopPolicy:(RLMSyncStopPolicy)stopPolicy {
    RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                             user:user
                                                    encryptionKey:encryptionKey
                                                       stopPolicy:stopPolicy];
    [self waitForDownloadsForRealm:realm];
    return realm;
}

- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration {
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nullptr];
    [self waitForDownloadsForRealm:realm];
    return realm;
}

- (RLMRealm *)asyncOpenRealmWithConfiguration:(RLMRealmConfiguration *)config {
    __block RLMRealm *r = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Should asynchronously open a Realm"];
    [RLMRealm asyncOpenWithConfiguration:config
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *err) {
        XCTAssertNil(err);
        XCTAssertNotNil(realm);
        r = realm;
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    // Ensure that the block does not retain the Realm, as it may not be dealloced
    // immediately and so would extend the lifetime of the Realm an inconsistent amount
    auto realm = r;
    r = nil;
    return realm;
}


- (NSError *)asyncOpenErrorWithConfiguration:(RLMRealmConfiguration *)config {
    __block NSError *error = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Should fail to asynchronously open a Realm"];
    [RLMRealm asyncOpenWithConfiguration:config
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *r, NSError *err){
        XCTAssertNotNil(err);
        XCTAssertNil(r);
        error = err;
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    return error;
}

- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue user:(RLMUser *)user {
    return [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                  user:user
                                         encryptionKey:nil
                                            stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
}

- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue
                                               user:(RLMUser *)user
                                      encryptionKey:(NSData *)encryptionKey
                                         stopPolicy:(RLMSyncStopPolicy)stopPolicy {
    auto c = [user configurationWithPartitionValue:partitionValue];
    c.encryptionKey = encryptionKey;
    c.objectClasses = @[Dog.self, Person.self, HugeSyncObject.self];
    RLMSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.stopPolicy = stopPolicy;
    c.syncConfiguration = syncConfig;
    return [RLMRealm realmWithConfiguration:c error:nil];
}

- (RLMUser *)logInUserForCredentials:(RLMCredentials *)credentials {
    return [self logInUserForCredentials:credentials app:self.app];
}

- (RLMUser *)logInUserForCredentials:(RLMCredentials *)credentials app:(RLMApp *)app {
    __block RLMUser* user;
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [app loginWithCredential:credentials completion:^(RLMUser *u, NSError *e) {
        XCTAssertNotNil(u);
        XCTAssertNil(e);
        user = u;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:4.0];
    XCTAssertTrue(user.state == RLMUserStateLoggedIn, @"User should have been valid, but wasn't");
    return user;
}

- (void)logOutUser:(RLMUser *)user {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [user logOutWithCompletion:^(NSError * error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:4.0];
    XCTAssertTrue(user.state == RLMUserStateLoggedOut, @"User should have been logged out, but wasn't");
}

- (void)waitForDownloadsForRealm:(RLMRealm *)realm {
    [self waitForDownloadsForRealm:realm error:nil];
}

- (void)waitForUploadsForRealm:(RLMRealm *)realm {
    [self waitForUploadsForRealm:realm error:nil];
}

- (void)waitForDownloadsForUser:(RLMUser *)user
                 partitionValue:(NSString *)partitionValue
                    expectation:(XCTestExpectation *)expectation
                          error:(NSError **)error {
    RLMSyncSession *session = [user sessionForPartitionValue:partitionValue];
    NSAssert(session, @"Cannot call with invalid partition value");
    XCTestExpectation *ex = expectation ?: [self expectationWithDescription:@"Wait for download completion"];
    __block NSError *theError = nil;
    BOOL queued = [session waitForDownloadCompletionOnQueue:nil callback:^(NSError *err) {
        theError = err;
        [ex fulfill];
    }];
    if (!queued) {
        XCTFail(@"Download waiter did not queue; session was invalid or errored out.");
        return;
    }
    [self waitForExpectations:@[ex] timeout:20.0];
    if (error) {
        *error = theError;
    }
}

- (void)waitForUploadsForRealm:(RLMRealm *)realm error:(NSError **)error {
    RLMSyncSession *session = realm.syncSession;
    NSAssert(session, @"Cannot call with invalid Realm");
    XCTestExpectation *ex = [self expectationWithDescription:@"Wait for upload completion"];
    __block NSError *completionError;
    BOOL queued = [session waitForUploadCompletionOnQueue:nil callback:^(NSError *error) {
        completionError = error;
        [ex fulfill];
    }];
    if (!queued) {
        XCTFail(@"Upload waiter did not queue; session was invalid or errored out.");
        return;
    }
    [self waitForExpectations:@[ex] timeout:20.0];
    if (error)
        *error = completionError;
}

- (void)waitForDownloadsForRealm:(RLMRealm *)realm error:(NSError **)error {
    RLMSyncSession *session = realm.syncSession;
    NSAssert(session, @"Cannot call with invalid Realm");
    XCTestExpectation *ex = [self expectationWithDescription:@"Wait for download completion"];
    __block NSError *completionError;
    BOOL queued = [session waitForDownloadCompletionOnQueue:nil callback:^(NSError *error) {
        completionError = error;
        [ex fulfill];
    }];
    if (!queued) {
        XCTFail(@"Download waiter did not queue; session was invalid or errored out.");
        return;
    }
    [self waitForExpectations:@[ex] timeout:20.0];
    if (error) {
        *error = completionError;
    }
    [realm refresh];
}

- (void)manuallySetAccessTokenForUser:(RLMUser *)user value:(NSString *)tokenValue {
    [user _syncUser]->update_access_token(tokenValue.UTF8String);
}

- (void)manuallySetRefreshTokenForUser:(RLMUser *)user value:(NSString *)tokenValue {
    [user _syncUser]->update_refresh_token(tokenValue.UTF8String);
}

#pragma mark - XCUnitTest Lifecycle

+ (XCTestSuite *)defaultTestSuite {
    if ([RealmServer haveServer]) {
        return [super defaultTestSuite];

    }

    NSLog(@"Skipping sync tests: no server access.");
    return [[XCTestSuite alloc] initWithName:[super defaultTestSuite].name];
}

+ (void)setUp {
    [super setUp];
    // Wait for the server to launch
    if ([RealmServer haveServer]) {
        (void)[RealmServer shared];
    }
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    if (auto ids = NSProcessInfo.processInfo.environment[@"RLMParentAppIds"]) {
        _appIds = [ids componentsSeparatedByString:@","];   //take the one array for split the string
    }
    [NSFileManager.defaultManager removeItemAtURL:self.clientDataRoot error:nil];
    [NSFileManager.defaultManager createDirectoryAtURL:self.clientDataRoot
                           withIntermediateDirectories:YES attributes:nil error:nil];
//    [[RealmServer shared] dropTestData];
}

- (void)tearDown {
    [self resetSyncManager];
    [super tearDown];
}

- (void)setupSyncManager {
    static NSString *s_appId;
    if (self.isParent && s_appId) {
        _appId = s_appId;
    }
    else {
        NSError *error;
        _appId = NSProcessInfo.processInfo.environment[@"RLMParentAppId"] ?: [RealmServer.shared createAppAndReturnError:&error];
        if (error) {
            NSLog(@"Failed to create app: %@", error);
            abort();
        }

        if (self.isParent) {
            s_appId = _appId;
        }
    }

    _app = [RLMApp appWithId:_appId configuration:self.defaultAppConfiguration rootDirectory:self.clientDataRoot];

    RLMSyncManager *syncManager = self.app.syncManager;
    syncManager.logLevel = RLMSyncLogLevelTrace;
    syncManager.userAgent = self.name;
}

- (NSString *)appId {
    if (!_appId) {
        [self setupSyncManager];
    }
    return _appId;
}

- (RLMApp *)app {
    if (!_app) {
        [self setupSyncManager];
    }
    return _app;
}

- (void)resetSyncManager {
    if (!_appId) {
        return;
    }

    NSMutableArray<XCTestExpectation *> *exs = [NSMutableArray new];
    [self.app.allUsers enumerateKeysAndObjectsUsingBlock:^(NSString *, RLMUser *user, BOOL *) {
        XCTestExpectation *ex = [self expectationWithDescription:@"Wait for logout"];
        [exs addObject:ex];
        [user logOutWithCompletion:^(NSError *) {
            [ex fulfill];
        }];

        // Sessions are removed from the user asynchronously after a logout.
        // We need to wait for this to happen before calling resetForTesting as
        // that expects all sessions to be cleaned up first.
        if (user.allSessions.count) {
            [exs addObject:[self expectationForPredicate:[NSPredicate predicateWithFormat:@"allSessions.@count == 0"]
                                     evaluatedWithObject:user handler:nil]];
        }
    }];

    if (exs.count) {
        [self waitForExpectations:exs timeout:60.0];
    }

    [self.app.syncManager resetForTesting];
    [RLMApp resetAppCache];
}

- (NSString *)badAccessToken {
    return @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJl"
    "eHAiOjE1ODE1MDc3OTYsImlhdCI6MTU4MTUwNTk5NiwiaXNzIjoiN"
    "WU0M2RkY2M2MzZlZTEwNmVhYTEyYmRjIiwic3RpdGNoX2RldklkIjo"
    "iMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwIiwic3RpdGNoX2RvbWFpbk"
    "lkIjoiNWUxNDk5MTNjOTBiNGFmMGViZTkzNTI3Iiwic3ViIjoiNWU0M2R"
    "kY2M2MzZlZTEwNmVhYTEyYmRhIiwidHlwIjoiYWNjZXNzIn0.0q3y9KpFx"
    "EnbmRwahvjWU1v9y1T1s3r2eozu93vMc3s";
}

- (void)cleanupRemoteDocuments:(RLMMongoCollection *)collection {
    XCTestExpectation *deleteManyExpectation = [self expectationWithDescription:@"should delete many documents"];
    [collection deleteManyDocumentsWhere:@{}
                              completion:^(NSInteger, NSError * error) {
        XCTAssertNil(error);
        [deleteManyExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (NSURL *)clientDataRoot {
    if (self.isParent) {
        return [NSURL fileURLWithPath:RLMDefaultDirectoryForBundleIdentifier(nil)];
    } else {
        return syncDirectoryForChildProcess();
    }
}

- (NSTask *)childTask {
    return [self childTaskWithAppIds:_appId ? @[_appId] : @[]];
}

@end

#endif // TARGET_OS_OSX
