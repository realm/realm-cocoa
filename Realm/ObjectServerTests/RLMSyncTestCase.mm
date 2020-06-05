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

#import "sync/sync_manager.hpp"
#import "sync/sync_session.hpp"
#import "sync/sync_user.hpp"

// Set this to 1 if you want the test ROS instance to log its debug messages to console.
#define LOG_ROS_OUTPUT 0

#if !TARGET_OS_MAC
#error These tests can only be run on a macOS host.
#endif

static NSString *nodePath() {
    static NSString *path = [] {
        NSDictionary *environment = NSProcessInfo.processInfo.environment;
        if (NSString *path = environment[@"REALM_NODE_PATH"]) {
            return path;
        }
        return @"/usr/local/bin/node";
    }();
    return path;
}

@interface RLMSyncManager ()
+ (void)_setCustomBundleID:(NSString *)customBundleID;
- (NSArray<RLMSyncUser *> *)_allUsers;
@end

@interface RLMSyncTestCase ()
@property (nonatomic) NSTask *task;
@end

@interface RLMSyncSession ()
- (BOOL)waitForUploadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
- (BOOL)waitForDownloadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
@end

@interface RLMSyncUser()
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

+ (instancetype)johnWithRealmId:(NSString *)realmId {
    Person *john = [[Person alloc] init];
    john._id = [RLMObjectId objectId];
    john.age = 30;
    john.firstName = @"John";
    john.lastName = @"Lennon";
    john.realm_id = realmId;
    return john;
}

+ (instancetype)paulWithRealmId:(NSString *)realmId {
    Person *paul = [[Person alloc] init];
    paul._id = [RLMObjectId objectId];
    paul.age = 30;
    paul.firstName = @"Paul";
    paul.lastName = @"McCartney";
    paul.realm_id = realmId;
    return paul;
}

+ (instancetype)ringoWithRealmId:(NSString *)realmId {
    Person *ringo = [[Person alloc] init];
    ringo._id = [RLMObjectId objectId];
    ringo.age = 30;
    ringo.firstName = @"Ringo";
    ringo.lastName = @"Starr";
    ringo.realm_id = realmId;
    return ringo;
}

+ (instancetype)georgeWithRealmId:(NSString *)realmId {
    Person *george = [[Person alloc] init];
    george._id = [RLMObjectId objectId];
    george.age = 30;
    george.firstName = @"George";
    george.lastName = @"Harrison";
    george.realm_id = realmId;
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

static NSTask *s_task;

static NSURL *syncDirectoryForChildProcess() {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = bundle.bundleIdentifier ?: bundle.executablePath.lastPathComponent;
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-child", bundleIdentifier]];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

#pragma mark RealmObjectServer

@implementation RealmObjectServer {
}

+ (instancetype)sharedServer {
    static RealmObjectServer *instance = [RealmObjectServer new];
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        if (getenv("RLMProcessIsChild")) {
            return self;
        }

        [self downloadAdminSDK];

        NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];

        NSTask *task = [[NSTask alloc] init];
        task.currentDirectoryPath = directory;
        task.launchPath = @"/usr/bin/ruby";
        task.arguments = @[[directory stringByAppendingPathComponent:@"run_baas.rb"], @"shutdown"];
        [task launch];
        [task waitUntilExit];

        task = [[NSTask alloc] init];
        task.currentDirectoryPath = directory;
        task.launchPath = @"/usr/bin/ruby";
        task.arguments = @[[directory stringByAppendingPathComponent:@"run_baas.rb"], @"start"];
        [task launch];
        [task waitUntilExit];

        __block BOOL isLive = NO;
        NSInteger tryCount = 0;
        const NSTimeInterval timeout = 4;

        while (tryCount < 100 && !isLive) {
            __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            [[[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]]
              dataTaskWithURL:[NSURL URLWithString:@"http://127.0.0.1:9090"]
              completionHandler:^(NSData * _Nullable, NSURLResponse * _Nullable response, NSError * _Nullable) {
                NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
                isLive = [urlResponse statusCode] == 200;
                dispatch_semaphore_signal(sema);
            }] resume];

            BOOL canConnect = dispatch_semaphore_wait(sema,
                                                      dispatch_time(DISPATCH_TIME_NOW,
                                                                    (int64_t)(timeout * NSEC_PER_SEC))) == 0;

            if (!canConnect) {
                NSLog(@"Timed out while trying to connect to MongoDB Realm at http://127.0.0.1:9090");
                abort();
            }

            tryCount++;
            sleep(1);
        }

        if (!isLive) {
            NSLog(@"Timed out while trying to connect to MongoDB Realm at http://127.0.0.1:9090");
            abort();
        }
    }
    return self;
}

- (void)cleanUp {
    if (getenv("RLMProcessIsChild")) {
        return;
    }

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = nodePath();
    NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];
    task.arguments = @[[directory stringByAppendingPathComponent:@"admin.js"], @"clean"];
    [task launch];
    [task waitUntilExit];

    task = [[NSTask alloc] init];
    task.currentDirectoryPath = directory;
    task.launchPath = @"/usr/bin/ruby";
    task.arguments = @[[directory stringByAppendingPathComponent:@"run_baas.rb"], @"shutdown"];
    [task launch];
    [task waitUntilExit];
}

- (NSString *)createApp {
    // Set up the actual MongoDB Realm creation task
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = nodePath();
    NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];
    task.arguments = @[[directory stringByAppendingPathComponent:@"admin.js"], @"create"];
    task.standardOutput = pipe;
    [task launch];

    NSData *childStdout = pipe.fileHandleForReading.readDataToEndOfFile;
    NSString *appId = [[NSString alloc] initWithData:childStdout encoding:NSUTF8StringEncoding];
    if (!appId.length) {
        abort();
    }

    return appId;
}

- (NSString *)lastApp {
    // Set up the actual MongoDB Realm last app task
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = nodePath();
    NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];
    task.arguments = @[[directory stringByAppendingPathComponent:@"admin.js"], @"last"];
    task.standardOutput = pipe;
    [task launch];

    NSData *childStdout = pipe.fileHandleForReading.readDataToEndOfFile;
    NSString *appId = [[NSString alloc] initWithData:childStdout encoding:NSUTF8StringEncoding];

    if (!appId.length) {
        abort();
    }

    return appId;
}


- (NSString *)desiredAdminSDKVersion {
    auto path = [[[[@(__FILE__) stringByDeletingLastPathComponent] // RLMSyncTestCase.mm
                   stringByDeletingLastPathComponent] // ObjectServerTests
                  stringByDeletingLastPathComponent] // Realm
                 stringByAppendingPathComponent:@"dependencies.list"];
    auto file = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!file) {
        NSLog(@"Failed to read dependencies.list");
        abort();
    }

    auto regex = [NSRegularExpression regularExpressionWithPattern:@"^MONGODB_STITCH_ADMIN_SDK_VERSION=(.*)$"
                                                           options:NSRegularExpressionAnchorsMatchLines error:nil];
    auto match = [regex firstMatchInString:file options:0 range:{0, file.length}];
    if (!match) {
        NSLog(@"Failed to read MONGODB_STITCH_ADMIN_SDK_VERSION from dependencies.list");
        abort();
    }
    return [file substringWithRange:[match rangeAtIndex:1]];
}

- (NSString *)currentAdminSDKVersion {
    auto path = [[[[@(__FILE__) stringByDeletingLastPathComponent] // RLMSyncTestCase.mm
                 stringByAppendingPathComponent:@"node_modules"]
                 stringByAppendingPathComponent:@"mongodb-stitch"]
                 stringByAppendingPathComponent:@"package.json"];
    auto file = [NSData dataWithContentsOfFile:path];
    if (!file) {
        return nil;
    }

    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:file options:0 error:&error];
    if (!json) {
        NSLog(@"Error reading version from installed Admin SDK: %@", error);
        abort();
    }

    return json[@"version"];
}

- (void)downloadAdminSDK {
    NSString *desiredVersion = [self desiredAdminSDKVersion];
    NSString *currentVersion = [self currentAdminSDKVersion];
    if ([currentVersion isEqualToString:desiredVersion]) {
        return;
    }

    NSLog(@"Installing Realm Cloud %@", desiredVersion);
    NSTask *task = [[NSTask alloc] init];
    task.currentDirectoryPath = [@(__FILE__) stringByDeletingLastPathComponent];
    task.launchPath = nodePath();
    task.arguments = @[[[nodePath() stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"npm"],
                       @"--scripts-prepend-node-path=auto",
                       @"--no-color",
                       @"--no-progress",
                       @"--no-save",
                       @"--no-package-lock",
                       @"install",
                       [@"mongodb-stitch@" stringByAppendingString:desiredVersion]
    ];
    [task launch];
    [task waitUntilExit];
}
@end

#pragma mark RLMSyncTestCase

@implementation RLMSyncTestCase

#pragma mark - Helper methods

- (BOOL)isPartial {
    return NO;
}

- (RLMAppCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister {
    if (shouldRegister) {
        XCTestExpectation *expectation = [self expectationWithDescription:@""];
        [[[self app] usernamePasswordProviderClient] registerEmail:name password:@"password" completion:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];
        [self waitForExpectationsWithTimeout:4.0 handler:nil];
    }
    return [RLMAppCredentials credentialsWithUsername:name
                                             password:@"password"];
}

+ (NSURL *)onDiskPathForSyncedRealm:(RLMRealm *)realm {
    return [NSURL fileURLWithPath:@(realm->_realm->config().path.data())];
}

- (RLMAppConfiguration*) defaultAppConfiguration {
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

- (void)waitForDownloadsForUser:(RLMSyncUser *)user
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

- (RLMRealm *)openRealmForPartitionValue:(NSString *)partitionValue user:(RLMSyncUser *)user {
    return [self openRealmForPartitionValue:partitionValue user:user immediatelyBlock:nil];
}

- (RLMRealm *)openRealmForPartitionValue:(NSString *)partitionValue user:(RLMSyncUser *)user immediatelyBlock:(void(^)(void))block {
    return [self openRealmForPartitionValue:partitionValue
                                       user:user
                              encryptionKey:nil
                                 stopPolicy:RLMSyncStopPolicyAfterChangesUploaded
                           immediatelyBlock:block];
}

- (RLMRealm *)openRealmForPartitionValue:(NSString *)partitionValue
                                    user:(RLMSyncUser *)user
                           encryptionKey:(nullable NSData *)encryptionKey
                              stopPolicy:(RLMSyncStopPolicy)stopPolicy
                        immediatelyBlock:(nullable void(^)(void))block {
    RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:partitionValue user:user encryptionKey:encryptionKey stopPolicy:stopPolicy];
    if (block) {
        block();
    }
    return realm;
}

- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration {
    return [self openRealmWithConfiguration:configuration immediatelyBlock:nullptr];
}

- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration
                        immediatelyBlock:(nullable void(^)(void))block {
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nullptr];
    if (block) {
        block();
    }
    return realm;
}
- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue user:(RLMSyncUser *)user {
    return [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                  user:user
                                         encryptionKey:nil
                                            stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
}

- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue
                                               user:(RLMSyncUser *)user
                                      encryptionKey:(NSData *)encryptionKey
                                         stopPolicy:(RLMSyncStopPolicy)stopPolicy {
    auto c = [user configurationWithPartitionValue:partitionValue];
    c.encryptionKey = encryptionKey;
    RLMSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.stopPolicy = stopPolicy;
    c.syncConfiguration = syncConfig;
    return [RLMRealm realmWithConfiguration:c error:nil];
}

- (RLMSyncUser *)logInUserForCredentials:(RLMAppCredentials *)credentials {
    RLMApp *app = [self app];
    __block RLMSyncUser* theUser;
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [app loginWithCredential:credentials completion:^(RLMSyncUser * _Nullable user, NSError * _Nullable) {
        theUser = user;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:4.0 handler:nil];
    XCTAssertTrue(theUser.state == RLMSyncUserStateLoggedIn, @"User should have been valid, but wasn't");
    return theUser;
}

- (void)logOutUser:(RLMSyncUser *)user {
    RLMApp *app = [self app];
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [app logOut:user completion:^(NSError * error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:4.0 handler:nil];
    XCTAssertTrue(user.state == RLMSyncUserStateLoggedOut, @"User should have been logged out, but wasn't");
}

- (void)waitForDownloadsForRealm:(RLMRealm *)realm {
    [self waitForDownloadsForRealm:realm error:nil];
}

- (void)waitForUploadsForRealm:(RLMRealm *)realm {
    [self waitForUploadsForRealm:realm error:nil];
}

- (void)waitForDownloadsForUser:(RLMSyncUser *)user
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
    if (error)
        *error = completionError;
}

- (void)manuallySetAccessTokenForUser:(RLMSyncUser *)user value:(NSString *)tokenValue {
    [user _syncUser]->update_access_token(tokenValue.UTF8String);
}

- (void)manuallySetRefreshTokenForUser:(RLMSyncUser *)user value:(NSString *)tokenValue {
    [user _syncUser]->update_refresh_token(tokenValue.UTF8String);
}

// FIXME: remove this API once the new token system is implemented.
- (void)primeSyncManagerWithSemaphore:(dispatch_semaphore_t)semaphore {
    if (semaphore == nil) {
        [[[self app] syncManager] setSessionCompletionNotifier:^(__unused NSError *error){ }];
        return;
    }
    [[[self app] syncManager] setSessionCompletionNotifier:^(NSError *error) {
        XCTAssertNil(error, @"Session completion block returned with an error: %@", error);
        dispatch_semaphore_signal(semaphore);
    }];
}

#pragma mark - XCUnitTest Lifecycle

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;


    [self resetSyncManager];

    static bool is_parent = [self isParent];

    atexit([] {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            if (is_parent) [[RealmObjectServer sharedServer] cleanUp];
        });
    });
    [self setupSyncManager];
}

- (void)tearDown {
    [self resetSyncManager];

    if ([self isParent]) {
        NSTask *task = [[NSTask alloc] init];
        NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];
        task.currentDirectoryPath = directory;
        task.launchPath = @"/usr/bin/ruby";
        task.arguments = @[[directory stringByAppendingPathComponent:@"run_baas.rb"], @"clean"];
        [task launch];
        [task waitUntilExit];
    }

    [super tearDown];
}

- (void)setupSyncManager {
    NSURL *clientDataRoot;
    NSError *error;
    if (self.isParent) {
        clientDataRoot = [NSURL fileURLWithPath:RLMDefaultDirectoryForBundleIdentifier(nil)];
    } else {
        clientDataRoot = syncDirectoryForChildProcess();
    }
    [NSFileManager.defaultManager removeItemAtURL:clientDataRoot error:&error];
    [NSFileManager.defaultManager createDirectoryAtURL:clientDataRoot
                           withIntermediateDirectories:YES attributes:nil error:&error];

    if (self.isParent) {
        _appId = [RealmObjectServer.sharedServer createApp];
        _app = [RLMApp appWithId:_appId configuration:[self defaultAppConfiguration] rootDirectory:clientDataRoot];
    } else {
        _appId = [RealmObjectServer.sharedServer lastApp];
        _app = [RLMApp appWithId:_appId configuration:[self defaultAppConfiguration] rootDirectory:clientDataRoot];
    }

    RLMSyncManager *syncManager = [[self app] syncManager];
    syncManager.logLevel = RLMSyncLogLevelTrace;
    syncManager.userAgent = self.name;
}

- (void)resetSyncManager {
    if ([self appId]) {
        NSMutableArray<XCTestExpectation *> *exs = [NSMutableArray new];
        [self.app.allUsers enumerateKeysAndObjectsUsingBlock:^(NSString *, RLMSyncUser *user, BOOL *) {
            XCTestExpectation *ex = [self expectationWithDescription:@"Wait for logout"];
            [exs addObject:ex];
            [self.app logOut:user completion:^(NSError *) {
                [ex fulfill];
            }];
        }];
        [self waitForExpectations:exs timeout:60.0];

        [[[self app] syncManager] resetForTesting];
    }
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

@end
