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
#import "RLMSyncManager_Private.h"
#import "RLMSyncSessionRefreshHandle+ObjectServerTests.h"
#import "RLMSyncConfiguration_Private.h"
#import "RLMUtil.hpp"
#import "RLMApp.h"

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
- (void)configureWithRootDirectory:(NSURL *)rootDirectory;
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

@implementation SyncObject
@end

@implementation HugeSyncObject

+ (instancetype)object  {
    const NSInteger fakeDataSize = 1000000;
    HugeSyncObject *object = [[self alloc] init];
    char fakeData[fakeDataSize];
    memset(fakeData, 16, sizeof(fakeData));
    object.dataProp = [NSData dataWithBytes:fakeData length:sizeof(fakeData)];
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

@interface RealmObjectServer : NSObject
@property (nonatomic, readonly) NSString *appId;
+ (instancetype)sharedServer;

- (NSString *)createApp;

@end

@implementation RealmObjectServer {
}

+ (instancetype)sharedServer {
    static RealmObjectServer *instance = [RealmObjectServer new];
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self downloadAdminSDK];

        NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];

        NSTask *task = [[NSTask alloc] init];
        task.currentDirectoryPath = directory;
        task.launchPath = @"/bin/sh";
        task.arguments = @[@"run_baas.sh"];
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
        }

        if (!isLive) {
            NSLog(@"Timed out while trying to connect to MongoDB Realm at http://127.0.0.1:9090");
            abort();
        }

        atexit([] {
            [[RealmObjectServer sharedServer] cleanUp];
        });
    }
    return self;
}

- (void)cleanUp {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = nodePath();
    NSString *directory = [@(__FILE__) stringByDeletingLastPathComponent];
    task.arguments = @[[directory stringByAppendingPathComponent:@"admin.js"], @"clean"];
    [task launch];
    [task waitUntilExit];

    task = [[NSTask alloc] init];
    task.currentDirectoryPath = directory;
    task.launchPath = @"/bin/sh";
    task.arguments = @[[directory stringByAppendingPathComponent:@"run_baas.sh"], @"clean"];
    [task launch];
    [task waitUntilExit];

    [[NSTask launchedTaskWithLaunchPath:@"/usr/bin/pkill"
                              arguments:@[@"-f", @"stitch"]] waitUntilExit];
}

- (NSString *)createApp {
    // Set up the actual ROS task
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

@implementation RLMSyncTestCase

#pragma mark - Helper methods

- (BOOL)isPartial {
    return NO;
}

+ (NSURL *)authServerURL {
    return [NSURL URLWithString:@"http://127.0.0.1:9090"];
}

+ (NSURL *)secureAuthServerURL {
    return [NSURL URLWithString:@"https://localhost:9443"];
}

+ (RLMAppCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister {
    return [RLMAppCredentials credentialsWithUsername:name
                                              password:@"a"];
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

- (void)addSyncObjectsToRealm:(RLMRealm *)realm descriptions:(NSArray<NSString *> *)descriptions {
    [realm beginWriteTransaction];
    for (NSString *desc in descriptions) {
        [SyncObject createInRealm:realm withValue:@[desc]];
    }
    [realm commitWriteTransaction];
}

- (void)waitForDownloadsForUser:(RLMSyncUser *)user
                         realms:(NSArray<RLMRealm *> *)realms
                      realmURLs:(NSArray<NSURL *> *)realmURLs
                 expectedCounts:(NSArray<NSNumber *> *)counts {
    NSAssert(realms.count == counts.count && realms.count == realmURLs.count,
             @"Test logic error: all array arguments must be the same size.");
    for (NSUInteger i = 0; i < realms.count; i++) {
        [self waitForDownloadsForUser:user url:realmURLs[i] expectation:nil error:nil];
        [realms[i] refresh];
        CHECK_COUNT([counts[i] integerValue], SyncObject, realms[i]);
    }
}

- (RLMRealm *)openRealmForURL:(NSURL *)url user:(RLMSyncUser *)user {
    return [self openRealmForURL:url user:user immediatelyBlock:nil];
}

- (RLMRealm *)openRealmForURL:(NSURL *)url user:(RLMSyncUser *)user immediatelyBlock:(void(^)(void))block {
    return [self openRealmForURL:url
                            user:user
                   encryptionKey:nil
                      stopPolicy:RLMSyncStopPolicyAfterChangesUploaded
                immediatelyBlock:block];
}

- (RLMRealm *)openRealmForURL:(NSURL *)url
                         user:(RLMSyncUser *)user
                encryptionKey:(nullable NSData *)encryptionKey
                   stopPolicy:(RLMSyncStopPolicy)stopPolicy
             immediatelyBlock:(nullable void(^)(void))block {
    const NSTimeInterval timeout = 4;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    RLMSyncManager.sharedManager.sessionCompletionNotifier = ^(NSError *error) {
        if (error) {
            XCTFail(@"Received an asynchronous error when trying to open Realm at '%@' for user '%@': %@ (process: %@)",
                    url, user.identity, error, self.isParent ? @"parent" : @"child");
        }
        dispatch_semaphore_signal(sema);
    };

    RLMRealm *realm = [self immediatelyOpenRealmForURL:url user:user encryptionKey:encryptionKey stopPolicy:stopPolicy];
    if (block) {
        block();
    }
    // Wait for login to succeed or fail.
    XCTAssert(dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) == 0,
              @"Timed out while trying to asynchronously open Realm for URL: %@", url);
    RLMSyncManager.sharedManager.sessionCompletionNotifier = nil;
    return realm;
}

- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration {
    return [self openRealmWithConfiguration:configuration immediatelyBlock:nullptr];
}

- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration
             immediatelyBlock:(nullable void(^)(void))block {
    const NSTimeInterval timeout = 4;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    RLMSyncConfiguration *syncConfig = configuration.syncConfiguration;
    RLMSyncManager.sharedManager.sessionCompletionNotifier = ^(NSError *error) {
        if (error) {
            XCTFail(@"Received an asynchronous error when trying to open Realm at '%@' for user '%@': %@ (process: %@)",
                    syncConfig.realmURL, syncConfig.user.identity, error, self.isParent ? @"parent" : @"child");
        }
        dispatch_semaphore_signal(sema);
    };

    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nullptr];
    if (block) {
        block();
    }
    // Wait for login to succeed or fail.
    XCTAssert(dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) == 0,
              @"Timed out while trying to asynchronously open Realm for URL: %@", syncConfig.realmURL);
    return realm;
}
- (RLMRealm *)immediatelyOpenRealmForURL:(NSURL *)url user:(RLMSyncUser *)user {
    return [self immediatelyOpenRealmForURL:url
                                       user:user
                              encryptionKey:nil
                                 stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
}

- (RLMRealm *)immediatelyOpenRealmForURL:(NSURL *)url
                                    user:(RLMSyncUser *)user
                           encryptionKey:(NSData *)encryptionKey
                              stopPolicy:(RLMSyncStopPolicy)stopPolicy {
    auto c = [user configurationWithURL:url];
    c.encryptionKey = encryptionKey;
    RLMSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.stopPolicy = stopPolicy;
    c.syncConfiguration = syncConfig;
    return [RLMRealm realmWithConfiguration:c error:nil];
}

- (RLMSyncUser *)logInUserForCredentials:(RLMAppCredentials *)credentials
                                  server:(NSURL *)url {
    RLMApp *app = [RLMApp app:self.appId configuration:[self defaultAppConfiguration]];
    __block RLMSyncUser* theUser;
    [app loginWithCredential:credentials completion:^(RLMSyncUser * _Nullable user, NSError * _Nullable) {
        theUser = user;
    }];
    [self waitForExpectationsWithTimeout:4.0 handler:nil];
    XCTAssertTrue(theUser.state == RLMSyncUserStateLoggedIn, @"User should have been valid, but wasn't");
    return theUser;
}

- (void)waitForDownloadsForRealm:(RLMRealm *)realm {
    [self waitForDownloadsForRealm:realm error:nil];
}

- (void)waitForUploadsForRealm:(RLMRealm *)realm {
    [self waitForUploadsForRealm:realm error:nil];
}

- (void)waitForDownloadsForUser:(RLMSyncUser *)user
                            url:(NSURL *)url
                    expectation:(XCTestExpectation *)expectation
                          error:(NSError **)error {
    RLMSyncSession *session = [user sessionForURL:url];
    NSAssert(session, @"Cannot call with invalid URL");
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

- (void)manuallySetRefreshTokenForUser:(RLMSyncUser *)user value:(NSString *)tokenValue {
    [user _syncUser]->update_refresh_token(tokenValue.UTF8String);
}

// FIXME: remove this API once the new token system is implemented.
- (void)primeSyncManagerWithSemaphore:(dispatch_semaphore_t)semaphore {
    if (semaphore == nil) {
        [[RLMSyncManager sharedManager] setSessionCompletionNotifier:^(__unused NSError *error){ }];
        return;
    }
    [[RLMSyncManager sharedManager] setSessionCompletionNotifier:^(NSError *error) {
        XCTAssertNil(error, @"Session completion block returned with an error: %@", error);
        dispatch_semaphore_signal(semaphore);
    }];
}

#pragma mark - XCUnitTest Lifecycle

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;

    REALM_ASSERT(RLMSyncManager.sharedManager._allUsers.count == 0);
    [self resetSyncManager];
    [self setupSyncManager];
}

- (void)tearDown {
    [self resetSyncManager];
    [super tearDown];
}

+ (void)tearDown {

}

- (void)setupSyncManager {
    NSURL *clientDataRoot;
    if (self.isParent) {
        _appId = [RealmObjectServer.sharedServer createApp];
        clientDataRoot = [NSURL fileURLWithPath:RLMDefaultDirectoryForBundleIdentifier(nil)];
    }
    else {
        clientDataRoot = syncDirectoryForChildProcess();
    }

    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:clientDataRoot error:&error];
    [NSFileManager.defaultManager createDirectoryAtURL:clientDataRoot
                           withIntermediateDirectories:YES attributes:nil error:&error];
    RLMSyncManager *syncManager = RLMSyncManager.sharedManager;
    [syncManager configureWithRootDirectory:clientDataRoot];
    syncManager.logLevel = RLMSyncLogLevelOff;
    syncManager.userAgent = self.name;
}

- (void)resetSyncManager {
//    [RLMSyncManager.sharedManager._allUsers makeObjectsPerformSelector:@selector(logOutWithCompletion)];
    [RLMSyncManager resetForTesting];
    [RLMSyncSessionRefreshHandle calculateFireDateUsingTestLogic:NO blockOnRefreshCompletion:nil];
}

@end
