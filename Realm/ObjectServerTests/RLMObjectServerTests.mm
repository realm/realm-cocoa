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
#import "RLMTestUtils.h"
#import "RLMSyncSessionRefreshHandle+ObjectServerTests.h"
#import "RLMSyncUser+ObjectServerTests.h"
#import "RLMSyncUtil_Private.h"
#import "RLMRealm+Sync.h"
#import "RLMRealmConfiguration_Private.h"
#import "RLMRealmUtil.hpp"
#import "RLMRealm_Dynamic.h"

#pragma mark - Test objects

@interface PartialSyncObjectA : RLMObject
@property NSInteger number;
@property NSString *string;
+ (instancetype)objectWithNumber:(NSInteger)number string:(NSString *)string;
@end

@interface PartialSyncObjectB : RLMObject
@property NSInteger number;
@property NSString *firstString;
@property NSString *secondString;
+ (instancetype)objectWithNumber:(NSInteger)number firstString:(NSString *)first secondString:(NSString *)second;
@end

@implementation PartialSyncObjectA
+ (instancetype)objectWithNumber:(NSInteger)number string:(NSString *)string {
    PartialSyncObjectA *object = [[PartialSyncObjectA alloc] init];
    object.number = number;
    object.string = string;
    return object;
}
@end

@implementation PartialSyncObjectB
+ (instancetype)objectWithNumber:(NSInteger)number firstString:(NSString *)first secondString:(NSString *)second {
    PartialSyncObjectB *object = [[PartialSyncObjectB alloc] init];
    object.number = number;
    object.firstString = first;
    object.secondString = second;
    return object;
}
@end

@interface RLMObjectServerTests : RLMSyncTestCase
@end

@implementation RLMObjectServerTests

#pragma mark - Authentication and Tokens

/// Valid username/password credentials should be able to log in a user. Using the same credentials should return the
/// same user object.
- (void)testUsernamePasswordAuthentication {
    [self verifyUsernamePasswordAuthenticationWithUsername:NSStringFromSelector(_cmd) simulateReconnection:NO];
}

- (void)testUsernamePasswordAuthenticationWithReconnection {
    [self verifyUsernamePasswordAuthenticationWithUsername:NSStringFromSelector(_cmd) simulateReconnection:YES];
}

- (void)verifyUsernamePasswordAuthenticationWithUsername:(NSString *)username simulateReconnection:(BOOL)simulateReconnection  {
    RLMSyncUser *firstUser = [self logInUserForCredentials:[RLMSyncTestCase basicCredentialsWithName:username
                                                                                            register:YES]
                                                    server:[RLMSyncTestCase authServerURL]
                                      simulateReconnection:simulateReconnection];
    RLMSyncUser *secondUser = [self logInUserForCredentials:[RLMSyncTestCase basicCredentialsWithName:username
                                                                                             register:NO]
                                                     server:[RLMSyncTestCase authServerURL]
                                       simulateReconnection:simulateReconnection];
    // Two users created with the same credential should resolve to the same actual user.
    XCTAssertTrue([firstUser.identity isEqualToString:secondUser.identity]);
    // Authentication server property should be properly set.
    XCTAssertEqualObjects(firstUser.authenticationServer, [RLMSyncTestCase authServerURL]);
    XCTAssertFalse(firstUser.isAdmin);
}

/// A valid admin token should be able to log in a user.
- (void)testAdminTokenAuthentication {
    NSString *adminToken = [RLMSyncTestCase retrieveAdminToken];
    RLMSyncCredentials *credentials = [RLMSyncCredentials credentialsWithAccessToken:adminToken identity:@"test"];
    XCTAssertNotNil(credentials);

    RLMSyncUser *user = [self logInUserForCredentials:credentials server:[RLMObjectServerTests authServerURL]];
    XCTAssertTrue(user.isAdmin);
}

/// An invalid username/password credential should not be able to log in a user and a corresponding error should be generated.
- (void)testInvalidPasswordAuthentication {
    [self logInUserForCredentials:[RLMSyncTestCase basicCredentialsWithName:NSStringFromSelector(_cmd) register:YES]
                          server:[RLMSyncTestCase authServerURL]];

    RLMSyncCredentials *credentials = [RLMSyncCredentials credentialsWithUsername:NSStringFromSelector(_cmd)
                                                                         password:@"INVALID_PASSWORD"
                                                                         register:NO];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [RLMSyncUser logInWithCredentials:credentials
                        authServerURL:[RLMObjectServerTests authServerURL]
                         onCompletion:^(RLMSyncUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, RLMSyncAuthErrorDomain);
        XCTAssertEqual(error.code, RLMSyncAuthErrorInvalidCredential);
        XCTAssertNotNil(error.localizedDescription);

        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// A non-existsing user should not be able to log in and a corresponding error should be generated.
- (void)testNonExistingUsernameAuthentication {
    RLMSyncCredentials *credentials = [RLMSyncTestCase basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                       register:NO];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [RLMSyncUser logInWithCredentials:credentials
                        authServerURL:[RLMObjectServerTests authServerURL]
                         onCompletion:^(RLMSyncUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, RLMSyncAuthErrorDomain);
        XCTAssertEqual(error.code, RLMSyncAuthErrorInvalidCredential);
        XCTAssertNotNil(error.localizedDescription);

        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// Registering a user with existing username should return corresponding error.
- (void)testExistingUsernameRegistration {
    RLMSyncCredentials *credentials = [RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                            register:YES];

    [self logInUserForCredentials:credentials server:[RLMSyncTestCase authServerURL]];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [RLMSyncUser logInWithCredentials:credentials
                        authServerURL:[RLMObjectServerTests authServerURL]
                        onCompletion:^(RLMSyncUser *user, NSError *error) {
        XCTAssertNil(user);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, RLMSyncAuthErrorDomain);
        XCTAssertEqual(error.code, RLMSyncAuthErrorInvalidCredential);
        XCTAssertNotNil(error.localizedDescription);

        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// Errors reported in RLMSyncManager.errorHandler shouldn't contain sync error domain errors as underlying error
- (void)testSyncErrorHandlerErrorDomain {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    XCTAssertNotNil(user);

    NSURL *realmURL = [NSURL URLWithString:@"realm://localhost:9080/THE_PATH_USER_DONT_HAVE_ACCESS_TO/test"];

    RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
    c.syncConfiguration = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:realmURL];

    NSError *error = nil;
    __attribute__((objc_precise_lifetime)) RLMRealm *realm = [RLMRealm realmWithConfiguration:c error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(realm.isEmpty);

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [RLMSyncManager sharedManager].errorHandler = ^(__unused NSError *error,
                                                    __unused RLMSyncSession *session) {
        XCTAssertTrue([error.domain isEqualToString:RLMSyncErrorDomain]);
        XCTAssertFalse([[error.userInfo[kRLMSyncUnderlyingErrorKey] domain] isEqualToString:RLMSyncErrorDomain]);
        [expectation fulfill];
    };

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// The pre-emptive token refresh subsystem should function, and properly refresh the token.
- (void)testPreemptiveTokenRefresh {
    // Prepare the test.
    __block NSInteger refreshCount = 0;
    __block NSInteger errorCount = 0;
    [RLMSyncManager sharedManager].errorHandler = ^(__unused NSError *error,
                                                    __unused RLMSyncSession *session) {
        errorCount++;
    };

    __block XCTestExpectation *ex;
    [RLMSyncSessionRefreshHandle calculateFireDateUsingTestLogic:YES
                                        blockOnRefreshCompletion:^(BOOL success) {
                                            XCTAssertTrue(success);
                                            refreshCount++;
                                            [ex fulfill];
                                        }];
    // Open the Realm.
    NSURL *url = REALM_URL();
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:true]
                                               server:[RLMObjectServerTests authServerURL]];
    __attribute__((objc_precise_lifetime)) RLMRealm *realm = [self openRealmForURL:url user:user];
    ex = [self expectationWithDescription:@"Timer fired"];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertTrue(errorCount == 0);
    XCTAssertTrue(refreshCount > 0);
}

#pragma mark - Users

/// `[RLMSyncUser all]` should be updated once a user is logged in.
- (void)testBasicUserPersistence {
    XCTAssertNil([RLMSyncUser currentUser]);
    XCTAssertEqual([[RLMSyncUser allUsers] count], 0U);
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    XCTAssertNotNil(user);
    XCTAssertEqual([[RLMSyncUser allUsers] count], 1U);
    XCTAssertEqualObjects([RLMSyncUser allUsers], @{user.identity: user});
    XCTAssertEqualObjects([RLMSyncUser currentUser], user);

    RLMSyncUser *user2 = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:[NSStringFromSelector(_cmd) stringByAppendingString:@"2"]
                                                                                             register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    XCTAssertEqual([[RLMSyncUser allUsers] count], 2U);
    NSDictionary *dict2 = @{user.identity: user, user2.identity: user2};
    XCTAssertEqualObjects([RLMSyncUser allUsers], dict2);
    RLMAssertThrowsWithReasonMatching([RLMSyncUser currentUser], @"currentUser cannot be called if more that one valid, logged-in user exists");
}

/// `[RLMSyncUser currentUser]` should become nil if the user is logged out.
- (void)testCurrentUserLogout {
    XCTAssertNil([RLMSyncUser currentUser]);
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    XCTAssertNotNil(user);
    XCTAssertEqualObjects([RLMSyncUser currentUser], user);
    [user logOut];
    XCTAssertNil([RLMSyncUser currentUser]);
}

/// A sync user should return a session when asked for it based on the path.
- (void)testUserGetSessionForValidURL {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    NSURL *url = REALM_URL();
    [self openRealmForURL:url user:user immediatelyBlock:^{
        RLMSyncSession *session = [user sessionForURL:url];
        XCTAssertNotNil(session);
    }];
    // Check session existence after binding.
    RLMSyncSession *session = [user sessionForURL:url];
    XCTAssertNotNil(session);
}

/// A sync user should return nil when asked for a URL that doesn't exist.
- (void)testUserGetSessionForInvalidURL {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMSyncSession *badSession = [user sessionForURL:[NSURL URLWithString:@"realm://localhost:9080/noSuchRealm"]];
    XCTAssertNil(badSession);
}

/// A sync user should be able to successfully change their own password.
- (void)testUserChangePassword {
    NSString *userName = NSStringFromSelector(_cmd);
    NSString *firstPassword = @"a";
    NSString *secondPassword = @"b";
    // Successfully create user, change its password, log out,
    // then fail to change password again due to being logged out.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:userName password:firstPassword
                                                                       register:YES];
        RLMSyncUser *user = [self logInUserForCredentials:creds
                                                   server:[RLMObjectServerTests authServerURL]];
        XCTestExpectation *ex = [self expectationWithDescription:@"change password callback invoked"];
        [user changePassword:secondPassword completion:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
        [user logOut];
        ex = [self expectationWithDescription:@"change password callback invoked"];
        [user changePassword:@"fail" completion:^(NSError * _Nullable error) {
            XCTAssertNotNil(error);
            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    // Fail to log in with original password.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:userName password:firstPassword
                                                                       register:NO];

        XCTestExpectation *ex = [self expectationWithDescription:@"login callback invoked"];
        [RLMSyncUser logInWithCredentials:creds
                            authServerURL:[RLMObjectServerTests authServerURL]
                             onCompletion:^(RLMSyncUser *user, NSError *error) {
            XCTAssertNil(user);
            XCTAssertNotNil(error);
            XCTAssertEqual(error.domain, RLMSyncAuthErrorDomain);
            XCTAssertEqual(error.code, RLMSyncAuthErrorInvalidCredential);
            XCTAssertNotNil(error.localizedDescription);

            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    // Successfully log in with new password.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:userName password:secondPassword
                                                                       register:NO];
        RLMSyncUser *user = [self logInUserForCredentials:creds server:[RLMObjectServerTests authServerURL]];
        XCTAssertNotNil(user);
        XCTAssertEqualObjects(RLMSyncUser.currentUser, user);
        [user logOut];
        XCTAssertNil(RLMSyncUser.currentUser);
    }
}

/// A sync admin user should be able to successfully change another user's password.
- (void)testOtherUserChangePassword {
    // Create admin user.
    NSURL *url = [RLMObjectServerTests authServerURL];
    RLMSyncUser *adminUser = [self createAdminUserForURL:url username:[[NSUUID UUID] UUIDString]];

    NSString *username = NSStringFromSelector(_cmd);
    NSString *firstPassword = @"a";
    NSString *secondPassword = @"b";
    NSString *nonAdminUserID = nil;
    // Successfully create user.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:username
                                                                       password:firstPassword
                                                                       register:YES];
        RLMSyncUser *user = [self logInUserForCredentials:creds server:url];
        nonAdminUserID = user.identity;
        [user logOut];
    }
    // Fail to change password from non-admin user.
    {
        NSString *username2 = [NSString stringWithFormat:@"%@_2", username];
        RLMSyncCredentials *creds2 = [RLMSyncCredentials credentialsWithUsername:username2
                                                                             password:@"a"
                                                                             register:YES];
        RLMSyncUser *user2 = [self logInUserForCredentials:creds2 server:url];
        XCTestExpectation *ex = [self expectationWithDescription:@"change password callback invoked"];
        [user2 changePassword:@"foobar" forUserID:nonAdminUserID completion:^(NSError *error) {
            XCTAssertNotNil(error);
            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    // Change password from admin user.
    {
        XCTestExpectation *ex = [self expectationWithDescription:@"change password callback invoked"];
        [adminUser changePassword:secondPassword forUserID:nonAdminUserID completion:^(NSError *error) {
            XCTAssertNil(error);
            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    // Fail to log in with original password.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:username
                                                                       password:firstPassword
                                                                       register:NO];

        XCTestExpectation *ex = [self expectationWithDescription:@"login callback invoked"];
        [RLMSyncUser logInWithCredentials:creds
                            authServerURL:[RLMObjectServerTests authServerURL]
                             onCompletion:^(RLMSyncUser *user, NSError *error) {
            XCTAssertNil(user);
            XCTAssertNotNil(error);
            XCTAssertEqual(error.domain, RLMSyncAuthErrorDomain);
            XCTAssertEqual(error.code, RLMSyncAuthErrorInvalidCredential);
            XCTAssertNotNil(error.localizedDescription);

            [ex fulfill];
        }];
        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    // Successfully log in with new password.
    {
        RLMSyncCredentials *creds = [RLMSyncCredentials credentialsWithUsername:username
                                                                       password:secondPassword
                                                                       register:NO];
        RLMSyncUser *user = [self logInUserForCredentials:creds server:[RLMObjectServerTests authServerURL]];
        XCTAssertNotNil(user);
        [user logOut];
    }
}

/// A sync admin user should be able to retrieve information about other users.
- (void)testRetrieveUserInfo {
    NSString *nonAdminUsername = @"meela@realm.example.org";
    NSString *adminUsername = @"jyaku";
    NSString *pw = @"p";
    NSURL *server = [RLMObjectServerTests authServerURL];

    // Create a non-admin user.
    RLMSyncCredentials *c1 = [RLMSyncCredentials credentialsWithUsername:nonAdminUsername password:pw register:YES];
    RLMSyncUser *nonAdminUser = [self logInUserForCredentials:c1 server:server];

    // Create an admin user.
    __unused RLMSyncUser *adminUser = [self createAdminUserForURL:server username:adminUsername];

    // Create another admin user.
    RLMSyncUser *userDoingLookups = [self createAdminUserForURL:server username:[[NSUUID UUID] UUIDString]];

    // Get the non-admin user's info.
    XCTestExpectation *ex1 = [self expectationWithDescription:@"should be able to get info about non-admin user"];
    [userDoingLookups retrieveInfoForUser:nonAdminUsername
                         identityProvider:RLMIdentityProviderUsernamePassword
                               completion:^(RLMSyncUserInfo *info, NSError *err) {
                                   XCTAssertNil(err);
                                   XCTAssertNotNil(info);
                                   XCTAssertGreaterThan([info.accounts count], ((NSUInteger) 0));
                                   RLMSyncUserAccountInfo *acctInfo = [info.accounts firstObject];
                                   XCTAssertEqualObjects(acctInfo.providerUserIdentity, nonAdminUsername);
                                   XCTAssertEqualObjects(acctInfo.provider, RLMIdentityProviderUsernamePassword);
                                   XCTAssertFalse(info.isAdmin);
                                   [ex1 fulfill];
                               }];
    [self waitForExpectationsWithTimeout:10 handler:nil];

    // Get the admin user's info.
    XCTestExpectation *ex2 = [self expectationWithDescription:@"should be able to get info about admin user"];
    [userDoingLookups retrieveInfoForUser:adminUsername
                         identityProvider:RLMIdentityProviderDebug
                               completion:^(RLMSyncUserInfo *info, NSError *err) {
                                   XCTAssertNil(err);
                                   XCTAssertNotNil(info);
                                   XCTAssertGreaterThan([info.accounts count], ((NSUInteger) 0));
                                   RLMSyncUserAccountInfo *acctInfo = [info.accounts firstObject];
                                   XCTAssertEqualObjects(acctInfo.providerUserIdentity, adminUsername);
                                   XCTAssertEqualObjects(acctInfo.provider, RLMIdentityProviderDebug);
                                   XCTAssertTrue(info.isAdmin);
                                   [ex2 fulfill];
                               }];
    [self waitForExpectationsWithTimeout:10 handler:nil];

    // Get invalid user's info.
    XCTestExpectation *ex3 = [self expectationWithDescription:@"should fail for non-existent user"];
    [userDoingLookups retrieveInfoForUser:@"invalid_user@realm.example.org"
                         identityProvider:RLMIdentityProviderUsernamePassword
                               completion:^(RLMSyncUserInfo *info, NSError *err) {
                                   XCTAssertNotNil(err);
                                   XCTAssertEqualObjects(err.domain, RLMSyncAuthErrorDomain);
                                   XCTAssertEqual(err.code, RLMSyncAuthErrorUserDoesNotExist);
                                   XCTAssertNil(info);
                                   [ex3 fulfill];
                               }];
    [self waitForExpectationsWithTimeout:10 handler:nil];

    // Get info using user without admin privileges.
    XCTestExpectation *ex4 = [self expectationWithDescription:@"should fail for user without admin privileges"];
    [nonAdminUser retrieveInfoForUser:adminUsername
                     identityProvider:RLMIdentityProviderUsernamePassword
                           completion:^(RLMSyncUserInfo *info, NSError *err) {
                               XCTAssertNotNil(err);
                               XCTAssertEqualObjects(err.domain, RLMSyncAuthErrorDomain);
                               // FIXME: Shouldn't this be RLMSyncAuthErrorAccessDeniedOrInvalidPath?
                               XCTAssertEqual(err.code, RLMSyncAuthErrorUserDoesNotExist);
                               XCTAssertNil(info);
                               [ex4 fulfill];
                           }];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

/// The login queue argument should be respected.
- (void)testLoginQueueForSuccessfulLogin {
    // Make global queue
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    RLMSyncCredentials *c1 = [RLMSyncCredentials credentialsWithUsername:[[NSUUID UUID] UUIDString]
                                                                password:@"p"
                                                                register:YES];
    XCTestExpectation *ex1 = [self expectationWithDescription:@"User logs in successfully on background queue"];
    [RLMSyncUser logInWithCredentials:c1
                        authServerURL:[RLMObjectServerTests authServerURL]
                              timeout:30.0
                        callbackQueue:queue
                         onCompletion:^(RLMSyncUser *user, __unused NSError *error) {
                             XCTAssertNotNil(user);
                             XCTAssertFalse([NSThread isMainThread]);
                             [ex1 fulfill];
                         }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    RLMSyncCredentials *c2 = [RLMSyncCredentials credentialsWithUsername:[[NSUUID UUID] UUIDString]
                                                                password:@"p"
                                                                register:YES];
    XCTestExpectation *ex2 = [self expectationWithDescription:@"User logs in successfully on main queue"];
    [RLMSyncUser logInWithCredentials:c2
                        authServerURL:[RLMObjectServerTests authServerURL]
                              timeout:30.0
                        callbackQueue:dispatch_get_main_queue()
                         onCompletion:^(RLMSyncUser *user, __unused NSError *error) {
                             XCTAssertNotNil(user);
                             XCTAssertTrue([NSThread isMainThread]);
                             [ex2 fulfill];
                         }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// The login queue argument should be respected.
- (void)testLoginQueueForFailedLogin {
    // Make global queue
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    RLMSyncCredentials *c1 = [RLMSyncCredentials credentialsWithUsername:[[NSUUID UUID] UUIDString]
                                                                password:@"p"
                                                                register:NO];
    XCTestExpectation *ex1 = [self expectationWithDescription:@"Error returned on background queue"];
    [RLMSyncUser logInWithCredentials:c1
                        authServerURL:[RLMObjectServerTests authServerURL]
                              timeout:30.0
                        callbackQueue:queue
                         onCompletion:^(__unused RLMSyncUser *user, NSError *error) {
                             XCTAssertNotNil(error);
                             XCTAssertFalse([NSThread isMainThread]);
                             [ex1 fulfill];
                         }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    RLMSyncCredentials *c2 = [RLMSyncCredentials credentialsWithUsername:[[NSUUID UUID] UUIDString]
                                                                password:@"p"
                                                                register:NO];
    XCTestExpectation *ex2 = [self expectationWithDescription:@"Error returned on main queue"];
    [RLMSyncUser logInWithCredentials:c2
                        authServerURL:[RLMObjectServerTests authServerURL]
                              timeout:30.0
                        callbackQueue:dispatch_get_main_queue()
                         onCompletion:^(__unused RLMSyncUser *user, NSError *error) {
                             XCTAssertNotNil(error);
                             XCTAssertTrue([NSThread isMainThread]);
                             [ex2 fulfill];
                         }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testUserExpirationCallback {
    NSString *username = NSStringFromSelector(_cmd);
    RLMSyncCredentials *credentials = [RLMSyncCredentials credentialsWithUsername:username
                                                                         password:@"a"
                                                                         register:YES];
    RLMSyncUser *user = [self logInUserForCredentials:credentials
                                               server:[RLMObjectServerTests authServerURL]];

    XCTestExpectation *ex = [self expectationWithDescription:@"callback should fire"];
    // Set a callback on the user
    __weak RLMSyncUser *weakUser = user;
    user.errorHandler = ^(RLMSyncUser *u, NSError *error) {
        XCTAssertEqualObjects(u.identity, weakUser.identity);
        // Make sure we get the right error.
        XCTAssertEqualObjects(error.domain, RLMSyncAuthErrorDomain);
        XCTAssertEqual(error.code, RLMSyncAuthErrorAccessDeniedOrInvalidPath);
        [ex fulfill];
    };

    // Screw up the token on the user using a debug API
    [self manuallySetRefreshTokenForUser:user value:@"not_a_real_refresh_token"];

    // Try to log in a Realm; this will cause our errorHandler block defined above to be fired.
    __attribute__((objc_precise_lifetime)) RLMRealm *r = [self immediatelyOpenRealmForURL:REALM_URL() user:user];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertTrue(user.state == RLMSyncUserStateLoggedOut);
}

#pragma mark - Basic Sync

/// It should be possible to successfully open a Realm configured for sync with an access token.
- (void)testOpenRealmWithAdminToken {
    // FIXME (tests): opening a Realm with the access token, then opening a Realm at the same virtual path
    // with normal credentials, causes Realms to fail to bind with a "bad virtual path" error.
    NSString *adminToken = [RLMSyncTestCase retrieveAdminToken];
    RLMSyncCredentials *credentials = [RLMSyncCredentials credentialsWithAccessToken:adminToken identity:@"test"];
    XCTAssertNotNil(credentials);
    RLMSyncUser *user = [self logInUserForCredentials:credentials
                                               server:[RLMObjectServerTests authServerURL]];
    NSURL *url = [NSURL URLWithString:@"realm://localhost:9080/testSyncWithAdminToken"];
    RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
    c.syncConfiguration = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
    NSError *error = nil;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:c error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(realm.isEmpty);
}

/// It should be possible to successfully open a Realm configured for sync with a normal user.
- (void)testOpenRealmWithNormalCredentials {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    NSURL *url = REALM_URL();
    RLMRealm *realm = [self openRealmForURL:url user:user];
    XCTAssertTrue(realm.isEmpty);
}

/// If client B adds objects to a synced Realm, client A should see those objects.
- (void)testAddObjects {
    [self verifyAddObjectsWithUsername:NSStringFromSelector(_cmd) relamURL:REALM_URL() simulateReconnection:NO];
}

- (void)testAddObjectsWithReconnection {
    [self verifyAddObjectsWithUsername:NSStringFromSelector(_cmd) relamURL:REALM_URL() simulateReconnection:YES];
}

- (void)verifyAddObjectsWithUsername:(NSString *)username
                            relamURL:(NSURL *)url
                simulateReconnection:(BOOL)simulateReconnection {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:username
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    if (!self.isParent && simulateReconnection) {
        [self disableNetworking];
    }
    RLMRealm *realm = [self immediatelyOpenRealmForURL:url
                                                  user:user
                                         encryptionKey:nil
                                            stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
    if (self.isParent) {
        CHECK_COUNT(0, SyncObject, realm);
        RLMRunChildAndWait();
        if (simulateReconnection) {
            [self disableNetworking];
            [self enableNetworkingAfter:20];
        }
        [self waitForDownloadsForUser:user realms:@[realm] realmURLs:@[url] expectedCounts:@[@3]];
    } else {
        if (simulateReconnection) {
            [self enableNetworkingAfter:20];
        }
        // Add objects.
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// If client B deletes objects from a synced Realm, client A should see the effects of that deletion.
- (void)testDeleteObjects {
    NSURL *url = REALM_URL();
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMRealm *realm = [self openRealmForURL:url user:user];
    if (self.isParent) {
        // Add objects.
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1", @"parent-2", @"parent-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(0, SyncObject, realm);
    } else {
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
        [realm beginWriteTransaction];
        [realm deleteAllObjects];
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(0, SyncObject, realm);
    }
}

#pragma mark - Encryption

/// If client B encrypts its synced Realm, client A should be able to access that Realm with a different encryption key.
- (void)testEncryptedSyncedRealm {
    NSURL *url = REALM_URL();
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];

    NSData *key = RLMGenerateKey();
    RLMRealm *realm = [self openRealmForURL:url user:user encryptionKey:key
                                 stopPolicy:RLMSyncStopPolicyAfterChangesUploaded immediatelyBlock:nil];
    if (self.isParent) {
        CHECK_COUNT(0, SyncObject, realm);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user realms:@[realm] realmURLs:@[url] expectedCounts:@[@3]];
    } else {
        // Add objects.
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// If an encrypted synced Realm is re-opened with the wrong key, throw an exception.
- (void)testEncryptedSyncedRealmWrongKey {
    NSURL *url = REALM_URL();
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];

    if (self.isParent) {
        NSString *path;
        @autoreleasepool {
            RLMRealm *realm = [self openRealmForURL:url user:user encryptionKey:RLMGenerateKey()
                                         stopPolicy:RLMSyncStopPolicyImmediately immediatelyBlock:nil];
            path = realm.configuration.pathOnDisk;
            CHECK_COUNT(0, SyncObject, realm);
            RLMRunChildAndWait();
            [self waitForDownloadsForUser:user realms:@[realm] realmURLs:@[url] expectedCounts:@[@3]];
        }
        RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
        c.fileURL = [NSURL fileURLWithPath:path];
        RLMAssertThrowsWithError([RLMRealm realmWithConfiguration:c error:nil],
                                 @"Unable to open a realm at path",
                                 RLMErrorFileAccess,
                                 @"not a realm file");
        c.encryptionKey = RLMGenerateKey();
        RLMAssertThrowsWithError([RLMRealm realmWithConfiguration:c error:nil],
                                 @"Unable to open a realm at path",
                                 RLMErrorFileAccess,
                                 @"Realm file decryption failed");
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user encryptionKey:RLMGenerateKey()
                                     stopPolicy:RLMSyncStopPolicyImmediately immediatelyBlock:nil];
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

#pragma mark - Multiple Realm Sync

/// If a client opens multiple Realms, there should be one session object for each Realm that was opened.
- (void)testMultipleRealmsSessions {
    NSURL *urlA = CUSTOM_REALM_URL(@"a");
    NSURL *urlB = CUSTOM_REALM_URL(@"b");
    NSURL *urlC = CUSTOM_REALM_URL(@"c");
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    // Open three Realms.
    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmA = [self openRealmForURL:urlA user:user];
    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmB = [self openRealmForURL:urlB user:user];
    __attribute__((objc_precise_lifetime)) RLMRealm *realmealmC = [self openRealmForURL:urlC user:user];
    // Make sure there are three active sessions for the user.
    XCTAssert(user.allSessions.count == 3, @"Expected 3 sessions, but didn't get 3 sessions");
    XCTAssertNotNil([user sessionForURL:urlA], @"Expected to get a session for URL A");
    XCTAssertNotNil([user sessionForURL:urlB], @"Expected to get a session for URL B");
    XCTAssertNotNil([user sessionForURL:urlC], @"Expected to get a session for URL C");
    XCTAssertTrue([user sessionForURL:urlA].state == RLMSyncSessionStateActive, @"Expected active session for URL A");
    XCTAssertTrue([user sessionForURL:urlB].state == RLMSyncSessionStateActive, @"Expected active session for URL B");
    XCTAssertTrue([user sessionForURL:urlC].state == RLMSyncSessionStateActive, @"Expected active session for URL C");
}

/// A client should be able to open multiple Realms and add objects to each of them.
- (void)testMultipleRealmsAddObjects {
    NSURL *urlA = CUSTOM_REALM_URL(@"a");
    NSURL *urlB = CUSTOM_REALM_URL(@"b");
    NSURL *urlC = CUSTOM_REALM_URL(@"c");
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMRealm *realmA = [self openRealmForURL:urlA user:user];
    RLMRealm *realmB = [self openRealmForURL:urlB user:user];
    RLMRealm *realmC = [self openRealmForURL:urlC user:user];
    if (self.isParent) {
        [self waitForDownloadsForUser:user url:urlA];
        [self waitForDownloadsForUser:user url:urlB];
        [self waitForDownloadsForUser:user url:urlC];
        CHECK_COUNT(0, SyncObject, realmA);
        CHECK_COUNT(0, SyncObject, realmB);
        CHECK_COUNT(0, SyncObject, realmC);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realmA, realmB, realmC]
                            realmURLs:@[urlA, urlB, urlC]
                       expectedCounts:@[@3, @2, @5]];
    } else {
        // Add objects.
        [self addSyncObjectsToRealm:realmA
                       descriptions:@[@"child-A1", @"child-A2", @"child-A3"]];
        [self addSyncObjectsToRealm:realmB
                       descriptions:@[@"child-B1", @"child-B2"]];
        [self addSyncObjectsToRealm:realmC
                       descriptions:@[@"child-C1", @"child-C2", @"child-C3", @"child-C4", @"child-C5"]];
        [self waitForUploadsForUser:user url:urlA];
        [self waitForUploadsForUser:user url:urlB];
        [self waitForUploadsForUser:user url:urlC];
        CHECK_COUNT(3, SyncObject, realmA);
        CHECK_COUNT(2, SyncObject, realmB);
        CHECK_COUNT(5, SyncObject, realmC);
    }
}

/// A client should be able to open multiple Realms and delete objects from each of them.
- (void)testMultipleRealmsDeleteObjects {
    NSURL *urlA = CUSTOM_REALM_URL(@"a");
    NSURL *urlB = CUSTOM_REALM_URL(@"b");
    NSURL *urlC = CUSTOM_REALM_URL(@"c");
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMRealm *realmA = [self openRealmForURL:urlA user:user];
    RLMRealm *realmB = [self openRealmForURL:urlB user:user];
    RLMRealm *realmC = [self openRealmForURL:urlC user:user];
    if (self.isParent) {
        [self waitForDownloadsForUser:user url:urlA];
        [self waitForDownloadsForUser:user url:urlB];
        [self waitForDownloadsForUser:user url:urlC];
        // Add objects.
        [self addSyncObjectsToRealm:realmA
                       descriptions:@[@"parent-A1", @"parent-A2", @"parent-A3", @"parent-A4"]];
        [self addSyncObjectsToRealm:realmB
                       descriptions:@[@"parent-B1", @"parent-B2", @"parent-B3", @"parent-B4", @"parent-B5"]];
        [self addSyncObjectsToRealm:realmC
                       descriptions:@[@"parent-C1", @"parent-C2"]];
        [self waitForUploadsForUser:user url:urlA];
        [self waitForUploadsForUser:user url:urlB];
        [self waitForUploadsForUser:user url:urlC];
        CHECK_COUNT(4, SyncObject, realmA);
        CHECK_COUNT(5, SyncObject, realmB);
        CHECK_COUNT(2, SyncObject, realmC);
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user
                               realms:@[realmA, realmB, realmC]
                            realmURLs:@[urlA, urlB, urlC]
                       expectedCounts:@[@0, @0, @0]];
    } else {
        // Delete all the objects from the Realms.
        [self waitForDownloadsForUser:user url:urlA];
        [self waitForDownloadsForUser:user url:urlB];
        [self waitForDownloadsForUser:user url:urlC];
        CHECK_COUNT(4, SyncObject, realmA);
        CHECK_COUNT(5, SyncObject, realmB);
        CHECK_COUNT(2, SyncObject, realmC);
        [realmA beginWriteTransaction];
        [realmA deleteAllObjects];
        [realmA commitWriteTransaction];
        [realmB beginWriteTransaction];
        [realmB deleteAllObjects];
        [realmB commitWriteTransaction];
        [realmC beginWriteTransaction];
        [realmC deleteAllObjects];
        [realmC commitWriteTransaction];
        [self waitForUploadsForUser:user url:urlA];
        [self waitForUploadsForUser:user url:urlB];
        [self waitForUploadsForUser:user url:urlC];
        CHECK_COUNT(0, SyncObject, realmA);
        CHECK_COUNT(0, SyncObject, realmB);
        CHECK_COUNT(0, SyncObject, realmC);
    }
}

#pragma mark - Session Lifetime

/// When a session opened by a Realm goes out of scope, it should stay alive long enough to finish any waiting uploads.
- (void)testUploadChangesWhenRealmOutOfScope {
    const NSInteger OBJECT_COUNT = 10000;
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];

    if (self.isParent) {
        // Open the Realm in an autorelease pool so that it is destroyed as soon as possible.
        @autoreleasepool {
            RLMRealm *realm = [self openRealmForURL:url user:user];
            [realm beginWriteTransaction];
            for (NSInteger i=0; i<OBJECT_COUNT; i++) {
                [realm addObject:[[SyncObject alloc] initWithValue:@[[NSString stringWithFormat:@"parent-%@", @(i+1)]]]];
            }
            [realm commitWriteTransaction];
            CHECK_COUNT(OBJECT_COUNT, SyncObject, realm);
        }
        // Run the sub-test. (Give the upload a bit of time to start.)
        // NOTE: This sleep should be fine because:
        // - There is currently no API that allows asynchronous coordination for waiting for an upload to begin.
        // - A delay longer than the specified one will not affect the outcome of the test.
        sleep(2);
        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Wait for download to complete.
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(OBJECT_COUNT, SyncObject, realm);
    }
}

#pragma mark - Logging Back In

/// A Realm that was opened before a user logged out should be able to resume uploading if the user logs back in.
- (void)testLogBackInSameRealmUpload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMRealm *realm = [self openRealmForURL:url user:user];

    if (self.isParent) {
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        CHECK_COUNT(1, SyncObject, realm);
        [self waitForUploadsForUser:user url:url];
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-2", @"parent-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
        RLMRunChildAndWait();
    } else {
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// A Realm that was opened before a user logged out should be able to resume downloading if the user logs back in.
- (void)testLogBackInSameRealmDownload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMRealm *realm = [self openRealmForURL:url user:user];

    if (self.isParent) {
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        CHECK_COUNT(1, SyncObject, realm);
        [self waitForUploadsForUser:user url:url];
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    } else {
        [self waitForDownloadsForUser:user url:url];
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// A Realm that was opened while a user was logged out should be able to start uploading if the user logs back in.
- (void)testLogBackInDeferredRealmUpload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    NSError *error = nil;
    if (self.isParent) {
        // Semaphore for knowing when the Realm is successfully opened for sync.
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.syncConfiguration = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
        [user logOut];
        // Open a Realm after the user's been logged out.
        [self primeSyncManagerWithSemaphore:sema];
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:&error];
        XCTAssertNil(error, @"Error when opening Realm: %@", error);
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        CHECK_COUNT(1, SyncObject, realm);
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        // Wait for the Realm's session to be bound.
        WAIT_FOR_SEMAPHORE(sema, 30);
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-2", @"parent-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        XCTAssertNil(error, @"Error when opening Realm: %@", error);
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// A Realm that was opened while a user was logged out should be able to start downloading if the user logs back in.
- (void)testLogBackInDeferredRealmDownload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    NSError *error = nil;
    if (self.isParent) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        RLMRunChildAndWait();
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.syncConfiguration = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
        [user logOut];
        // Open a Realm after the user's been logged out.
        [self primeSyncManagerWithSemaphore:sema];
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:&error];
        XCTAssertNil(error, @"Error when opening Realm: %@", error);
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        CHECK_COUNT(1, SyncObject, realm);
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        // Wait for the Realm's session to be bound.
        WAIT_FOR_SEMAPHORE(sema, 30);
        [self waitForDownloadsForUser:user realms:@[realm] realmURLs:@[url] expectedCounts:@[@4]];
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        XCTAssertNil(error, @"Error when opening Realm: %@", error);
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(3, SyncObject, realm);
    }
}

/// After logging back in, a Realm whose path has been opened for the first time should properly upload changes.
- (void)testLogBackInOpenFirstTimePathUpload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];

    // Now run a basic multi-client test.
    if (self.isParent) {
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                     server:[RLMObjectServerTests authServerURL]];
        // Open the Realm (for the first time).
        RLMRealm *realm = [self openRealmForURL:url user:user];
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(2, SyncObject, realm);
        RLMRunChildAndWait();
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Add objects.
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(2, SyncObject, realm);
    }
}

/// After logging back in, a Realm whose path has been opened for the first time should properly download changes.
- (void)testLogBackInOpenFirstTimePathDownload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];

    // Now run a basic multi-client test.
    if (self.isParent) {
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        // Open the Realm (for the first time).
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Run the sub-test.
        RLMRunChildAndWait();
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(2, SyncObject, realm);
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Add objects.
        [self waitForDownloadsForUser:user url:url];
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(2, SyncObject, realm);
    }
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly upload changes for a new
/// `RLMRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmUpload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    // Open the Realm
    RLMRealm *realm = [self openRealmForURL:url user:user];
    if (self.isParent) {
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(1, SyncObject, realm);
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        // Open the Realm again.
        realm = [self immediatelyOpenRealmForURL:url user:user];
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3", @"child-4"]];
        CHECK_COUNT(5, SyncObject, realm);
        [self waitForUploadsForUser:user url:url];
        RLMRunChildAndWait();
    } else {
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(5, SyncObject, realm);
    }
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly download changes for a new
/// `RLMRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmDownload {
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                              server:[RLMObjectServerTests authServerURL]];
    // Open the Realm
    RLMRealm *realm = [self openRealmForURL:url user:user];
    if (self.isParent) {
        [self addSyncObjectsToRealm:realm descriptions:@[@"parent-1"]];
        [self waitForUploadsForUser:user url:url];
        XCTAssert([SyncObject allObjectsInRealm:realm].count == 1, @"Expected 1 item");
        // Log out the user.
        [user logOut];
        // Log the user back in.
        user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                   register:NO]
                                      server:[RLMObjectServerTests authServerURL]];
        // Run the sub-test.
        RLMRunChildAndWait();
        // Open the Realm again and get the items.
        realm = [self immediatelyOpenRealmForURL:url user:user];
        [self waitForDownloadsForUser:user realms:@[realm] realmURLs:@[url] expectedCounts:@[@5]];
    } else {
        // Add objects.
        [self waitForDownloadsForUser:user url:url];
        CHECK_COUNT(1, SyncObject, realm);
        [self addSyncObjectsToRealm:realm descriptions:@[@"child-1", @"child-2", @"child-3", @"child-4"]];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(5, SyncObject, realm);
    }
}

#pragma mark - Client reset

/// Ensure that a client reset error is propagated up to the binding successfully.
- (void)testClientReset {
    NSURL *url = REALM_URL();
    NSString *sessionName = NSStringFromSelector(_cmd);
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:sessionName
                                                                                            register:true]
                                               server:[RLMObjectServerTests authServerURL]];
    // Open the Realm
    __attribute__((objc_precise_lifetime)) RLMRealm *realm = [self openRealmForURL:url user:user];

    __block NSError *theError = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
    [RLMSyncManager sharedManager].errorHandler = ^void(NSError *error, RLMSyncSession *session) {
        // Make sure we're actually looking at the right session.
        XCTAssertTrue([[session.realmURL absoluteString] rangeOfString:sessionName].location != NSNotFound);
        theError = error;
        [ex fulfill];
    };
    [user simulateClientResetErrorForSession:url];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertNotNil(theError);
    XCTAssertTrue(theError.code == RLMSyncErrorClientResetError);
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertNotNil(pathValue);
    // Sanity check the recovery path.
    NSString *recoveryPath = @"io.realm.object-server-recovered-realms/recovered_realm";
    XCTAssertTrue([pathValue rangeOfString:recoveryPath].location != NSNotFound);
    XCTAssertNotNil([theError rlmSync_errorActionToken]);
}

/// Test manually initiating client reset.
- (void)testClientResetManualInitiation {
    NSURL *url = REALM_URL();
    NSString *sessionName = NSStringFromSelector(_cmd);
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:sessionName
                                                                                            register:true]
                                               server:[RLMObjectServerTests authServerURL]];
    __block NSError *theError = nil;
    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) RLMRealm *realm = [self openRealmForURL:url user:user];
        XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
        [RLMSyncManager sharedManager].errorHandler = ^void(NSError *error, RLMSyncSession *session) {
            // Make sure we're actually looking at the right session.
            XCTAssertTrue([[session.realmURL absoluteString] rangeOfString:sessionName].location != NSNotFound);
            theError = error;
            [ex fulfill];
        };
        [user simulateClientResetErrorForSession:url];
        [self waitForExpectationsWithTimeout:10 handler:nil];
        XCTAssertNotNil(theError);
    }
    // At this point the Realm should be invalidated and client reset should be possible.
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:pathValue]);
    [RLMSyncSession immediatelyHandleError:[theError rlmSync_errorActionToken]];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:pathValue]);
}

#pragma mark - Progress Notifications

- (void)testStreamingDownloadNotifier {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    __block NSInteger callCount = 0;
    __block NSUInteger transferred = 0;
    __block NSUInteger transferrable = 0;
    // Open the Realm
    RLMRealm *realm = [self openRealmForURL:url user:user];
    if (self.isParent) {
        __block BOOL hasBeenFulfilled = NO;
        // Register a notifier.
        RLMSyncSession *session = [user sessionForURL:url];
        XCTAssertNotNil(session);
        XCTestExpectation *ex = [self expectationWithDescription:@"streaming-download-notifier"];
        RLMProgressNotificationToken *token = [session addProgressNotificationForDirection:RLMSyncProgressDirectionDownload
                                                                                      mode:RLMSyncProgressModeReportIndefinitely
                                                                                     block:^(NSUInteger xfr, NSUInteger xfb) {
            // Make sure the values are increasing, and update our stored copies.
            XCTAssert(xfr >= transferred);
            XCTAssert(xfb >= transferrable);
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
        XCTAssert(callCount > 1);
        XCTAssert(transferred >= transferrable,
                  @"Transferred (%@) needs to be greater than or equal to transferrable (%@)",
                  @(transferred), @(transferrable));
    } else {
        // Write lots of data to the Realm, then wait for it to be uploaded.
        [realm beginWriteTransaction];
        for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
            [realm addObject:[HugeSyncObject object]];
        }
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    }
}

- (void)testStreamingUploadNotifier {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    __block NSInteger callCount = 0;
    __block NSUInteger transferred = 0;
    __block NSUInteger transferrable = 0;
    __block BOOL hasBeenFulfilled = NO;
    // Open the Realm
    RLMRealm *realm = [self openRealmForURL:url user:user];

    // Register a notifier.
    RLMSyncSession *session = [user sessionForURL:url];
    XCTAssertNotNil(session);
    XCTestExpectation *ex = [self expectationWithDescription:@"streaming-upload-expectation"];
    RLMProgressNotificationToken *token = [session addProgressNotificationForDirection:RLMSyncProgressDirectionUpload
                                                                                  mode:RLMSyncProgressModeReportIndefinitely
                                                                                 block:^(NSUInteger xfr, NSUInteger xfb) {
                                                                                     // Make sure the values are
                                                                                     // increasing, and update our
                                                                                     // stored copies.
                                                                                     XCTAssert(xfr >= transferred);
                                                                                     XCTAssert(xfb >= transferrable);
                                                                                     transferred = xfr;
                                                                                     transferrable = xfb;
                                                                                     callCount++;
                                                                                     if (transferred > 0
                                                                                         && transferred >= transferrable
                                                                                         && !hasBeenFulfilled) {
                                                                                         [ex fulfill];
                                                                                         hasBeenFulfilled = YES;
                                                                                     }
                                                                                 }];
    // Upload lots of data
    [realm beginWriteTransaction];
    for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
        [realm addObject:[HugeSyncObject object]];
    }
    [realm commitWriteTransaction];
    // Wait for upload to begin and finish
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    [token invalidate];
    // The notifier should have been called at least twice: once at the beginning and at least once
    // to report progress.
    XCTAssert(callCount > 1);
    XCTAssert(transferred >= transferrable,
              @"Transferred (%@) needs to be greater than or equal to transferrable (%@)",
              @(transferred), @(transferrable));
}

#pragma mark - Download Realm

- (void)testDownloadRealm {
    [self verifyDownloadRealmWithUsername:NSStringFromSelector(_cmd) relamURL:REALM_URL() simulateReconnection:NO];
}

- (void)testDownloadRealmWithReconnection {
    [self verifyDownloadRealmWithUsername:NSStringFromSelector(_cmd) relamURL:REALM_URL() simulateReconnection:YES];
}

- (void)verifyDownloadRealmWithUsername:(NSString *)username
                               relamURL:(NSURL *)url
                   simulateReconnection:(BOOL)simulateReconnection {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:username
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    if (self.isParent) {
        // Wait for the child process to upload everything.
        RLMRunChildAndWait();
        if (simulateReconnection) {
            [self disableNetworking];
            [self enableNetworkingAfter:20];
        }
        XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
        RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
        RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
        c.syncConfiguration = syncConfig;
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);
        [RLMRealm asyncOpenWithConfiguration:c
                               callbackQueue:dispatch_get_main_queue()
                                    callback:^(RLMRealm * _Nullable realm, NSError * _Nullable error) {
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
        NSUInteger sizeBefore = fileSize(c.pathOnDisk);
        @autoreleasepool {
            // We have partial transaction logs but no data
            XCTAssertGreaterThan(sizeBefore, 0U);
            XCTAssertTrue([[RLMRealm realmWithConfiguration:c error:nil] isEmpty]);
        }
        XCTAssertNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
        if (simulateReconnection) {
            [self waitForExpectationsWithTimeout:60.0 handler:nil];
        } else {
            [self waitForExpectationsWithTimeout:10.0 handler:nil];
        }
        XCTAssertGreaterThan(fileSize(c.pathOnDisk), sizeBefore);
        XCTAssertNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    } else {
        if (simulateReconnection) {
            [self disableNetworking];
            [self enableNetworkingAfter:20];
        }
        RLMRealm *realm = [self immediatelyOpenRealmForURL:url
                                                      user:user
                                             encryptionKey:nil
                                                stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
        // Write lots of data to the Realm, then wait for it to be uploaded.
        [realm beginWriteTransaction];
        for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
            [realm addObject:[HugeSyncObject object]];
        }
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:url timeout:simulateReconnection ? 20.0 : 60.0 error:nil];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    }
}

- (void)testDownloadAlreadyOpenRealm {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    if (self.isParent) {
        // Wait for the child process to upload everything.
        RLMRunChildAndWait();
        XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
        XCTestExpectation *ex2 = [self expectationWithDescription:@"wait for downloads after asyncOpen"];
        RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
        RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
        c.syncConfiguration = syncConfig;
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);
        RLMRealm *realm = [RLMRealm realmWithConfiguration:c error:nil];
        CHECK_COUNT(0, HugeSyncObject, realm);
        [RLMRealm asyncOpenWithConfiguration:c
                               callbackQueue:dispatch_get_main_queue()
                                    callback:^(RLMRealm * _Nullable realm, NSError * _Nullable error) {
            XCTAssertNil(error);
            // The big objects might take some time for the server to process,
            // so we may need to ask it a few times before it's ready.
            CHECK_COUNT_PENDING_DOWNLOAD_CUSTOM_EXPECTATION(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm, ex2);
            [ex fulfill];
        }];
        NSUInteger (^fileSize)(NSString *) = ^NSUInteger(NSString *path) {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            if (attributes)
                return [(NSNumber *)attributes[NSFileSize] unsignedLongLongValue];

            return 0;
        };
        NSUInteger sizeBefore = fileSize(c.pathOnDisk);
        XCTAssertGreaterThan(sizeBefore, 0U);
        XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
        [self waitForExpectationsWithTimeout:10.0 handler:nil];
        XCTAssertGreaterThan(fileSize(c.pathOnDisk), sizeBefore);
        XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Write lots of data to the Realm, then wait for it to be uploaded.
        [realm beginWriteTransaction];
        for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
            [realm addObject:[HugeSyncObject object]];
        }
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    }
}

- (void)testDownloadWhileOpeningRealm {
    const NSInteger NUMBER_OF_BIG_OBJECTS = 2;
    NSURL *url = REALM_URL();
    // Log in the user.
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:self.isParent]
                                               server:[RLMObjectServerTests authServerURL]];
    if (self.isParent) {
        // Wait for the child process to upload everything.
        RLMRunChildAndWait();
        XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
        RLMRealmConfiguration *c = [RLMRealmConfiguration defaultConfiguration];
        RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:url];
        c.syncConfiguration = syncConfig;
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);
        [RLMRealm asyncOpenWithConfiguration:c
                               callbackQueue:dispatch_get_main_queue()
                                    callback:^(RLMRealm * _Nullable realm, NSError * _Nullable error) {
            XCTAssertNil(error);
            CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
            [ex fulfill];
        }];
        RLMRealm *realm = [RLMRealm realmWithConfiguration:c error:nil];
        CHECK_COUNT(0, HugeSyncObject, realm);
        XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
        [self waitForExpectationsWithTimeout:10.0 handler:nil];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
        XCTAssertNotNil(RLMGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    } else {
        RLMRealm *realm = [self openRealmForURL:url user:user];
        // Write lots of data to the Realm, then wait for it to be uploaded.
        [realm beginWriteTransaction];
        for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
            [realm addObject:[HugeSyncObject object]];
        }
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:url];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    }
}

#pragma mark - Validation

- (void)testCompactOnLaunchCannotBeSet {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:REALM_URL()];

    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.syncConfiguration = syncConfig;
    RLMAssertThrowsWithReasonMatching(configuration.shouldCompactOnLaunch = ^BOOL(NSUInteger, NSUInteger){ return NO; },
                                      @"Cannot set `shouldCompactOnLaunch` when `syncConfiguration` is set.");
}

#pragma mark - Offline Client Reset

- (void)testOfflineClientReset {
    RLMSyncUser *user = [self logInUserForCredentials:[RLMObjectServerTests basicCredentialsWithName:NSStringFromSelector(_cmd)
                                                                                            register:YES]
                                               server:[RLMObjectServerTests authServerURL]];
    RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:REALM_URL()];

    NSURL *sourceFileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"sync-1.x" withExtension:@"realm"];
    NSString *fileName = [NSString stringWithFormat:@"%@.realm", [NSUUID new]];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    [[NSFileManager defaultManager] copyItemAtURL:sourceFileURL toURL:fileURL error:nullptr];
    syncConfig.customFileURL = fileURL;

    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.syncConfiguration = syncConfig;

    NSError *error;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:&error];
    XCTAssertNil(realm);
    XCTAssertEqualObjects(error.domain, RLMErrorDomain);
    XCTAssertEqual(error.code, RLMErrorIncompatibleSyncedFile);
    RLMRealmConfiguration *backupConfiguration = error.userInfo[RLMBackupRealmConfigurationErrorKey];
    XCTAssertNotNil(backupConfiguration);

    // Open the backup Realm with a schema subset since it was created using the schema from .NET's unit tests.
    // The Person class is declared in SwiftObjectServerTests.swift.
    backupConfiguration.objectClasses = @[ NSClassFromString(@"Person") ];

    error = nil;
    RLMRealm *backupRealm = [RLMRealm realmWithConfiguration:backupConfiguration error:&error];
    XCTAssertNotNil(backupRealm);
    XCTAssertNil(error);

    RLMResults *people = [backupRealm allObjects:@"Person"];
    XCTAssertEqual(people.count, 1u);
    XCTAssertEqualObjects([people[0] valueForKey:@"FirstName"], @"John");
    XCTAssertEqualObjects([people[0] valueForKey:@"LastName"], @"Smith");

    error = nil;
    realm = [RLMRealm realmWithConfiguration:configuration error:&error];
    XCTAssertNotNil(realm);
    XCTAssertNil(error);
}

#pragma mark - Partial sync

- (void)testPartialSync {
    // Make credentials.
    NSString *name = NSStringFromSelector(_cmd);
    NSURL *server = [RLMObjectServerTests authServerURL];
    NSURL *realmURL = REALM_URL();

    // Log in and populate the Realm.
    @autoreleasepool {
        RLMSyncCredentials *creds = [RLMObjectServerTests basicCredentialsWithName:name register:YES];
        RLMSyncUser *user = [self logInUserForCredentials:creds server:server];
        RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:realmURL];
        RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
        configuration.syncConfiguration = syncConfig;
        RLMRealm *realm = [self openRealmForURL:realmURL user:user];
        [realm beginWriteTransaction];
        // FIXME: make this less hideous
        // Add ten of each object
        [realm addObject:[PartialSyncObjectA objectWithNumber:0 string:@"realm"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:1 string:@""]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:2 string:@""]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:3 string:@""]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:4 string:@"realm"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:5 string:@"sync"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:6 string:@"partial"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:7 string:@"partial"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:8 string:@"partial"]];
        [realm addObject:[PartialSyncObjectA objectWithNumber:9 string:@"partial"]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:0 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:1 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:2 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:3 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:4 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:5 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:6 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:7 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:8 firstString:@"" secondString:@""]];
        [realm addObject:[PartialSyncObjectB objectWithNumber:9 firstString:@"" secondString:@""]];
        [realm commitWriteTransaction];
        [self waitForUploadsForUser:user url:realmURL];
    }

    // Log back in and do partial sync stuff.
    @autoreleasepool {
        RLMSyncCredentials *creds = [RLMObjectServerTests basicCredentialsWithName:name register:NO];
        RLMSyncUser *user = [self logInUserForCredentials:creds server:server];
        RLMSyncConfiguration *syncConfig = [[RLMSyncConfiguration alloc] initWithUser:user realmURL:realmURL];
        syncConfig.isPartial = YES;
        RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
        configuration.syncConfiguration = syncConfig;
        RLMRealm *realm = [self openRealmWithConfiguration:configuration];

        // Perform some partial sync queries
        RLMResults *objects = [PartialSyncObjectA objectsInRealm:realm where:@"number > 5"];
        RLMSyncSubscription *subscription = [objects subscribeWithName:@"query"];

        // Wait for the results to become available.
        XCTestExpectation *ex = [[XCTKVOExpectation alloc] initWithKeyPath:@"state" object:subscription expectedValue:@(RLMSyncSubscriptionStateComplete)];
        [self waitForExpectations:@[ex] timeout:20.0];

        // Verify that we got what we're looking for
        XCTAssertEqual(objects.count, 4U);
        for (PartialSyncObjectA *object in objects) {
            XCTAssertGreaterThan(object.number, 5);
            XCTAssertEqualObjects(object.string, @"partial");
        }

        // Verify that we didn't get any other objects
        XCTAssertEqual([PartialSyncObjectA allObjectsInRealm:realm].count, objects.count);
        XCTAssertEqual([PartialSyncObjectB allObjectsInRealm:realm].count, 0u);


        // Create a subscription with the same name but a different query. This should trigger an error.
        RLMResults *objects2 = [PartialSyncObjectA objectsInRealm:realm where:@"number < 5"];
        RLMSyncSubscription *subscription2 = [objects2 subscribeWithName:@"query"];

        // Wait for the error to be reported.
        XCTestExpectation *ex2 = [[XCTKVOExpectation alloc] initWithKeyPath:@"state" object:subscription2 expectedValue:@(RLMSyncSubscriptionStateError)];
        [self waitForExpectations:@[ex2] timeout:20.0];
        XCTAssertNotNil(subscription2.error);

        // Unsubscribe from the query, and ensure that it correctly transitions to the invalidated state.
        [subscription unsubscribe];
        XCTestExpectation *ex3 = [[XCTKVOExpectation alloc] initWithKeyPath:@"state" object:subscription expectedValue:@(RLMSyncSubscriptionStateInvalidated)];
        [self waitForExpectations:@[ex3] timeout:20.0];
    }
}

@end
