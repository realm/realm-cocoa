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
#import "RLMUser+ObjectServerTests.h"

#import "RLMApp_Private.hpp"
#import "RLMBSON_Private.hpp"
#import "RLMCredentials.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMRealm+Sync.h"
#import "RLMRealmConfiguration_Private.h"
#import "RLMRealmUtil.hpp"
#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMSyncConfiguration_Private.h"
#import "RLMSyncManager_Private.hpp"
#import "RLMSyncUtil_Private.h"
#import "RLMUser_Private.hpp"
#import "RLMWatchTestUtility.h"

#import <realm/object-store/shared_realm.hpp>
#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/util/file.hpp>

#if TARGET_OS_OSX

#pragma mark - Helpers

// These are defined in Swift. Importing the auto-generated header doesn't work
// when building with SPM, so just redeclare the bits we need.
@interface RealmServer : NSObject
+ (RealmServer *)shared;
- (NSString *)createAppAndReturnError:(NSError **)error;
@end

@interface TimeoutProxyServer : NSObject
- (instancetype)initWithPort:(uint16_t)port targetPort:(uint16_t)targetPort;
- (void)startAndReturnError:(NSError **)error;
- (void)stop;
@property (nonatomic) double delay;
@end

@interface RLMUser (Test)
@end
@implementation RLMUser (Test)
- (RLMRealmConfiguration *)configurationWithTestSelector:(SEL)sel {
    auto config = [self configurationWithPartitionValue:NSStringFromSelector(sel)];
    config.objectClasses = @[Person.class, HugeSyncObject.class];
    return config;
}

@end

@interface RLMObjectServerTests : RLMSyncTestCase
@end
@implementation RLMObjectServerTests

#pragma mark - App Tests

static NSString *generateRandomString(int num) {
    NSMutableString *string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%c", (char)('a' + arc4random_uniform(26))];
    }
    return string;
}

- (RLMUser *)userForTest:(SEL)sel {
    return [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(sel)
                                                               register:self.isParent]];
}

#pragma mark - Authentication and Tokens

- (void)testAnonymousAuthentication {
    RLMUser *syncUser = self.anonymousUser;
    RLMUser *currentUser = [self.app currentUser];
    XCTAssert([currentUser.identifier isEqualToString:syncUser.identifier]);
    XCTAssert([currentUser.refreshToken isEqualToString:syncUser.refreshToken]);
    XCTAssert([currentUser.accessToken isEqualToString:syncUser.accessToken]);
}

- (void)testCallFunction {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should get sum of arguments from remote function"];
    [self.anonymousUser callFunctionNamed:@"sum"
                                arguments:@[@1, @2, @3, @4, @5]
                          completionBlock:^(id<RLMBSON> bson, NSError *error) {
        XCTAssert(!error);
        XCTAssertEqual([((NSNumber *)bson) intValue], 15);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testLogoutCurrentUser {
    RLMUser *user = self.anonymousUser;
    XCTestExpectation *expectation = [self expectationWithDescription:@"should log out current user"];
    [self.app.currentUser logOutWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(user.state, RLMUserStateRemoved);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testLogoutSpecificUser {
    RLMUser *firstUser = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                             register:YES]];
    RLMUser *secondUser = [self logInUserForCredentials:[self basicCredentialsWithName:@"test1@10gen.com"
                                                                              register:YES]];

    XCTAssertEqualObjects(self.app.currentUser.identifier, secondUser.identifier);
    // `[app currentUser]` will now be `secondUser`, so let's logout firstUser and ensure
    // the state is correct
    XCTestExpectation *expectation = [self expectationWithDescription:@"should log out current user"];
    [firstUser logOutWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(firstUser.state, RLMUserStateLoggedOut);
        XCTAssertEqual(secondUser.state, RLMUserStateLoggedIn);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSwitchUser {
    RLMApp *app = self.app;

    RLMUser *syncUserA = [self anonymousUser];
    RLMUser *syncUserB = [self userForTest:_cmd];

    XCTAssertNotEqualObjects(syncUserA.identifier, syncUserB.identifier);
    XCTAssertEqualObjects(app.currentUser.identifier, syncUserB.identifier);

    XCTAssertEqualObjects([app switchToUser:syncUserA].identifier, syncUserA.identifier);
}

- (void)testRemoveUser {
    RLMUser *firstUser = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                             register:YES]];
    RLMUser *secondUser = [self logInUserForCredentials:[self basicCredentialsWithName:@"test2@10gen.com"
                                                                              register:YES]];

    XCTAssert([self.app.currentUser.identifier isEqualToString:secondUser.identifier]);

    XCTestExpectation *removeUserExpectation = [self expectationWithDescription:@"should remove user"];

    [secondUser removeWithCompletion:^(NSError *error) {
        XCTAssert(!error);
        XCTAssert(self.app.allUsers.count == 1);
        XCTAssert([self.app.currentUser.identifier isEqualToString:firstUser.identifier]);
        [removeUserExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testDeviceRegistration {
    RLMPushClient *client = [self.app pushClientWithServiceName:@"gcm"];
    auto expectation = [self expectationWithDescription:@"should register device"];
    [client registerDeviceWithToken:@"token" user:self.anonymousUser completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    expectation = [self expectationWithDescription:@"should deregister device"];
    [client deregisterDeviceForUser:self.app.currentUser completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

// FIXME: Reenable once possible underlying race condition is understood
- (void)fixme_testMultipleRegisterDevice {
    RLMApp *app = self.app;
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should register device"];
    XCTestExpectation *secondRegisterExpectation = [self expectationWithDescription:@"should not throw error when attempting to register again"];

    RLMUser *user = self.anonymousUser;
    RLMPushClient *client = [app pushClientWithServiceName:@"gcm"];
    [client registerDeviceWithToken:@"token" user:user completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [registerExpectation fulfill];
    }];
    [self waitForExpectations:@[registerExpectation] timeout:10.0];

    [client registerDeviceWithToken:@"token" user:user completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [secondRegisterExpectation fulfill];
    }];
    [self waitForExpectations:@[secondRegisterExpectation] timeout:10.0];
}

#pragma mark - RLMEmailPasswordAuth

static NSString *randomEmail() {
    return [NSString stringWithFormat:@"%@@%@.com", generateRandomString(10), generateRandomString(10)];
}

- (void)testRegisterEmailAndPassword {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should register with email and password"];

    NSString *randomPassword = generateRandomString(10);
    [self.app.emailPasswordAuth registerUserWithEmail:randomEmail() password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testConfirmUser {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try confirm user and fail"];

    [self.app.emailPasswordAuth confirmUser:randomEmail() tokenId:@"a_token" completion:^(NSError *error) {
        XCTAssertEqual(error.code, RLMAppErrorBadRequest);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testResendConfirmationEmail {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try resend confirmation email and fail"];

    [self.app.emailPasswordAuth resendConfirmationEmail:randomEmail() completion:^(NSError *error) {
        XCTAssertEqual(error.code, RLMAppErrorUserNotFound);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testResetPassword {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try reset password and fail"];
    [self.app.emailPasswordAuth resetPasswordTo:@"APassword123" token:@"a_token" tokenId:@"a_token_id" completion:^(NSError *error) {
        XCTAssertEqual(error.code, RLMAppErrorBadRequest);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testCallResetPasswordFunction {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try call reset password function and fail"];
    [self.app.emailPasswordAuth callResetPasswordFunction:@"test@mongodb.com"
                                                 password:@"aPassword123"
                                                     args:@[@{}]
                                               completion:^(NSError *error) {
        XCTAssertEqual(error.code, RLMAppErrorUserNotFound);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

#pragma mark - UserAPIKeyProviderClient

- (void)testUserAPIKeyProviderClientFlow {
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should try register"];
    XCTestExpectation *loginExpectation = [self expectationWithDescription:@"should try login"];
    XCTestExpectation *createAPIKeyExpectationA = [self expectationWithDescription:@"should try create an api key"];
    XCTestExpectation *createAPIKeyExpectationB = [self expectationWithDescription:@"should try create an api key"];
    XCTestExpectation *fetchAPIKeysExpectation = [self expectationWithDescription:@"should try call fetch api keys"];
    XCTestExpectation *disableAPIKeyExpectation = [self expectationWithDescription:@"should try disable api key"];
    XCTestExpectation *enableAPIKeyExpectation = [self expectationWithDescription:@"should try enable api key"];
    XCTestExpectation *deleteAPIKeyExpectation = [self expectationWithDescription:@"should try delete api key"];

    __block RLMUser *syncUser;
    __block RLMUserAPIKey *userAPIKeyA;
    __block RLMUserAPIKey *userAPIKeyB;

    NSString *randomPassword = generateRandomString(10);
    NSString *email = randomEmail();
    [self.app.emailPasswordAuth registerUserWithEmail:email password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [registerExpectation fulfill];
    }];

    [self waitForExpectations:@[registerExpectation] timeout:60.0];

    [self.app loginWithCredential:[RLMCredentials credentialsWithEmail:email password:randomPassword]
                  completion:^(RLMUser *user, NSError *error) {
        XCTAssert(!error);
        XCTAssert(user);
        syncUser = user;
        [loginExpectation fulfill];
    }];

    [self waitForExpectations:@[loginExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] createAPIKeyWithName:@"apiKeyName1" completion:^(RLMUserAPIKey *userAPIKey, NSError *error) {
        XCTAssert(!error);
        XCTAssert([userAPIKey.name isEqualToString:@"apiKeyName1"]);
        userAPIKeyA = userAPIKey;
        [createAPIKeyExpectationA fulfill];
    }];

    [[syncUser apiKeysAuth] createAPIKeyWithName:@"apiKeyName2" completion:^(RLMUserAPIKey *userAPIKey, NSError *error) {
        XCTAssert(!error);
        XCTAssert([userAPIKey.name isEqualToString:@"apiKeyName2"]);
        userAPIKeyB = userAPIKey;
        [createAPIKeyExpectationB fulfill];
    }];

    [self waitForExpectations:@[createAPIKeyExpectationA, createAPIKeyExpectationB] timeout:60.0];

    // sleep for 2 seconds as there seems to be an issue fetching the keys straight after they are created.
    [NSThread sleepForTimeInterval:2];

    [[syncUser apiKeysAuth] fetchAPIKeysWithCompletion:^(NSArray<RLMUserAPIKey *> *_Nonnull apiKeys, NSError *error) {
        XCTAssert(!error);
        XCTAssert(apiKeys.count == 2);
        [fetchAPIKeysExpectation fulfill];
    }];

    [self waitForExpectations:@[fetchAPIKeysExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] disableAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [disableAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[disableAPIKeyExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] enableAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [enableAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[enableAPIKeyExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] deleteAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [deleteAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[deleteAPIKeyExpectation] timeout:60.0];
}

#pragma mark - Link user -

- (void)testLinkUser {
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should try register"];
    XCTestExpectation *loginExpectation = [self expectationWithDescription:@"should try login"];
    XCTestExpectation *linkExpectation = [self expectationWithDescription:@"should try link and fail"];

    __block RLMUser *syncUser;

    NSString *email = randomEmail();
    NSString *randomPassword = generateRandomString(10);

    [self.app.emailPasswordAuth registerUserWithEmail:email password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [registerExpectation fulfill];
    }];

    [self waitForExpectations:@[registerExpectation] timeout:60.0];

    [self.app loginWithCredential:[RLMCredentials credentialsWithEmail:email password:randomPassword]
                       completion:^(RLMUser *user, NSError *error) {
        XCTAssert(!error);
        XCTAssert(user);
        syncUser = user;
        [loginExpectation fulfill];
    }];

    [self waitForExpectations:@[loginExpectation] timeout:60.0];

    [syncUser linkUserWithCredentials:[RLMCredentials credentialsWithFacebookToken:@"a_token"]
                           completion:^(RLMUser *user, NSError *error) {
        XCTAssert(!user);
        XCTAssertEqual(error.code, RLMAppErrorInvalidSession);
        [linkExpectation fulfill];
    }];

    [self waitForExpectations:@[linkExpectation] timeout:60.0];
}

#pragma mark - Auth Credentials -

- (void)testEmailPasswordCredential {
    RLMCredentials *emailPasswordCredential = [RLMCredentials credentialsWithEmail:@"test@mongodb.com" password:@"apassword"];
    XCTAssertEqualObjects(emailPasswordCredential.provider, @"local-userpass");
}

- (void)testJWTCredential {
    RLMCredentials *jwtCredential = [RLMCredentials credentialsWithJWT:@"sometoken"];
    XCTAssertEqualObjects(jwtCredential.provider, @"custom-token");
}

- (void)testAnonymousCredential {
    RLMCredentials *anonymousCredential = [RLMCredentials anonymousCredentials];
    XCTAssertEqualObjects(anonymousCredential.provider, @"anon-user");
}

- (void)testUserAPIKeyCredential {
    RLMCredentials *userAPICredential = [RLMCredentials credentialsWithUserAPIKey:@"apikey"];
    XCTAssertEqualObjects(userAPICredential.provider, @"api-key");
}

- (void)testServerAPIKeyCredential {
    RLMCredentials *serverAPICredential = [RLMCredentials credentialsWithServerAPIKey:@"apikey"];
    XCTAssertEqualObjects(serverAPICredential.provider, @"api-key");
}

- (void)testFacebookCredential {
    RLMCredentials *facebookCredential = [RLMCredentials credentialsWithFacebookToken:@"facebook token"];
    XCTAssertEqualObjects(facebookCredential.provider, @"oauth2-facebook");
}

- (void)testGoogleCredential {
    RLMCredentials *googleCredential = [RLMCredentials credentialsWithGoogleAuthCode:@"google token"];
    XCTAssertEqualObjects(googleCredential.provider, @"oauth2-google");
}

- (void)testGoogleIdCredential {
    RLMCredentials *googleCredential = [RLMCredentials credentialsWithGoogleIdToken:@"id token"];
    XCTAssertEqualObjects(googleCredential.provider, @"oauth2-google");
}

- (void)testAppleCredential {
    RLMCredentials *appleCredential = [RLMCredentials credentialsWithAppleToken:@"apple token"];
    XCTAssertEqualObjects(appleCredential.provider, @"oauth2-apple");
}

- (void)testFunctionCredential {
    NSError *error;
    RLMCredentials *functionCredential = [RLMCredentials credentialsWithFunctionPayload:@{@"dog": @{@"name": @"fido"}}];
    XCTAssertEqualObjects(functionCredential.provider, @"custom-function");
    XCTAssertEqualObjects(error, nil);
}

#pragma mark - Username Password

/// Valid email/password credentials should be able to log in a user. Using the same credentials should return the
/// same user object.
- (void)testEmailPasswordAuthentication {
    RLMUser *firstUser = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                             register:YES]];
    RLMUser *secondUser = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                              register:NO]];
    // Two users created with the same credential should resolve to the same actual user.
    XCTAssertTrue([firstUser.identifier isEqualToString:secondUser.identifier]);
}

/// An invalid email/password credential should not be able to log in a user and a corresponding error should be generated.
- (void)testInvalidPasswordAuthentication {
    (void)[self userForTest:_cmd];

    RLMCredentials *credentials = [RLMCredentials credentialsWithEmail:NSStringFromSelector(_cmd)
                                                              password:@"INVALID_PASSWORD"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"login should fail"];

    [self.app loginWithCredential:credentials completion:^(RLMUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// A non-existsing user should not be able to log in and a corresponding error should be generated.
- (void)testNonExistingEmailAuthentication {
    RLMCredentials *credentials = [RLMCredentials credentialsWithEmail:@"INVALID_USERNAME"
                                                              password:@"INVALID_PASSWORD"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"login should fail"];

    [self.app loginWithCredential:credentials completion:^(RLMUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// Registering a user with existing email should return corresponding error.
- (void)testExistingEmailRegistration {
    XCTestExpectation *expectationA = [self expectationWithDescription:@"registration should succeed"];
    [[self.app emailPasswordAuth] registerUserWithEmail:NSStringFromSelector(_cmd)
                                               password:@"password"
                                             completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTestExpectation *expectationB = [self expectationWithDescription:@"registration should fail"];
    [[self.app emailPasswordAuth] registerUserWithEmail:NSStringFromSelector(_cmd)
                                               password:@"password"
                                             completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [expectationB fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// Errors reported in RLMSyncManager.errorHandler shouldn't contain sync error domain errors as underlying error

- (void)testSyncErrorHandlerErrorDomain {
    RLMUser *user = [self userForTest:_cmd];
    XCTAssertNotNil(user);

    XCTestExpectation *expectation = [self expectationWithDescription:@"should fail after setting bad token"];
    [self.app syncManager].errorHandler = ^(__unused NSError *error, __unused RLMSyncSession *session) {
        XCTAssertTrue([error.domain isEqualToString:RLMSyncErrorDomain]);
        XCTAssertFalse([[error.userInfo[kRLMSyncUnderlyingErrorKey] domain] isEqualToString:RLMSyncErrorDomain]);
        [expectation fulfill];
    };

    [self manuallySetAccessTokenForUser:user value:[self badAccessToken]];
    [self manuallySetRefreshTokenForUser:user value:[self badAccessToken]];

    [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Basic Sync

/// It should be possible to successfully open a Realm configured for sync with a normal user.
- (void)testOpenRealmWithNormalCredentials {
    RLMUser *user = [self userForTest:_cmd];
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
    XCTAssertTrue(realm.isEmpty);
}

- (void)testOpenRealmWithNilPartitionValue {
    RLMUser *user = [self userForTest:_cmd];
    RLMRealm *realm = [self openRealmForPartitionValue:nil user:user];
    XCTAssertTrue(realm.isEmpty);
}

/// If client B adds objects to a synced Realm, client A should see those objects.
- (void)testAddObjects {
    RLMUser *user = [self userForTest:_cmd];
    NSString *realmId = NSStringFromSelector(_cmd);
    RLMRealm *realm = [self openRealmForPartitionValue:realmId user:user];
    if (self.isParent) {
        CHECK_COUNT(0, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);
    } else {
        // Add objects.
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);
    }
}

- (void)testAddObjectsWithNilPartitionValue {
    RLMRealm *realm = [self openRealmForPartitionValue:nil user:self.anonymousUser];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);

        // Other tests expect the nil partition to be empty so we need to clean up
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
        }];
        [self waitForUploadsForRealm:realm];
    } else {
        // Add objects.
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);
    }
}

/// If client B adds objects to a synced Realm, client A should see those objects.
- (void)testAddObjectsMultipleApps {
    NSString *appId1;
    NSString *appId2;
    if (self.isParent) {
        appId1 = [RealmServer.shared createAppAndReturnError:nil];
        appId2 = [RealmServer.shared createAppAndReturnError:nil];

    } else {
        appId1 = self.appIds[0];
        appId2 = self.appIds[1];
    }

    RLMApp *app1 = [RLMApp appWithId:appId1
                       configuration:[self defaultAppConfiguration]
                       rootDirectory:[self clientDataRoot]];
    RLMApp *app2 = [RLMApp appWithId:appId2
                       configuration:[self defaultAppConfiguration]
                       rootDirectory:[self clientDataRoot]];

    [self logInUserForCredentials:[RLMCredentials anonymousCredentials] app:app1];
    [self logInUserForCredentials:[RLMCredentials anonymousCredentials] app:app2];
    RLMRealm *realm1 = [self openRealmForPartitionValue:appId1 user:app1.currentUser];
    RLMRealm *realm2 = [self openRealmForPartitionValue:appId2 user:app2.currentUser];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realm1);
        CHECK_COUNT(0, Person, realm2);
        int code = [self runChildAndWaitWithAppIds:@[appId1, appId2]];
        XCTAssertEqual(0, code);
        [self waitForDownloadsForRealm:realm1];
        [self waitForDownloadsForRealm:realm2];
        CHECK_COUNT(2, Person, realm1);
        CHECK_COUNT(2, Person, realm2);
        XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'John'"].count, 1UL);
        XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'Paul'"].count, 1UL);
        XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'Ringo'"].count, 0UL);
        XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'George'"].count, 0UL);

        XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'John'"].count, 0UL);
        XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'Paul'"].count, 0UL);
        XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'Ringo'"].count, 1UL);
        XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'George'"].count, 1UL);
    } else {
        // Add objects.
        [self addPersonsToRealm:realm1
                        persons:@[[Person john],
                                  [Person paul]]];
        [self addPersonsToRealm:realm2
                        persons:@[[Person ringo],
                                  [Person george]]];

        [self waitForUploadsForRealm:realm1];
        [self waitForUploadsForRealm:realm2];
        CHECK_COUNT(2, Person, realm1);
        CHECK_COUNT(2, Person, realm2);
    }
}

/// If client B adds objects to a synced Realm, client A should see those objects.
- (void)testSessionRefresh {
    RLMUser *user = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd) register:self.isParent]];
    RLMUser *user2 = [self logInUserForCredentials:[self basicCredentialsWithName:@"lmao@10gen.com" register:self.isParent]];

    [user _syncUser]->update_access_token(self.badAccessToken.UTF8String);

    NSString *realmId = NSStringFromSelector(_cmd);
    RLMRealm *realm = [self openRealmForPartitionValue:realmId user:user];
    RLMRealm *realm2 = [self openRealmForPartitionValue:realmId user:user2];
    if (self.isParent) {
        CHECK_COUNT(0, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realm]
                      partitionValues:@[realmId] expectedCounts:@[@4]];
        [self waitForDownloadsForUser:user2
                               realms:@[realm2]
                      partitionValues:@[realmId] expectedCounts:@[@4]];
    } else {
        // Add objects.
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george]]];
        [self waitForUploadsForRealm:realm];
    }
}

/// If client B deletes objects from a synced Realm, client A should see the effects of that deletion.
- (void)testDeleteObjects {
    RLMUser *user = [self userForTest:_cmd];
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
    if (self.isParent) {
        // Add objects.
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(0, Person, realm);
    } else {
        CHECK_COUNT(1, Person, realm);
        [realm beginWriteTransaction];
        [realm deleteAllObjects];
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(0, Person, realm);
    }
}

#pragma mark - Encryption -

/// If client B encrypts its synced Realm, client A should be able to access that Realm with a different encryption key.
- (void)testEncryptedSyncedRealm {
    RLMUser *user = [self userForTest:_cmd];

    NSData *key = RLMGenerateKey();
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd)
                                                  user:user
                                         encryptionKey:key
                                            stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realm]
                      partitionValues:@[NSStringFromSelector(_cmd)]
                       expectedCounts:@[@1]];
    } else {
        // Add objects.
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    }
}

/// If an encrypted synced Realm is re-opened with the wrong key, throw an exception.
- (void)testEncryptedSyncedRealmWrongKey {
    RLMUser *user = [self userForTest:_cmd];

    if (self.isParent) {
        NSString *path;
        @autoreleasepool {
            RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd)
                                                          user:user
                                                 encryptionKey:RLMGenerateKey()
                                                    stopPolicy:RLMSyncStopPolicyImmediately];
            path = realm.configuration.pathOnDisk;
            CHECK_COUNT(0, Person, realm);
            RLMRunChildAndWait();
            [self waitForDownloadsForUser:user
                                   realms:@[realm]
                          partitionValues:@[NSStringFromSelector(_cmd)]
                           expectedCounts:@[@1]];
        }

        RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
        c.fileURL = [NSURL fileURLWithPath:path];
        RLMAssertThrowsWithError([RLMRealm realmWithConfiguration:c error:nil],
                                 @"Unable to open a realm at path",
                                 RLMErrorFileAccess,
                                 @"Realm file initial open failed");
        c.encryptionKey = RLMGenerateKey();
        RLMAssertThrowsWithError([RLMRealm realmWithConfiguration:c error:nil],
                                 @"Unable to open a realm at path",
                                 RLMErrorFileAccess,
                                 @"Realm file decryption failed");
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd)
                                                      user:user
                                             encryptionKey:RLMGenerateKey()
                                                stopPolicy:RLMSyncStopPolicyImmediately];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    }
}

#pragma mark - Multiple Realm Sync

/// If a client opens multiple Realms, there should be one session object for each Realm that was opened.
- (void)testMultipleRealmsSessions {
    NSString *partitionValueA = NSStringFromSelector(_cmd);
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    RLMUser *user = [self userForTest:_cmd];

    // Open three Realms.

    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmA = [self openRealmForPartitionValue:partitionValueA
                                                                                              user:user];
    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmB = [self openRealmForPartitionValue:partitionValueB
                                                                                              user:user];
    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmC = [self openRealmForPartitionValue:partitionValueC
                                                                                              user:user];
    // Make sure there are three active sessions for the user.
    XCTAssert(user.allSessions.count == 3, @"Expected 3 sessions, but didn't get 3 sessions");
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueA],
                    @"Expected to get a session for partition value A");
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueB],
                    @"Expected to get a session for partition value B");
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueC],
                    @"Expected to get a session for partition value C");
    XCTAssertTrue([user sessionForPartitionValue:partitionValueA].state == RLMSyncSessionStateActive,
                  @"Expected active session for URL A");
    XCTAssertTrue([user sessionForPartitionValue:partitionValueB].state == RLMSyncSessionStateActive,
                  @"Expected active session for URL B");
    XCTAssertTrue([user sessionForPartitionValue:partitionValueC].state == RLMSyncSessionStateActive,
                  @"Expected active session for URL C");
}

/// A client should be able to open multiple Realms and add objects to each of them.
- (void)testMultipleRealmsAddObjects {
    NSString *partitionValueA = NSStringFromSelector(_cmd);
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    RLMUser *user = [self userForTest:_cmd];

    RLMRealm *realmA = [self openRealmForPartitionValue:partitionValueA user:user];
    RLMRealm *realmB = [self openRealmForPartitionValue:partitionValueB user:user];
    RLMRealm *realmC = [self openRealmForPartitionValue:partitionValueC user:user];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);
        CHECK_COUNT(0, Person, realmC);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realmA, realmB, realmC]
                      partitionValues:@[partitionValueA,
                                        partitionValueB,
                                        partitionValueC]
                       expectedCounts:@[@3, @2, @5]];

        RLMResults *resultsA = [Person objectsInRealm:realmA where:@"firstName == %@", @"Ringo"];
        RLMResults *resultsB = [Person objectsInRealm:realmB where:@"firstName == %@", @"Ringo"];

        XCTAssertEqual([resultsA count], 1UL);
        XCTAssertEqual([resultsB count], 0UL);
    } else {
        // Add objects.
        [self addPersonsToRealm:realmA
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo]]];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john],
                                  [Person paul]]];
        [self addPersonsToRealm:realmC
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george],
                                  [Person ringo]]];
        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(3, Person, realmA);
        CHECK_COUNT(2, Person, realmB);
        CHECK_COUNT(5, Person, realmC);
    }
}

/// A client should be able to open multiple Realms and delete objects from each of them.
- (void)testMultipleRealmsDeleteObjects {
    NSString *partitionValueA = NSStringFromSelector(_cmd);
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    RLMUser *user = [self userForTest:_cmd];
    RLMRealm *realmA = [self openRealmForPartitionValue:partitionValueA user:user];
    RLMRealm *realmB = [self openRealmForPartitionValue:partitionValueB user:user];
    RLMRealm *realmC = [self openRealmForPartitionValue:partitionValueC user:user];

    if (self.isParent) {
        [self addPersonsToRealm:realmA
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george]]];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george],
                                  [Person george]]];
        [self addPersonsToRealm:realmC
                        persons:@[[Person john],
                                  [Person paul]]];

        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(4, Person, realmA);
        CHECK_COUNT(5, Person, realmB);
        CHECK_COUNT(2, Person, realmC);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realmA, realmB, realmC]
                      partitionValues:@[partitionValueA,
                                        partitionValueB,
                                        partitionValueC]
                       expectedCounts:@[@0, @0, @0]];
    } else {
        // Delete all the objects from the Realms.
        CHECK_COUNT(4, Person, realmA);
        CHECK_COUNT(5, Person, realmB);
        CHECK_COUNT(2, Person, realmC);
        [realmA beginWriteTransaction];
        [realmA deleteAllObjects];
        [realmA commitWriteTransaction];
        [realmB beginWriteTransaction];
        [realmB deleteAllObjects];
        [realmB commitWriteTransaction];
        [realmC beginWriteTransaction];
        [realmC deleteAllObjects];
        [realmC commitWriteTransaction];
        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);
        CHECK_COUNT(0, Person, realmC);
    }
}

#pragma mark - Session Lifetime
/// When a session opened by a Realm goes out of scope, it should stay alive long enough to finish any waiting uploads.
- (void)testUploadChangesWhenRealmOutOfScope {
    const NSInteger OBJECT_COUNT = 3;
    RLMUser *user = [self userForTest:_cmd];

    if (self.isParent) {
        // Open the Realm in an autorelease pool so that it is destroyed as soon as possible.
        @autoreleasepool {
            RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
            [self addPersonsToRealm:realm
                            persons:@[[Person john],
                                      [Person paul],
                                      [Person ringo]]];
            CHECK_COUNT(OBJECT_COUNT, Person, realm);
        }

        // We have to use a sleep here because explicitly waiting for uploads
        // would retain the session, defeating the purpose of this test
        sleep(2);

        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        CHECK_COUNT(OBJECT_COUNT, Person, realm);
    }
}

#pragma mark - Logging Back In

/// A Realm that was opened before a user logged out should be able to resume uploading if the user logs back in.
- (void)testLogBackInSameRealmUpload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];

    if (self.isParent) {
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);
        [self waitForUploadsForRealm:realm];
        // Log out the user out and back in
        [self logOutUser:user];
        user = [self logInUserForCredentials:credentials];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);

        // Verify that the post-login objects were actually synced
        RLMRunChildAndWait();
    } else {
        CHECK_COUNT(4, Person, realm);
    }
}

/// A Realm that was opened before a user logged out should be able to resume downloading if the user logs back in.
- (void)testLogBackInSameRealmDownload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];

    if (self.isParent) {
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);
        [self waitForUploadsForRealm:realm];
        // Log out the user.
        [self logOutUser:user];
        // Log the user back in.
        user = [self logInUserForCredentials:credentials];

        RLMRunChildAndWait();

        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    } else {
        [self addPersonsToRealm:realm persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    }
}

/// A Realm that was opened while a user was logged out should be able to start uploading if the user logs back in.
- (void)testLogBackInDeferredRealmUpload {
    NSString *partitionValue = NSStringFromSelector(_cmd);
    RLMCredentials *credentials = [self basicCredentialsWithName:partitionValue
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        [self logOutUser:user];

        // Open a Realm after the user's been logged out.
        RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:partitionValue user:user];

        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);

        user = [self logInUserForCredentials:credentials];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);

        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:partitionValue user:user];
        CHECK_COUNT(4, Person, realm);
    }
}

/// A Realm that was opened while a user was logged out should be able to start downloading if the user logs back in.
- (void)testLogBackInDeferredRealmDownload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        [self logOutUser:user];
        RLMRunChildAndWait();

        // Open a Realm after the user's been logged out.
        RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);

        user = [self logInUserForCredentials:credentials];
        [self waitForDownloadsForUser:user
                               realms:@[realm]
                      partitionValues:@[NSStringFromSelector(_cmd)] expectedCounts:@[@4]];

    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        [self waitForUploadsForRealm:realm];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    }
}

/// After logging back in, a Realm whose path has been opened for the first time should properly upload changes.
- (void)testLogBackInOpenFirstTimePathUpload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];
    if (self.isParent) {
        [self logOutUser:user];
        user = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                   register:NO]];
        RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul]]];

        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(2, Person, realm);
        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        CHECK_COUNT(2, Person, realm);
    }
}

/// After logging back in, a Realm whose path has been opened for the first time should properly download changes.
- (void)testLogBackInOpenFirstTimePathDownload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        [self logOutUser:user];
        user = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                   register:NO]];
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        RLMRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(2, Person, realm);
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(2, Person, realm);
    }
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly upload changes for a new
/// `RLMRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmUpload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        @autoreleasepool {
            RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
            [self addPersonsToRealm:realm persons:@[[Person john]]];
            [self waitForUploadsForRealm:realm];
            CHECK_COUNT(1, Person, realm);
            [self logOutUser:user];
            user = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                       register:NO]];
        }

        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person george],
                                  [Person ringo]]];
        CHECK_COUNT(5, Person, realm);
        [self waitForUploadsForRealm:realm];

        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        CHECK_COUNT(5, Person, realm);
    }
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly download changes for a new
/// `RLMRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmDownload {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        XCTAssert([Person allObjectsInRealm:realm].count == 1, @"Expected 1 item");
        [self logOutUser:user];
        user = [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                   register:NO]];
        RLMRunChildAndWait();
        // Open the Realm again and get the items.
        realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self waitForDownloadsForUser:user
                               realms:@[realm]
                      partitionValues:@[NSStringFromSelector(_cmd)] expectedCounts:@[@5]];
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        CHECK_COUNT(1, Person, realm);
        [self addPersonsToRealm:realm
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person george],
                                  [Person ringo]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(5, Person, realm);
    }
}

#pragma mark - Session suspend and resume

- (void)testSuspendAndResume {
    RLMUser *user = [self userForTest:_cmd];

    __attribute__((objc_precise_lifetime))
    RLMRealm *realmA = [self openRealmForPartitionValue:@"suspend and resume 1" user:user];
    __attribute__((objc_precise_lifetime))
    RLMRealm *realmB = [self openRealmForPartitionValue:@"suspend and resume 2" user:user];
    if (self.isParent) {
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);

        // Suspend the session for realm A and then add an object to each Realm
        RLMSyncSession *sessionA = [RLMSyncSession sessionForRealm:realmA];
        RLMSyncSession *sessionB = [RLMSyncSession sessionForRealm:realmB];
        XCTAssertEqual(sessionB.state, RLMSyncSessionStateActive);
        [sessionA suspend];
        XCTAssertEqual(realmB.syncSession.state, RLMSyncSessionStateActive);

        [self addPersonsToRealm:realmA persons:@[[Person john]]];
        [self addPersonsToRealm:realmB persons:@[[Person ringo]]];
        [self waitForUploadsForRealm:realmB];
        RLMRunChildAndWait();

        // A should still be 1 since it's suspended. If it wasn't suspended, it
        // should have downloaded before B due to the ordering in the child.
        [self waitForDownloadsForRealm:realmB];
        CHECK_COUNT(1, Person, realmA);
        CHECK_COUNT(3, Person, realmB);

        // A should see the other two from the child after resuming
        [sessionA resume];
        [self waitForDownloadsForRealm:realmA];
        CHECK_COUNT(3, Person, realmA);
    } else {
        // Child shouldn't see the object in A
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(1, Person, realmB);
        [self addPersonsToRealm:realmA
                        persons:@[[Person john],
                                  [Person paul]]];
        [self waitForUploadsForRealm:realmA];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john],
                                  [Person paul]]];
        [self waitForUploadsForRealm:realmB];
        CHECK_COUNT(2, Person, realmA);
        CHECK_COUNT(3, Person, realmB);
    }
}

#pragma mark - Client reset

/// Ensure that a client reset error is propagated up to the binding successfully.
- (void)testClientReset {
    RLMUser *user = [self userForTest:_cmd];
    // Open the Realm
    __attribute__((objc_precise_lifetime)) RLMRealm *realm = [self openRealmForPartitionValue:@"realm_id" user:user];

    __block NSError *theError = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
    [self.app syncManager].errorHandler = ^void(NSError *error, RLMSyncSession *) {
        theError = error;
        [ex fulfill];
    };
    [user simulateClientResetErrorForSession:@"realm_id"];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertNotNil(theError);
    XCTAssertTrue(theError.code == RLMSyncErrorClientResetError);
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertNotNil(pathValue);
    // Sanity check the recovery path.
    NSString *recoveryPath = [NSString stringWithFormat:@"mongodb-realm/%@/recovered-realms", self.appId];
    XCTAssertTrue([pathValue rangeOfString:recoveryPath].location != NSNotFound);
    XCTAssertNotNil([theError rlmSync_errorActionToken]);
}

/// Test manually initiating client reset.
- (void)testClientResetManualInitiation {
    RLMUser *user = [self userForTest:_cmd];
    NSString *partitionValue = NSStringFromSelector(_cmd);

    __block NSError *theError = nil;
    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) RLMRealm *realm = [self openRealmForPartitionValue:partitionValue user:user];
        XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
        self.app.syncManager.errorHandler = ^(NSError *error, RLMSyncSession *) {
            theError = error;
            [ex fulfill];
        };
        [user simulateClientResetErrorForSession:partitionValue];
        [self waitForExpectationsWithTimeout:10 handler:nil];
        XCTAssertNotNil(theError);
    }
    // At this point the Realm should be invalidated and client reset should be possible.
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:pathValue]);
    [RLMSyncSession immediatelyHandleError:theError.rlmSync_errorActionToken syncManager:self.app.syncManager];
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:pathValue]);
}

#pragma mark - Progress Notifications

static const NSInteger NUMBER_OF_BIG_OBJECTS = 2;

- (void)populateDataForUser:(RLMUser *)user partitionValue:(NSString *)partitionValue {
    RLMRealm *realm = [self openRealmForPartitionValue:partitionValue user:user];
    CHECK_COUNT(0, HugeSyncObject, realm);
    [realm beginWriteTransaction];
    for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
        [realm addObject:[HugeSyncObject objectWithRealmId:partitionValue]];
    }
    [realm commitWriteTransaction];
    [self waitForUploadsForRealm:realm];
    CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
}

- (void)testStreamingDownloadNotifier {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (!self.isParent) {
        [self populateDataForUser:user partitionValue:NSStringFromSelector(_cmd)];
        return;
    }

    __block NSInteger callCount = 0;
    __block NSUInteger transferred = 0;
    __block NSUInteger transferrable = 0;
    __block BOOL hasBeenFulfilled = NO;
    // Register a notifier.
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
    RLMSyncSession *session = realm.syncSession;
    XCTAssertNotNil(session);
    XCTestExpectation *ex = [self expectationWithDescription:@"streaming-download-notifier"];
    id token = [session addProgressNotificationForDirection:RLMSyncProgressDirectionDownload
                                                       mode:RLMSyncProgressModeReportIndefinitely
                                                      block:^(NSUInteger xfr, NSUInteger xfb) {
        // Make sure the values are increasing, and update our stored copies.
        XCTAssertGreaterThanOrEqual(xfr, transferred);
        XCTAssertGreaterThanOrEqual(xfb, transferrable);
        transferred = xfr;
        transferrable = xfb;
        callCount++;
        if (transferrable > 0 && transferred >= transferrable && !hasBeenFulfilled) {
            [ex fulfill];
            hasBeenFulfilled = YES;
        }
    }];
    // Wait for the child process to upload everything.
    RLMRunChildAndWait();
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    [token invalidate];
    // The notifier should have been called at least twice: once at the beginning and at least once
    // to report progress.
    XCTAssertGreaterThan(callCount, 1);
    XCTAssertGreaterThanOrEqual(transferred, transferrable);
}

- (void)testStreamingUploadNotifier {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];
    __block NSInteger callCount = 0;
    __block NSUInteger transferred = 0;
    __block NSUInteger transferrable = 0;
    // Open the Realm
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];

    // Register a notifier.
    RLMSyncSession *session = realm.syncSession;
    XCTAssertNotNil(session);
    XCTestExpectation *ex = [self expectationWithDescription:@"streaming-upload-expectation"];
    auto token = [session addProgressNotificationForDirection:RLMSyncProgressDirectionUpload
                                                         mode:RLMSyncProgressModeReportIndefinitely
                                                        block:^(NSUInteger xfr, NSUInteger xfb) {
        // Make sure the values are increasing, and update our stored copies.
        XCTAssertGreaterThanOrEqual(xfr, transferred);
        XCTAssertGreaterThanOrEqual(xfb, transferrable);
        transferred = xfr;
        transferrable = xfb;
        callCount++;
        if (transferred > 0 && transferred >= transferrable && transferrable > 1000000 * NUMBER_OF_BIG_OBJECTS) {
            [ex fulfill];
        }
    }];
    // Upload lots of data
    [realm beginWriteTransaction];
    for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
        [realm addObject:[HugeSyncObject objectWithRealmId:NSStringFromSelector(_cmd)]];
    }
    [realm commitWriteTransaction];
    // Wait for upload to begin and finish
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    [token invalidate];
    // The notifier should have been called at least twice: once at the beginning and at least once
    // to report progress.
    XCTAssertGreaterThan(callCount, 1);
    XCTAssertGreaterThanOrEqual(transferred, transferrable);
}

#pragma mark - Download Realm

- (void)testDownloadRealm {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    RLMUser *user = [self userForTest:_cmd];

    if (!self.isParent) {
        [self populateDataForUser:user partitionValue:NSStringFromSelector(_cmd)];
        return;
    }

    // Wait for the child process to upload everything.
    RLMRunChildAndWait();

    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    RLMRealmConfiguration *c = [user configurationWithTestSelector:_cmd];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);

    [RLMRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNil(error);
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
        [ex fulfill];
    }];
    NSUInteger (^fileSize)(NSString *) = ^NSUInteger(NSString *path) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        if (attributes)
            return [(NSNumber *)attributes[NSFileSize] unsignedLongLongValue];

        return 0;
    };
    XCTAssertNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertGreaterThan(fileSize(c.pathOnDisk), 0U);
    XCTAssertNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
}

- (void)testDownloadAlreadyOpenRealm {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    RLMUser *user = [self userForTest:_cmd];

    if (!self.isParent) {
        [self populateDataForUser:user partitionValue:NSStringFromSelector(_cmd)];
        return;
    }

    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    RLMRealmConfiguration *c = [user configurationWithTestSelector:_cmd];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);
    RLMRealm *realm = [RLMRealm realmWithConfiguration:c error:nil];
    CHECK_COUNT(0, HugeSyncObject, realm);
    [self waitForUploadsForRealm:realm];
    [realm.syncSession suspend];

    // Wait for the child process to upload everything.
    RLMRunChildAndWait();

    auto fileSize = ^NSUInteger(NSString *path) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        return [(NSNumber *)attributes[NSFileSize] unsignedLongLongValue];
    };
    NSUInteger sizeBefore = fileSize(c.pathOnDisk);
    XCTAssertGreaterThan(sizeBefore, 0U);
    XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));

    [RLMRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNil(error);
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
        [ex fulfill];
    }];
    [realm.syncSession resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertGreaterThan(fileSize(c.pathOnDisk), sizeBefore);
    XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
}

- (void)testDownloadCancelsOnAuthError {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];
    [self manuallySetAccessTokenForUser:user value:[self badAccessToken]];
    [self manuallySetRefreshTokenForUser:user value:[self badAccessToken]];
    auto ex = [self expectationWithDescription:@"async open"];
    auto c = [user configurationWithTestSelector:_cmd];
    [RLMRealm asyncOpenWithConfiguration:c callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNil(realm);
        XCTAssertNotNil(error);
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testCancelDownload {
    RLMUser *user = [self userForTest:_cmd];

    if (!self.isParent) {
        [self populateDataForUser:user partitionValue:NSStringFromSelector(_cmd)];
        return;
    }

    // Wait for the child process to upload everything.
    RLMRunChildAndWait();

    // Use a serial queue for asyncOpen to ensure that the first one adds
    // the completion block before the second one cancels it
    RLMSetAsyncOpenQueue(dispatch_queue_create("io.realm.asyncOpen", 0));

    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    RLMRealmConfiguration *c = [user configurationWithTestSelector:_cmd];
    [RLMRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNil(realm);
        XCTAssertNotNil(error);
        [ex fulfill];
    }];
    [[RLMRealm asyncOpenWithConfiguration:c
                            callbackQueue:dispatch_get_main_queue()
                                 callback:^(RLMRealm *, NSError *) {
        XCTFail(@"Cancelled callback got called");
    }] cancel];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testAsyncOpenProgressNotifications {
    RLMCredentials *credentials = [self basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                        register:self.isParent];
    RLMUser *user = [self logInUserForCredentials:credentials];

    if (!self.isParent) {
        [self populateDataForUser:user partitionValue:NSStringFromSelector(_cmd)];
        return;
    }

    RLMRunChildAndWait();

    XCTestExpectation *ex1 = [self expectationWithDescription:@"async open"];
    XCTestExpectation *ex2 = [self expectationWithDescription:@"download progress complete"];
    RLMRealmConfiguration *c = [user configurationWithTestSelector:_cmd];

    auto task = [RLMRealm asyncOpenWithConfiguration:c
                                       callbackQueue:dispatch_get_main_queue()
                                            callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(realm);
        [ex1 fulfill];
    }];
    [task addProgressNotificationBlock:^(NSUInteger transferredBytes, NSUInteger transferrableBytes) {
        if (transferrableBytes > 0 && transferredBytes == transferrableBytes) {
            [ex2 fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testAsyncOpenConnectionTimeout {
    TimeoutProxyServer *proxy = [[TimeoutProxyServer alloc] initWithPort:5678 targetPort:9090];
    NSError *error;
    [proxy startAndReturnError:&error];
    XCTAssertNil(error);

    RLMAppConfiguration *config = [[RLMAppConfiguration alloc] initWithBaseURL:@"http://localhost:9090"
                                                                     transport:[AsyncOpenConnectionTimeoutTransport new]
                                                                  localAppName:nil
                                                               localAppVersion:nil
                                                       defaultRequestTimeoutMS:60];
    NSString *appId = [RealmServer.shared createAppAndReturnError:nil];
    RLMApp *app = [RLMApp appWithId:appId configuration:config];
    RLMUser *user = [self logInUserForCredentials:[RLMCredentials anonymousCredentials] app:app];

    RLMRealmConfiguration *c = [user configurationWithPartitionValue:NSStringFromSelector(_cmd)];
    c.objectClasses = @[Person.class];
    RLMSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.cancelAsyncOpenOnNonFatalErrors = true;
    c.syncConfiguration = syncConfig;

    RLMSyncTimeoutOptions *timeoutOptions = [RLMSyncTimeoutOptions new];
    timeoutOptions.connectTimeout = 1000.0;
    app.syncManager.timeoutOptions = timeoutOptions;

    // Set delay above the timeout so it should fail
    proxy.delay = 2.0;

    XCTestExpectation *ex = [self expectationWithDescription:@"async open"];
    [RLMRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, ETIMEDOUT);
        XCTAssertEqual(error.domain, NSPOSIXErrorDomain);
        XCTAssertNil(realm);
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Delay below the timeout should work
    proxy.delay = 0.5;

    ex = [self expectationWithDescription:@"async open"];
    [RLMRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(RLMRealm *realm, NSError *error) {
        XCTAssertNotNil(realm);
        XCTAssertNil(error);
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [proxy stop];
}

#pragma mark - Compact on Launch

- (void)testCompactOnLaunch {
    RLMUser *user = [self userForTest:_cmd];
    NSString *partitionValue = NSStringFromSelector(_cmd);
    NSString *path;
    // Create a large object and then delete it in the next transaction so that
    // the file is bloated
    @autoreleasepool {
        RLMRealm *realm = [self immediatelyOpenRealmForPartitionValue:NSStringFromSelector(_cmd)
                                                                 user:user
                                                        encryptionKey:nil
                                                           stopPolicy:RLMSyncStopPolicyImmediately];
        [realm beginWriteTransaction];
        [realm addObject:[HugeSyncObject objectWithRealmId:partitionValue]];
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];

        [realm beginWriteTransaction];
        [realm deleteAllObjects];
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];
        [self waitForDownloadsForRealm:realm];
        [realm.syncSession suspend];

        path = realm.configuration.pathOnDisk;
    }

    auto fileManager = NSFileManager.defaultManager;
    auto initialSize = [[fileManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];

    // Reopen the file with a shouldCompactOnLaunch block and verify that it is
    // actually compacted
    auto config = [user configurationWithTestSelector:_cmd];
    __block bool blockCalled = false;
    __block NSUInteger usedSize = 0;
    config.shouldCompactOnLaunch = ^(NSUInteger, NSUInteger used) {
        usedSize = used;
        blockCalled = true;
        return YES;
    };

    @autoreleasepool {
        [RLMRealm realmWithConfiguration:config error:nil];
    }
    XCTAssertTrue(blockCalled);

    auto finalSize = [[fileManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    XCTAssertLessThan(finalSize, initialSize);
    XCTAssertLessThanOrEqual(finalSize, usedSize + realm::util::page_size());
}

#pragma mark - Read Only

- (void)testOpenSynchronouslyInReadOnlyBeforeRemoteSchemaIsInitialized {
    RLMUser *user = [self userForTest:_cmd];

    if (self.isParent) {
        RLMRealmConfiguration *config = [user configurationWithTestSelector:_cmd];
        config.readOnly = true;
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
        CHECK_COUNT(0, Person, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    } else {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    }
}

- (void)testAddPropertyToReadOnlyRealmWithExistingLocalCopy {
    RLMUser *user = [self userForTest:_cmd];

    if (!self.isParent) {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        return;
    }
    RLMRunChildAndWait();

    RLMRealmConfiguration *config = [user configurationWithTestSelector:_cmd];
    config.readOnly = true;
    @autoreleasepool {
        RLMRealm *realm = [self asyncOpenRealmWithConfiguration:config];
        CHECK_COUNT(1, Person, realm);
    }

    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:Person.class];
    objectSchema.properties = [RLMObjectSchema schemaForObjectClass:HugeSyncObject.class].properties;
    config.customSchema = [[RLMSchema alloc] init];
    config.customSchema.objectSchema = @[objectSchema];

    RLMAssertThrowsWithReason([RLMRealm realmWithConfiguration:config error:nil],
                              @"Property 'Person.dataProp' has been added.");

    @autoreleasepool {
        NSError *error = [self asyncOpenErrorWithConfiguration:config];
        XCTAssertNotEqual([error.localizedDescription rangeOfString:@"Property 'Person.dataProp' has been added."].location,
                          NSNotFound);
    }
}

- (void)testAddPropertyToReadOnlyRealmWithAsyncOpen {
    RLMUser *user = [self userForTest:_cmd];

    if (!self.isParent) {
        RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        return;
    }
    RLMRunChildAndWait();

    RLMRealmConfiguration *config = [user configurationWithTestSelector:_cmd];
    config.readOnly = true;

    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:Person.class];
    objectSchema.properties = [RLMObjectSchema schemaForObjectClass:HugeSyncObject.class].properties;
    config.customSchema = [[RLMSchema alloc] init];
    config.customSchema.objectSchema = @[objectSchema];

    @autoreleasepool {
        NSError *error = [self asyncOpenErrorWithConfiguration:config];
        XCTAssertNotEqual([error.localizedDescription rangeOfString:@"Property 'Person.dataProp' has been added."].location,
                          NSNotFound);
    }
}

- (void)testSyncConfigShouldNotMigrate {
    RLMUser *user = [self userForTest:_cmd];
    RLMRealm *realm = [self openRealmForPartitionValue:NSStringFromSelector(_cmd) user:user];

    RLMAssertThrowsWithReason([realm.configuration setDeleteRealmIfMigrationNeeded:YES],
                              @"Cannot set 'deleteRealmIfMigrationNeeded' when sync is enabled");

    RLMRealmConfiguration *localRealmConfiguration = [RLMRealmConfiguration defaultConfiguration];
    XCTAssertNoThrow([localRealmConfiguration setDeleteRealmIfMigrationNeeded:YES]);
}
@end

#pragma mark - Mongo Client

@interface RLMMongoClientTests : RLMSyncTestCase
@end

@implementation RLMMongoClientTests
- (void)tearDown {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];
    [self cleanupRemoteDocuments:collection];
    [super tearDown];
}

- (void)testFindOneAndModifyOptions {
    NSDictionary<NSString *, id<RLMBSON>> *projection = @{@"name": @1, @"breed": @1};
    NSDictionary<NSString *, id<RLMBSON>> *sort = @{@"age" : @1, @"coat" : @1};

    RLMFindOneAndModifyOptions *findOneAndModifyOptions1 = [[RLMFindOneAndModifyOptions alloc] init];
    XCTAssertNil(findOneAndModifyOptions1.projection);
    XCTAssertNil(findOneAndModifyOptions1.sort);
    XCTAssertFalse(findOneAndModifyOptions1.shouldReturnNewDocument);
    XCTAssertFalse(findOneAndModifyOptions1.upsert);

    RLMFindOneAndModifyOptions *findOneAndModifyOptions2 = [[RLMFindOneAndModifyOptions alloc] init];
    findOneAndModifyOptions2.projection = projection;
    findOneAndModifyOptions2.sort = sort;
    XCTAssertNotNil(findOneAndModifyOptions2.projection);
    XCTAssertNotNil(findOneAndModifyOptions2.sort);
    findOneAndModifyOptions2.shouldReturnNewDocument = YES;
    findOneAndModifyOptions2.upsert = YES;
    XCTAssertTrue(findOneAndModifyOptions2.shouldReturnNewDocument);
    XCTAssertTrue(findOneAndModifyOptions2.upsert);

    XCTAssertFalse([findOneAndModifyOptions2.projection isEqual:@{}]);
    XCTAssertTrue([findOneAndModifyOptions2.projection isEqual:projection]);
    XCTAssertFalse([findOneAndModifyOptions2.sort isEqual:@{}]);
    XCTAssertTrue([findOneAndModifyOptions2.sort isEqual:sort]);

    RLMFindOneAndModifyOptions *findOneAndModifyOptions3 = [[RLMFindOneAndModifyOptions alloc]
                                                            initWithProjection:projection
                                                            sort:sort
                                                            upsert:YES
                                                            shouldReturnNewDocument:YES];

    XCTAssertNotNil(findOneAndModifyOptions3.projection);
    XCTAssertNotNil(findOneAndModifyOptions3.sort);
    XCTAssertTrue(findOneAndModifyOptions3.shouldReturnNewDocument);
    XCTAssertTrue(findOneAndModifyOptions3.upsert);
    XCTAssertFalse([findOneAndModifyOptions3.projection isEqual:@{}]);
    XCTAssertTrue([findOneAndModifyOptions3.projection isEqual:projection]);
    XCTAssertFalse([findOneAndModifyOptions3.sort isEqual:@{}]);
    XCTAssertTrue([findOneAndModifyOptions3.sort isEqual:sort]);

    findOneAndModifyOptions3.projection = nil;
    findOneAndModifyOptions3.sort = nil;
    XCTAssertNil(findOneAndModifyOptions3.projection);
    XCTAssertNil(findOneAndModifyOptions3.sort);

    RLMFindOneAndModifyOptions *findOneAndModifyOptions4 = [[RLMFindOneAndModifyOptions alloc]
                                                            initWithProjection:nil
                                                            sort:nil
                                                            upsert:NO
                                                            shouldReturnNewDocument:NO];

    XCTAssertNil(findOneAndModifyOptions4.projection);
    XCTAssertNil(findOneAndModifyOptions4.sort);
    XCTAssertFalse(findOneAndModifyOptions4.upsert);
    XCTAssertFalse(findOneAndModifyOptions4.shouldReturnNewDocument);
}

- (void)testFindOptions {
    NSDictionary<NSString *, id<RLMBSON>> *projection = @{@"name": @1, @"breed": @1};
    NSDictionary<NSString *, id<RLMBSON>> *sort = @{@"age" : @1, @"coat" : @1};

    RLMFindOptions *findOptions1 = [[RLMFindOptions alloc] init];
    findOptions1.limit = 37;
    XCTAssertNil(findOptions1.projection);
    findOptions1.projection = projection;
    XCTAssertTrue([findOptions1.projection isEqual:projection]);
    XCTAssertNil(findOptions1.sort);
    findOptions1.sort = sort;
    XCTAssertTrue([findOptions1.sort isEqual:sort]);
    XCTAssertEqual(findOptions1.limit, 37);

    RLMFindOptions *findOptions2 = [[RLMFindOptions alloc] initWithProjection:projection
                                                                         sort:sort];
    XCTAssertTrue([findOptions2.projection isEqual:projection]);
    XCTAssertTrue([findOptions2.sort isEqual:sort]);
    XCTAssertEqual(findOptions2.limit, 0);

    RLMFindOptions *findOptions3 = [[RLMFindOptions alloc] initWithLimit:37
                                                              projection:projection
                                                                    sort:sort];
    XCTAssertTrue([findOptions3.projection isEqual:projection]);
    XCTAssertTrue([findOptions3.sort isEqual:sort]);
    XCTAssertEqual(findOptions3.limit, 37);

    findOptions3.projection = nil;
    findOptions3.sort = nil;
    XCTAssertNil(findOptions3.projection);
    XCTAssertNil(findOptions3.sort);

    RLMFindOptions *findOptions4 = [[RLMFindOptions alloc] initWithProjection:nil
                                                                         sort:nil];
    XCTAssertNil(findOptions4.projection);
    XCTAssertNil(findOptions4.sort);
    XCTAssertEqual(findOptions4.limit, 0);
}

- (void)testMongoInsert {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    XCTestExpectation *insertOneExpectation = [self expectationWithDescription:@"should insert one document"];
    [collection insertOneDocument:@{@"name": @"fido", @"breed": @"cane corso"} completion:^(id<RLMBSON> objectId, NSError *error) {
        XCTAssertEqual(objectId.bsonType, RLMBSONTypeObjectId);
        XCTAssertNotEqualObjects(((RLMObjectId *)objectId).stringValue, @"");
        XCTAssertNil(error);
        [insertOneExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *insertManyExpectation = [self expectationWithDescription:@"should insert one document"];
    [collection insertManyDocuments:@[
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"rex", @"breed": @"tibetan mastiff"}]
                         completion:^(NSArray<id<RLMBSON>> *objectIds, NSError *error) {
        XCTAssertGreaterThan(objectIds.count, 0U);
        XCTAssertNil(error);
        [insertManyExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation = [self expectationWithDescription:@"should find documents"];
    RLMFindOptions *options = [[RLMFindOptions alloc] initWithLimit:0 projection:nil sort:nil];
    [collection findWhere:@{@"name": @"fido", @"breed": @"cane corso"}
                  options:options
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertEqual(documents.count, 3U);
        XCTAssertNil(error);
        [findExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testMongoFind {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    XCTestExpectation *insertManyExpectation = [self expectationWithDescription:@"should insert one document"];
    [collection insertManyDocuments:@[
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"rex", @"breed": @"tibetan mastiff"}]
                         completion:^(NSArray<id<RLMBSON>> *objectIds, NSError *error) {
        XCTAssertGreaterThan(objectIds.count, 0U);
        XCTAssertNil(error);
        [insertManyExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation = [self expectationWithDescription:@"should find documents"];
    RLMFindOptions *options = [[RLMFindOptions alloc] initWithLimit:0 projection:nil sort:nil];
    [collection findWhere:@{@"name": @"fido", @"breed": @"cane corso"}
                  options:options
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertEqual(documents.count, 2U);
        XCTAssertNil(error);
        [findExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation2 = [self expectationWithDescription:@"should find documents"];
    [collection findWhere:@{@"name": @"fido", @"breed": @"cane corso"}
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertEqual(documents.count, 2U);
        XCTAssertNil(error);
        [findExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation3 = [self expectationWithDescription:@"should not find documents"];
    [collection findWhere:@{@"name": @"should not exist", @"breed": @"should not exist"}
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertEqual(documents.count, NSUInteger(0));
        XCTAssertNil(error);
        [findExpectation3 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation4 = [self expectationWithDescription:@"should not find documents"];
    [collection findWhere:@{}
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertGreaterThan(documents.count, 0U);
        XCTAssertNil(error);
        [findExpectation4 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneExpectation1 = [self expectationWithDescription:@"should find documents"];
    [collection findOneDocumentWhere:@{@"name": @"fido", @"breed": @"cane corso"}
                          completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"fido"]);
        XCTAssertTrue([document[@"breed"] isEqualToString:@"cane corso"]);
        XCTAssertNil(error);
        [findOneExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneExpectation2 = [self expectationWithDescription:@"should find documents"];
    [collection findOneDocumentWhere:@{@"name": @"fido", @"breed": @"cane corso"}
                             options:options
                          completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"fido"]);
        XCTAssertTrue([document[@"breed"] isEqualToString:@"cane corso"]);
        XCTAssertNil(error);
        [findOneExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

// FIXME: Re-enable once we understand why the server is not setup correctly
- (void)fixme_testMongoAggregateAndCount {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    XCTestExpectation *insertManyExpectation = [self expectationWithDescription:@"should insert one document"];
    [collection insertManyDocuments:@[
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"rex", @"breed": @"tibetan mastiff"}]
                         completion:^(NSArray<id<RLMBSON>> *objectIds, NSError *error) {
        XCTAssertEqual(objectIds.count, 3U);
        XCTAssertNil(error);
        [insertManyExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *aggregateExpectation1 = [self expectationWithDescription:@"should aggregate documents"];
    [collection aggregateWithPipeline:@[@{@"name" : @"fido"}]
                           completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertTrue([error.domain.description isEqualToString:@"realm::app::ServiceError"]);
        XCTAssertNil(documents);
        [aggregateExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *aggregateExpectation2 = [self expectationWithDescription:@"should aggregate documents"];
    [collection aggregateWithPipeline:@[@{@"$match" : @{@"name" : @"fido"}}, @{@"$group" : @{@"_id" : @"$name"}}]
                           completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(documents);
        XCTAssertGreaterThan(documents.count, 0U);
        [aggregateExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *countExpectation1 = [self expectationWithDescription:@"should aggregate documents"];
    [collection countWhere:@{@"name" : @"fido"}
                completion:^(NSInteger count, NSError *error) {
        XCTAssertGreaterThan(count, 0);
        XCTAssertNil(error);
        [countExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *countExpectation2 = [self expectationWithDescription:@"should aggregate documents"];
    [collection countWhere:@{@"name" : @"fido"}
                     limit:1
                completion:^(NSInteger count, NSError *error) {
        XCTAssertEqual(count, 1);
        XCTAssertNil(error);
        [countExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testMongoUpdate {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    XCTestExpectation *updateExpectation1 = [self expectationWithDescription:@"should update document"];
    [collection updateOneDocumentWhere:@{@"name" : @"scrabby doo"}
                        updateDocument:@{@"name" : @"scooby"}
                                upsert:YES
                            completion:^(RLMUpdateResult *result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNotNil(result.objectId);
        XCTAssertEqual(result.modifiedCount, (NSUInteger)0);
        XCTAssertEqual(result.matchedCount, (NSUInteger)0);
        XCTAssertNil(error);
        [updateExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *updateExpectation2 = [self expectationWithDescription:@"should update document"];
    [collection updateOneDocumentWhere:@{@"name" : @"scooby"}
                        updateDocument:@{@"name" : @"fred"}
                                upsert:NO
                            completion:^(RLMUpdateResult *result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNil(result.objectId);
        XCTAssertEqual(result.modifiedCount, (NSUInteger)1);
        XCTAssertEqual(result.matchedCount, (NSUInteger)1);
        XCTAssertNil(error);
        [updateExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *updateExpectation3 = [self expectationWithDescription:@"should update document"];
    [collection updateOneDocumentWhere:@{@"name" : @"fred"}
                        updateDocument:@{@"name" : @"scrabby"}
                            completion:^(RLMUpdateResult *result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNil(result.objectId);
        XCTAssertEqual(result.modifiedCount, (NSUInteger)1);
        XCTAssertEqual(result.matchedCount, (NSUInteger)1);
        XCTAssertNil(error);
        [updateExpectation3 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *updateManyExpectation1 = [self expectationWithDescription:@"should update many documents"];
    [collection updateManyDocumentsWhere:@{@"name" : @"scrabby"}
                          updateDocument:@{@"name" : @"fred"}
                              completion:^(RLMUpdateResult *result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNil(result.objectId);
        XCTAssertEqual(result.modifiedCount, (NSUInteger)1);
        XCTAssertEqual(result.matchedCount, (NSUInteger)1);
        XCTAssertNil(error);
        [updateManyExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *updateManyExpectation2 = [self expectationWithDescription:@"should update many documents"];
    [collection updateManyDocumentsWhere:@{@"name" : @"john"}
                          updateDocument:@{@"name" : @"alex"}
                                  upsert:YES
                              completion:^(RLMUpdateResult *result, NSError *error) {
        XCTAssertNotNil(result);
        XCTAssertNotNil(result.objectId);
        XCTAssertEqual(result.modifiedCount, (NSUInteger)0);
        XCTAssertEqual(result.matchedCount, (NSUInteger)0);
        XCTAssertNil(error);
        [updateManyExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testMongoFindAndModify {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    RLMFindOneAndModifyOptions *findAndModifyOptions = [[RLMFindOneAndModifyOptions alloc] initWithProjection:@{@"name" : @1, @"breed" : @1}
                                                                                                         sort:@{@"name" : @1, @"breed" : @1}
                                                                                                       upsert:YES
                                                                                      shouldReturnNewDocument:YES];

    XCTestExpectation *findOneAndUpdateExpectation1 = [self expectationWithDescription:@"should find one document and update"];
    [collection findOneAndUpdateWhere:@{@"name" : @"alex"}
                       updateDocument:@{@"name" : @"max"}
                              options:findAndModifyOptions
                           completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"max"]);
        XCTAssertNil(error);
        [findOneAndUpdateExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneAndUpdateExpectation2 = [self expectationWithDescription:@"should find one document and update"];
    [collection findOneAndUpdateWhere:@{@"name" : @"max"}
                       updateDocument:@{@"name" : @"john"}
                           completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"max"]);
        XCTAssertNil(error);
        [findOneAndUpdateExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneAndReplaceExpectation1 = [self expectationWithDescription:@"should find one document and replace"];
    [collection findOneAndReplaceWhere:@{@"name" : @"alex"}
                   replacementDocument:@{@"name" : @"max"}
                               options:findAndModifyOptions
                            completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"max"]);
        XCTAssertNil(error);
        [findOneAndReplaceExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneAndReplaceExpectation2 = [self expectationWithDescription:@"should find one document and replace"];
    [collection findOneAndReplaceWhere:@{@"name" : @"max"}
                   replacementDocument:@{@"name" : @"john"}
                            completion:^(NSDictionary *document, NSError *error) {
        XCTAssertTrue([document[@"name"] isEqualToString:@"max"]);
        XCTAssertNil(error);
        [findOneAndReplaceExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testMongoDelete {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    NSArray<RLMObjectId *> *objectIds = [self insertDogDocuments:collection];
    RLMObjectId *rexObjectId = objectIds[1];

    XCTestExpectation *deleteOneExpectation1 = [self expectationWithDescription:@"should delete first document in collection"];
    [collection deleteOneDocumentWhere:@{@"_id" : rexObjectId}
                            completion:^(NSInteger count, NSError *error) {
        XCTAssertEqual(count, 1);
        XCTAssertNil(error);
        [deleteOneExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findExpectation1 = [self expectationWithDescription:@"should find documents"];
    [collection findWhere:@{}
               completion:^(NSArray<NSDictionary *> *documents, NSError *error) {
        XCTAssertEqual(documents.count, 2U);
        XCTAssertTrue([documents[0][@"name"] isEqualToString:@"fido"]);
        XCTAssertNil(error);
        [findExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *deleteManyExpectation1 = [self expectationWithDescription:@"should delete many documents"];
    [collection deleteManyDocumentsWhere:@{@"name" : @"rex"}
                              completion:^(NSInteger count, NSError *error) {
        XCTAssertEqual(count, 0U);
        XCTAssertNil(error);
        [deleteManyExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *deleteManyExpectation2 = [self expectationWithDescription:@"should delete many documents"];
    [collection deleteManyDocumentsWhere:@{@"breed" : @"cane corso"}
                              completion:^(NSInteger count, NSError *error) {
        XCTAssertEqual(count, 1);
        XCTAssertNil(error);
        [deleteManyExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneAndDeleteExpectation1 = [self expectationWithDescription:@"should find one and delete"];
    [collection findOneAndDeleteWhere:@{@"name": @"john"}
                           completion:^(NSDictionary<NSString *, id<RLMBSON>> *document, NSError *error) {
        XCTAssertNotNil(document);
        NSString *name = (NSString *)document[@"name"];
        XCTAssertTrue([name isEqualToString:@"john"]);
        XCTAssertNil(error);
        [findOneAndDeleteExpectation1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTestExpectation *findOneAndDeleteExpectation2 = [self expectationWithDescription:@"should find one and delete"];
    NSDictionary<NSString *, id<RLMBSON>> *projection = @{@"name": @1, @"breed": @1};
    NSDictionary<NSString *, id<RLMBSON>> *sort = @{@"_id" : @1, @"breed" : @1};
    RLMFindOneAndModifyOptions *findOneAndModifyOptions = [[RLMFindOneAndModifyOptions alloc]
                                                           initWithProjection:projection
                                                           sort:sort
                                                           upsert:YES
                                                           shouldReturnNewDocument:YES];

    [collection findOneAndDeleteWhere:@{@"name": @"john"}
                              options:findOneAndModifyOptions
                           completion:^(NSDictionary<NSString *, id<RLMBSON>> *document, NSError *error) {
        XCTAssertNil(document);
        // FIXME: when a projection is used, the server reports the error
        // "expected pre-image to match projection matcher" when there are no
        // matches, rather than simply doing nothing like when there is no projection
//        XCTAssertNil(error);
        (void)error;
        [findOneAndDeleteExpectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

#pragma mark - Watch

- (void)testWatch {
    [self performWatchTest:nil];
}

- (void)testWatchAsync {
    auto asyncQueue = dispatch_queue_create("io.realm.watchQueue", DISPATCH_QUEUE_CONCURRENT);
    [self performWatchTest:asyncQueue];
}

- (void)performWatchTest:(nullable dispatch_queue_t)delegateQueue {
    XCTestExpectation *expectation = [self expectationWithDescription:@"watch collection and receive change event 3 times"];

    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    __block RLMMongoCollection *collection = [database collectionWithName:@"Dog"];

    __block RLMWatchTestUtility *testUtility =
        [[RLMWatchTestUtility alloc] initWithChangeEventCount:3
                                                  expectation:expectation];

    __block RLMChangeStream *changeStream = [collection watchWithDelegate:testUtility delegateQueue:delegateQueue];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(testUtility.isOpenSemaphore, DISPATCH_TIME_FOREVER);
        for (int i = 0; i < 3; i++) {
            [collection insertOneDocument:@{@"name": @"fido"} completion:^(id<RLMBSON> objectId, NSError *error) {
                XCTAssertNil(error);
                XCTAssertNotNil(objectId);
            }];
            dispatch_semaphore_wait(testUtility.semaphore, DISPATCH_TIME_FOREVER);
        }
        [changeStream close];
    });

    [self waitForExpectations:@[expectation] timeout:60.0];
}

- (void)testWatchWithMatchFilter {
    [self performWatchWithMatchFilterTest:nil];
}

- (void)testWatchWithMatchFilterAsync {
    auto asyncQueue = dispatch_queue_create("io.realm.watchQueue", DISPATCH_QUEUE_CONCURRENT);
    [self performWatchWithMatchFilterTest:asyncQueue];
}

- (NSArray<RLMObjectId *> *)insertDogDocuments:(RLMMongoCollection *)collection {
    __block NSArray<RLMObjectId *> *objectIds;
    XCTestExpectation *insertManyExpectation = [self expectationWithDescription:@"should insert documents"];
    [collection insertManyDocuments:@[
        @{@"name": @"fido", @"breed": @"cane corso"},
        @{@"name": @"rex", @"breed": @"tibetan mastiff"},
        @{@"name": @"john", @"breed": @"tibetan mastiff"}]
                         completion:^(NSArray<id<RLMBSON>> *ids, NSError *error) {
        XCTAssertEqual(ids.count, 3U);
        for (id<RLMBSON> objectId in ids) {
            XCTAssertEqual(objectId.bsonType, RLMBSONTypeObjectId);
        }
        XCTAssertNil(error);
        objectIds = (NSArray *)ids;
        [insertManyExpectation fulfill];
    }];
    [self waitForExpectations:@[insertManyExpectation] timeout:60.0];
    return objectIds;
}

- (void)performWatchWithMatchFilterTest:(nullable dispatch_queue_t)delegateQueue {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    __block RLMMongoCollection *collection = [database collectionWithName:@"Dog"];
    NSArray<RLMObjectId *> *objectIds = [self insertDogDocuments:collection];

    XCTestExpectation *expectation = [self expectationWithDescription:@"watch collection and receive change event 3 times"];

    __block RLMWatchTestUtility *testUtility =
        [[RLMWatchTestUtility alloc] initWithChangeEventCount:3
                                             matchingObjectId:objectIds[0]
                                                  expectation:expectation];

    __block RLMChangeStream *changeStream = [collection watchWithMatchFilter:@{@"fullDocument._id": objectIds[0]}
                                                                    delegate:testUtility
                                                               delegateQueue:delegateQueue];

    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(testUtility.isOpenSemaphore, DISPATCH_TIME_FOREVER);
        for (int i = 0; i < 3; i++) {
            [collection updateOneDocumentWhere:@{@"_id": objectIds[0]}
                                updateDocument:@{@"breed": @"king charles", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];

            [collection updateOneDocumentWhere:@{@"_id": objectIds[1]}
                                updateDocument:@{@"breed": @"french bulldog", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];
            dispatch_semaphore_wait(testUtility.semaphore, DISPATCH_TIME_FOREVER);
        }
        [changeStream close];
    });
    [self waitForExpectations:@[expectation] timeout:60.0];
}

- (void)testWatchWithFilterIds {
    [self performWatchWithFilterIdsTest:nil];
}

- (void)testWatchWithFilterIdsAsync {
    auto asyncQueue = dispatch_queue_create("io.realm.watchQueue", DISPATCH_QUEUE_CONCURRENT);
    [self performWatchWithFilterIdsTest:asyncQueue];
}

- (void)performWatchWithFilterIdsTest:(nullable dispatch_queue_t)delegateQueue {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    __block RLMMongoCollection *collection = [database collectionWithName:@"Dog"];
    NSArray<RLMObjectId *> *objectIds = [self insertDogDocuments:collection];

    XCTestExpectation *expectation = [self expectationWithDescription:@"watch collection and receive change event 3 times"];

    __block RLMWatchTestUtility *testUtility =
        [[RLMWatchTestUtility alloc] initWithChangeEventCount:3
                                             matchingObjectId:objectIds[0]
                                                  expectation:expectation];

    __block RLMChangeStream *changeStream = [collection watchWithFilterIds:@[objectIds[0]]
                                                                  delegate:testUtility
                                                             delegateQueue:delegateQueue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(testUtility.isOpenSemaphore, DISPATCH_TIME_FOREVER);
        for (int i = 0; i < 3; i++) {
            [collection updateOneDocumentWhere:@{@"_id": objectIds[0]}
                                updateDocument:@{@"breed": @"king charles", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];

            [collection updateOneDocumentWhere:@{@"_id": objectIds[1]}
                                updateDocument:@{@"breed": @"french bulldog", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];
            dispatch_semaphore_wait(testUtility.semaphore, DISPATCH_TIME_FOREVER);
        }
        [changeStream close];
    });

    [self waitForExpectations:@[expectation] timeout:60.0];
}

- (void)testMultipleWatchStreams {
    auto asyncQueue = dispatch_queue_create("io.realm.watchQueue", DISPATCH_QUEUE_CONCURRENT);
    [self performMultipleWatchStreamsTest:asyncQueue];
}

- (void)testMultipleWatchStreamsAsync {
    [self performMultipleWatchStreamsTest:nil];
}

- (void)performMultipleWatchStreamsTest:(nullable dispatch_queue_t)delegateQueue {
    RLMMongoClient *client = [self.anonymousUser mongoClientWithServiceName:@"mongodb1"];
    RLMMongoDatabase *database = [client databaseWithName:@"test_data"];
    __block RLMMongoCollection *collection = [database collectionWithName:@"Dog"];
    NSArray<RLMObjectId *> *objectIds = [self insertDogDocuments:collection];

    XCTestExpectation *expectation = [self expectationWithDescription:@"watch collection and receive change event 3 times"];
    expectation.expectedFulfillmentCount = 2;

    __block RLMWatchTestUtility *testUtility1 =
        [[RLMWatchTestUtility alloc] initWithChangeEventCount:3
                                             matchingObjectId:objectIds[0]
                                                  expectation:expectation];

    __block RLMWatchTestUtility *testUtility2 =
        [[RLMWatchTestUtility alloc] initWithChangeEventCount:3
                                             matchingObjectId:objectIds[1]
                                                  expectation:expectation];

    __block RLMChangeStream *changeStream1 = [collection watchWithFilterIds:@[objectIds[0]]
                                                                   delegate:testUtility1
                                                              delegateQueue:delegateQueue];

    __block RLMChangeStream *changeStream2 = [collection watchWithFilterIds:@[objectIds[1]]
                                                                   delegate:testUtility2
                                                              delegateQueue:delegateQueue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(testUtility1.isOpenSemaphore, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_wait(testUtility2.isOpenSemaphore, DISPATCH_TIME_FOREVER);
        for (int i = 0; i < 3; i++) {
            [collection updateOneDocumentWhere:@{@"_id": objectIds[0]}
                                updateDocument:@{@"breed": @"king charles", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];

            [collection updateOneDocumentWhere:@{@"_id": objectIds[1]}
                                updateDocument:@{@"breed": @"french bulldog", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];

            [collection updateOneDocumentWhere:@{@"_id": objectIds[2]}
                                updateDocument:@{@"breed": @"german shepard", @"name": [NSString stringWithFormat:@"fido-%d", i]}
                                    completion:^(RLMUpdateResult *, NSError *error) {
                XCTAssertNil(error);
            }];
            dispatch_semaphore_wait(testUtility1.semaphore, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_wait(testUtility2.semaphore, DISPATCH_TIME_FOREVER);
        }
        [changeStream1 close];
        [changeStream2 close];
    });

    [self waitForExpectations:@[expectation] timeout:60.0];
}

#pragma mark - File paths

static NSString *newPathForPartitionValue(RLMUser *user, id<RLMBSON> partitionValue) {
    std::stringstream s;
    s << RLMConvertRLMBSONToBson(partitionValue);
    auto path = user._syncUser->sync_manager()->path_for_realm(*user._syncUser, s.str());
    return @(path.c_str());
}

- (void)testSyncFilePaths {
    RLMUser *user = self.anonymousUser;
    auto configuration = [user configurationWithPartitionValue:@"abc"];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/%%22abc%%22.realm",
                               self.appId, user.identifier])]);
    configuration = [user configurationWithPartitionValue:@123];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/%@.realm",
                               self.appId, user.identifier, @"%7B%22%24numberInt%22%3A%22123%22%7D"])]);
    configuration = [user configurationWithPartitionValue:nil];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/null.realm",
                               self.appId, user.identifier])]);

    XCTAssertEqualObjects([user configurationWithPartitionValue:@"abc"].fileURL.path,
                          newPathForPartitionValue(user, @"abc"));
    XCTAssertEqualObjects([user configurationWithPartitionValue:@123].fileURL.path,
                          newPathForPartitionValue(user, @123));
    XCTAssertEqualObjects([user configurationWithPartitionValue:nil].fileURL.path,
                          newPathForPartitionValue(user, nil));
}

static NSString *oldPathForPartitionValue(RLMUser *user, id<RLMBSON> partitionValue) {
    std::stringstream s;
    s << RLMConvertRLMBSONToBson(partitionValue);
    NSString *encodedPartitionValue = [@(s.str().c_str()) stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *encodedRealmName = [[NSString alloc] initWithFormat:@"%@/%@", user.identifier, encodedPartitionValue];
    auto path = user._syncUser->sync_manager()->path_for_realm(*user._syncUser, encodedRealmName.UTF8String);
    return @(path.c_str());
}

- (void)testLegacyFilePathsAreUsedIfFilesArePresent {
    RLMUser *user = self.anonymousUser;

    auto testPartitionValue = [&](id<RLMBSON> partitionValue) {
        NSURL *url = [NSURL fileURLWithPath:oldPathForPartitionValue(user, partitionValue)];
        @autoreleasepool {
            auto configuration = [user configurationWithPartitionValue:partitionValue];
            configuration.fileURL = url;
            configuration.objectClasses = @[Person.class];
            RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
            [realm beginWriteTransaction];
            [Person createInRealm:realm withValue:[Person george]];
            [realm commitWriteTransaction];
        }

        auto configuration = [user configurationWithPartitionValue:partitionValue];
        configuration.objectClasses = @[Person.class];
        XCTAssertEqualObjects(configuration.fileURL, url);
        RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
        XCTAssertEqual([Person allObjectsInRealm:realm].count, 1U);
    };

    testPartitionValue(@"abc");
    testPartitionValue(@123);
    testPartitionValue(nil);
}

@end

#endif // TARGET_OS_OSX
