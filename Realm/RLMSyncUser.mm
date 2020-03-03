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

#import "RLMSyncUser_Private.hpp"

#import "RLMJSONModels.h"
#import "RLMNetworkClient.h"
#import "RLMRealmConfiguration+Sync.h"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMRealmUtil.hpp"
#import "RLMResults_Private.hpp"
#import "RLMSyncConfiguration.h"
#import "RLMSyncConfiguration_Private.hpp"
#import "RLMSyncManager_Private.h"
#import "RLMSyncSessionRefreshHandle.hpp"
#import "RLMSyncSession_Private.hpp"
#import "RLMSyncUtil_Private.hpp"
#import "RLMUtil.hpp"

#import "sync/sync_manager.hpp"
#import "sync/sync_session.hpp"
#import "sync/sync_user.hpp"

using namespace realm;

void CocoaSyncUserContext::register_refresh_handle(const std::string& path, RLMSyncSessionRefreshHandle *handle)
{
    REALM_ASSERT(handle);
    std::lock_guard<std::mutex> lock(m_mutex);
    auto& refresh_handle = m_refresh_handles[path];
    [refresh_handle invalidate];
    refresh_handle = handle;
}

void CocoaSyncUserContext::unregister_refresh_handle(const std::string& path)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_refresh_handles.erase(path);
}

void CocoaSyncUserContext::invalidate_all_handles()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    for (auto& it : m_refresh_handles) {
        [it.second invalidate];
    }
    m_refresh_handles.clear();
}

RLMUserErrorReportingBlock CocoaSyncUserContext::error_handler() const
{
    std::lock_guard<std::mutex> lock(m_error_handler_mutex);
    return m_error_handler;
}

void CocoaSyncUserContext::set_error_handler(RLMUserErrorReportingBlock block)
{
    std::lock_guard<std::mutex> lock(m_error_handler_mutex);
    m_error_handler = block;
}

@interface RLMSyncUserInfo ()

@property (nonatomic, readwrite) NSArray *accounts;
@property (nonatomic, readwrite) NSDictionary *metadata;
@property (nonatomic, readwrite) NSString *identity;
@property (nonatomic, readwrite) BOOL isAdmin;

+ (instancetype)syncUserInfoWithModel:(RLMUserResponseModel *)model;

@end

@interface RLMSyncUser () {
    std::shared_ptr<SyncUser> _user;
}
@end

@implementation RLMSyncUser

#pragma mark - static API

+ (NSDictionary *)allUsers {
    NSArray *allUsers = [[RLMSyncManager sharedManager] _allUsers];
    return [NSDictionary dictionaryWithObjects:allUsers
                                       forKeys:[allUsers valueForKey:@"identity"]];
}

+ (RLMSyncUser *)currentUser {
    NSArray *allUsers = [[RLMSyncManager sharedManager] _allUsers];
    if (allUsers.count > 1 && [NSSet setWithArray:[allUsers valueForKey:@"identity"]].count > 1) {
        @throw RLMException(@"+currentUser cannot be called if more that one valid, logged-in user exists.");
    }
    return allUsers.firstObject;
}

#pragma mark - API

- (instancetype)initWithSyncUser:(std::shared_ptr<SyncUser>)user {
    if (self = [super init]) {
        _user = user;
        return self;
    }
    return nil;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[RLMSyncUser class]]) {
        return NO;
    }
    return _user == ((RLMSyncUser *)object)->_user;
}

- (RLMRealmConfiguration *)configuration {
    return [self configurationWithURL:nil
                  enableSSLValidation:YES
                            urlPrefix:nil];
}

- (RLMRealmConfiguration *)configurationWithURL:(NSURL *)url {
    return [self configurationWithURL:url
                  enableSSLValidation:YES
                            urlPrefix:nil];
}

- (RLMRealmConfiguration *)configurationWithURL:(NSURL *)url
                            enableSSLValidation:(bool)enableSSLValidation
                                      urlPrefix:(NSString * _Nullable)urlPrefix {
    auto syncConfig = [[RLMSyncConfiguration alloc] initWithUser:self
                                                        realmURL:url ?: self.defaultRealmURL
                                                   customFileURL:nil stopPolicy:RLMSyncStopPolicyAfterChangesUploaded];
    syncConfig.urlPrefix = urlPrefix;
    syncConfig.enableSSLValidation = enableSSLValidation;
    syncConfig.pinnedCertificateURL = RLMSyncManager.sharedManager.pinnedCertificatePaths[syncConfig.realmURL.host];
    RLMRealmConfiguration *config = [[RLMRealmConfiguration alloc] init];
    config.syncConfiguration = syncConfig;
    return config;
}

- (void)logOut {
    if (!_user) {
        return;
    }
    _user->log_out();
    context_for(_user).invalidate_all_handles();
}

- (void)invalidate {
    if (!_user) {
        return;
    }
    context_for(_user).invalidate_all_handles();
    _user = nullptr;
}

- (RLMUserErrorReportingBlock)errorHandler {
    if (!_user) {
        return nil;
    }
    return context_for(_user).error_handler();
}

- (void)setErrorHandler:(RLMUserErrorReportingBlock)errorHandler {
    if (!_user) {
        return;
    }
    context_for(_user).set_error_handler([errorHandler copy]);
}

- (nullable RLMSyncSession *)sessionForURL:(NSURL *)url {
    if (!_user) {
        return nil;
    }
    auto path = SyncManager::shared().path_for_realm(*_user, [url.absoluteString UTF8String]);
    if (auto session = _user->session_for_on_disk_path(path)) {
        return [[RLMSyncSession alloc] initWithSyncSession:session];
    }
    return nil;
}

- (NSArray<RLMSyncSession *> *)allSessions {
    if (!_user) {
        return @[];
    }
    NSMutableArray<RLMSyncSession *> *buffer = [NSMutableArray array];
    auto sessions = _user->all_sessions();
    for (auto session : sessions) {
        [buffer addObject:[[RLMSyncSession alloc] initWithSyncSession:std::move(session)]];
    }
    return [buffer copy];
}

- (NSString *)identity {
    if (!_user) {
        return nil;
    }
    return @(_user->identity().c_str());
}

- (RLMSyncUserState)state {
    if (!_user) {
        return RLMSyncUserStateError;
    }
    switch (_user->state()) {
        case SyncUser::State::Active:
            return RLMSyncUserStateActive;
        case SyncUser::State::LoggedOut:
            return RLMSyncUserStateLoggedOut;
        case SyncUser::State::Error:
            return RLMSyncUserStateError;
    }
}

- (NSURL *)authenticationServer {
    if (!_user) {
        return nil;
    }
    return [NSURL URLWithString:@(_user->server_url().c_str())];
}

#pragma mark - Passwords

- (void)changePassword:(NSString *)newPassword completion:(RLMPasswordChangeStatusBlock)completion {
    [self changePassword:newPassword forUserID:self.identity completion:completion];
}

- (void)changePassword:(NSString *)newPassword forUserID:(NSString *)userID completion:(RLMPasswordChangeStatusBlock)completion {
    if (self.state != RLMSyncUserStateActive) {
        completion([NSError errorWithDomain:RLMSyncErrorDomain
                                       code:RLMSyncErrorClientSessionError
                                   userInfo:nil]);
        return;
    }
    [RLMSyncChangePasswordEndpoint sendRequestToServer:self.authenticationServer
                                       JSON:@{kRLMSyncTokenKey: self.refreshToken,
                                              kRLMSyncUserIDKey: userID,
                                              kRLMSyncDataKey: @{kRLMSyncNewPasswordKey: newPassword}}
                                 completion:completion];
}

+ (void)requestPasswordResetForAuthServer:(NSURL *)serverURL
                                userEmail:(NSString *)email
                               completion:(RLMPasswordChangeStatusBlock)completion {
    [RLMSyncUpdateAccountEndpoint sendRequestToServer:serverURL
                                                 JSON:@{@"provider_id": email, @"data": @{@"action": @"reset_password"}}
                                           completion:completion];
}

+ (void)completePasswordResetForAuthServer:(NSURL *)serverURL
                                     token:(NSString *)token
                                  password:(NSString *)newPassword
                                completion:(RLMPasswordChangeStatusBlock)completion {
    [RLMSyncUpdateAccountEndpoint sendRequestToServer:serverURL
                                                 JSON:@{@"data": @{@"action": @"complete_reset",
                                                                   @"token": token,
                                                                   @"new_password": newPassword}}
                                           completion:completion];
}

+ (void)requestEmailConfirmationForAuthServer:(NSURL *)serverURL
                                    userEmail:(NSString *)email
                                   completion:(RLMPasswordChangeStatusBlock)completion {
    [RLMSyncUpdateAccountEndpoint sendRequestToServer:serverURL
                                                 JSON:@{@"provider_id": email,
                                                        @"data": @{@"action": @"request_email_confirmation"}}
                                           completion:completion];
}

+ (void)confirmEmailForAuthServer:(NSURL *)serverURL
                            token:(NSString *)token
                       completion:(RLMPasswordChangeStatusBlock)completion {
    [RLMSyncUpdateAccountEndpoint sendRequestToServer:serverURL
                                                 JSON:@{@"data": @{@"action": @"confirm_email",
                                                                   @"token": token}}
                                           completion:completion];
}

#pragma mark - Administrator API

- (void)retrieveInfoForUser:(NSString *)providerUserIdentity
           identityProvider:(RLMIdentityProvider)provider
                 completion:(RLMRetrieveUserBlock)completion {
    [RLMSyncGetUserInfoEndpoint sendRequestToServer:self.authenticationServer
                                               JSON:@{kRLMSyncProviderKey: provider,
                                                      kRLMSyncProviderIDKey: providerUserIdentity,
                                                      kRLMSyncTokenKey: self.refreshToken}
                                            timeout:60
                                         completion:^(NSError *error, NSDictionary *json) {
        if (error) {
            return completion(nil, error);
        }
        RLMUserResponseModel *model = [[RLMUserResponseModel alloc] initWithDictionary:json];
        if (!model) {
            return completion(nil, make_auth_error_bad_response(json));
        }
        completion([RLMSyncUserInfo syncUserInfoWithModel:model], nil);
    }];
}

#pragma mark - Private API

- (NSURL *)urlForPath:(nullable NSString *)path {
    if (!path) {
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:self.authenticationServer resolvingAgainstBaseURL:YES];
    if ([components.scheme caseInsensitiveCompare:@"http"] == NSOrderedSame)
        components.scheme = @"realm";
    else if ([components.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)
        components.scheme = @"realms";
    else
        @throw RLMException(@"The provided user's authentication server URL (%@) was not valid.", self.authenticationServer);

    components.path = path;
    return components.URL;

}

- (NSURL *)defaultRealmURL {
    return [self urlForPath:@"/default"];
}

+ (void)_setUpBindingContextFactory {
    SyncUser::set_binding_context_factory([] {
        return std::make_shared<CocoaSyncUserContext>();
    });
}

- (NSString *)refreshToken {
    if (!_user) {
        return nil;
    }
    return @(_user->refresh_token().c_str());
}

- (std::shared_ptr<SyncUser>)_syncUser {
    return _user;
}

@end

#pragma mark - RLMSyncUserInfo

@implementation RLMSyncUserInfo

- (instancetype)initPrivate {
    return [super init];
}

+ (instancetype)syncUserInfoWithModel:(RLMUserResponseModel *)model {
    RLMSyncUserInfo *info = [[RLMSyncUserInfo alloc] initPrivate];
    info.accounts = model.accounts;
    info.metadata = model.metadata;
    info.isAdmin = model.isAdmin;
    info.identity = model.identity;
    return info;
}

@end
