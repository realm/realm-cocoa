////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import "RLMApp_Private.hpp"

#import "RLMBSON_Private.hpp"
#import "RLMCredentials_Private.hpp"
#import "RLMEmailPasswordAuth.h"
#import "RLMIvarStorage.hpp"
#import "RLMPushClient_Private.hpp"
#import "RLMSyncManager_Private.hpp"
#import "RLMUser_Private.hpp"
#import "RLMUtil.hpp"

#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/sync/config.hpp>

#if !defined(REALM_COCOA_VERSION)
#import "RLMVersion.h"
#endif

using namespace realm;

#pragma mark CocoaNetworkTransport
namespace {
    /// Internal transport struct to bridge RLMNetworkingTransporting to the GenericNetworkTransport.
    class CocoaNetworkTransport : public realm::app::GenericNetworkTransport {
    public:
        CocoaNetworkTransport(id<RLMNetworkTransport> transport) : m_transport(transport) {};

        void send_request_to_server(const app::Request request,
                                    std::function<void(const app::Response)> completion) override {
            // Convert the app::Request to an RLMRequest
            auto rlmRequest = [RLMRequest new];
            rlmRequest.url = @(request.url.data());
            rlmRequest.body = @(request.body.data());
            NSMutableDictionary *headers = [NSMutableDictionary new];
            for (auto header : request.headers) {
                headers[@(header.first.data())] = @(header.second.data());
            }
            rlmRequest.headers = headers;
            rlmRequest.method = static_cast<RLMHTTPMethod>(request.method);
            rlmRequest.timeout = request.timeout_ms / 1000;

            // Send the request through to the Cocoa level transport
            [m_transport sendRequestToServer:rlmRequest completion:^(RLMResponse *response) {
                __block std::map<std::string, std::string> bridgingHeaders;
                [response.headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *) {
                    bridgingHeaders[key.UTF8String] = value.UTF8String;
                }];

                // Convert the RLMResponse to an app:Response and pass downstream to
                // the object store
                completion({
                    .body = response.body.UTF8String,
                    .headers = bridgingHeaders,
                    .http_status_code = static_cast<int>(response.httpStatusCode),
                    .custom_status_code = static_cast<int>(response.customStatusCode)
                });
            }];
        }

        id<RLMNetworkTransport> transport() const {
            return m_transport;
        }
    private:
        id<RLMNetworkTransport> m_transport;
    };
}

#pragma mark RLMAppConfiguration
@implementation RLMAppConfiguration {
    RLMIvar<realm::app::App::Config> _config;
}

- (instancetype)initWithConfig:(const realm::app::App::Config &)config {
    if (self = [super init]) {
        _config = config;
        return self;
    }

    return nil;
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<RLMNetworkTransport>)transport
                   localAppName:(nullable NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion {
    return [self initWithBaseURL:baseURL
                       transport:transport
                    localAppName:localAppName
                 localAppVersion:localAppVersion
         defaultRequestTimeoutMS:6000];
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<RLMNetworkTransport>)transport
                   localAppName:(NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion
        defaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS {
    if (self = [super init]) {
        self.baseURL = baseURL;
        self.transport = transport;
        self.localAppName = localAppName;
        self.localAppVersion = localAppVersion;
        self.defaultRequestTimeoutMS = defaultRequestTimeoutMS;

        _config->platform = "Realm Cocoa";

        RLMNSStringToStdString(_config->platform_version, [[NSProcessInfo processInfo] operatingSystemVersionString]);
        RLMNSStringToStdString(_config->sdk_version, REALM_COCOA_VERSION);
        return self;
    }
    return nil;
}

- (realm::app::App::Config&)config {
    return _config;
}

- (void)setAppId:(NSString *)appId {
    RLMNSStringToStdString(_config->app_id, appId);
}

- (NSString *)baseURL {
    if (_config->base_url) {
        return @(_config->base_url->c_str());
    }

    return nil;
}

- (void)setBaseURL:(nullable NSString *)baseURL {
    std::string base_url;
    RLMNSStringToStdString(base_url, baseURL);
    _config->base_url = base_url.empty() ? util::none : util::Optional(base_url);
    return;
}

- (id<RLMNetworkTransport>)transport {
    return static_cast<CocoaNetworkTransport*>(_config->transport_generator().get())->transport();
}

- (void)setTransport:(id<RLMNetworkTransport>)transport {
    if (transport) {
        _config->transport_generator = [transport]{
            return std::make_unique<CocoaNetworkTransport>(transport);
        };
    } else {
        _config->transport_generator = []{
            return std::make_unique<CocoaNetworkTransport>([RLMNetworkTransport new]);
        };
    }
}

- (NSString *)localAppName {
    if (_config->local_app_name) {
        return @((_config->base_url)->c_str());
    }

    return nil;
}

- (void)setLocalAppName:(nullable NSString *)localAppName {
    std::string local_app_name;
    RLMNSStringToStdString(local_app_name, localAppName);
    _config->local_app_name = local_app_name.empty() ? util::none : util::Optional(local_app_name);
    return;
}

- (NSString *)localAppVersion {
    if (_config->local_app_version) {
        return @(_config->base_url->c_str());
    }

    return nil;
}

- (void)setLocalAppVersion:(nullable NSString *)localAppVersion {
    std::string local_app_version;
    RLMNSStringToStdString(local_app_version, localAppVersion);
    _config->local_app_version = local_app_version.empty() ? util::none : util::Optional(local_app_version);
    return;
}

- (NSUInteger)defaultRequestTimeoutMS {
    return _config->default_request_timeout_ms.value_or(6000U);
}

- (void)setDefaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS {
    _config->default_request_timeout_ms = (uint64_t)defaultRequestTimeoutMS;
}

@end

NSError *RLMAppErrorToNSError(realm::app::AppError const& appError) {
    return [[NSError alloc] initWithDomain:@(appError.error_code.category().name())
                                      code:appError.error_code.value()
                                  userInfo:@{
                                      @(appError.error_code.category().name()) : @(appError.error_code.message().data()),
                                      NSLocalizedDescriptionKey : @(appError.message.c_str())
                                  }];
}

#pragma mark RLMAppSubscriptionToken
@implementation RLMAppSubscriptionToken {
@public
    std::unique_ptr<realm::Subscribable<app::App>::Token> _token;
}

- (instancetype)initWithToken:(realm::Subscribable<app::App>::Token&&)token {
    if (self = [super init]) {
        _token = std::make_unique<realm::Subscribable<app::App>::Token>(std::move(token));
        return self;
    }

    return nil;
}

- (NSUInteger)value {
    return _token->value();
}
@end

#pragma mark RLMApp
@interface RLMApp() <ASAuthorizationControllerDelegate> {
    std::shared_ptr<realm::app::App> _app;
    __weak id<RLMASLoginDelegate> _authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0));
}

@end

@implementation RLMApp : NSObject

- (instancetype)initWithApp:(std::shared_ptr<realm::app::App>)app {
    if (self = [super init]) {
        _configuration = [[RLMAppConfiguration alloc] initWithConfig:app->config()];
        _app = app;
        _syncManager = [[RLMSyncManager alloc] initWithSyncManager:_app->sync_manager()];
        return self;
    }

    return nil;
}

- (instancetype)initWithId:(NSString *)appId
             configuration:(RLMAppConfiguration *)configuration
             rootDirectory:(NSURL *)rootDirectory {
    if ([appId length] == 0) {
        @throw RLMException(@"AppId cannot be an empty string");
    }

    if (self = [super init]) {
        if (!configuration) {
            configuration = [[RLMAppConfiguration alloc] initWithBaseURL:nil
                                                               transport:nil
                                                            localAppName:nil
                                                         localAppVersion:nil];
        }
        _configuration = configuration;
        [_configuration setAppId:appId];

        _app = RLMTranslateError([&] {
            return app::App::get_shared_app(configuration.config,
                                            [RLMSyncManager configurationWithRootDirectory:rootDirectory appId:appId]);
        });

        _syncManager = [[RLMSyncManager alloc] initWithSyncManager:_app->sync_manager()];
        return self;
    }
    return nil;
}

static NSMutableDictionary *s_apps = [NSMutableDictionary new];
static std::mutex& s_appMutex = *new std::mutex();

+ (void)resetAppCache {
    std::lock_guard<std::mutex> lock(s_appMutex);
    [s_apps removeAllObjects];
    app::App::clear_cached_apps();
}

+ (instancetype)appWithId:(NSString *)appId
            configuration:(RLMAppConfiguration *)configuration
            rootDirectory:(NSURL *)rootDirectory {
    std::lock_guard<std::mutex> lock(s_appMutex);
    if (RLMApp *app = s_apps[appId]) {
        return app;
    }

    RLMApp *app = [[RLMApp alloc] initWithId:appId configuration:configuration rootDirectory:rootDirectory];
    s_apps[appId] = app;
    return app;
}

+ (instancetype)appWithId:(NSString *)appId configuration:(RLMAppConfiguration *)configuration {
    return [self appWithId:appId configuration:configuration rootDirectory:nil];
}

+ (instancetype)appWithId:(NSString *)appId {
    return [self appWithId:appId configuration:nil];
}

- (std::shared_ptr<realm::app::App>)_realmApp {
    return _app;
}

- (NSDictionary<NSString *, RLMUser *> *)allUsers {
    NSMutableDictionary *buffer = [NSMutableDictionary new];
    for (auto&& user : _app->sync_manager()->all_users()) {
        NSString *identity = @(user->identity().c_str());
        buffer[identity] = [[RLMUser alloc] initWithUser:std::move(user) app:self];
    }
    return buffer;
}

- (RLMUser *)currentUser {
    if (auto user = _app->sync_manager()->get_current_user()) {
        return [[RLMUser alloc] initWithUser:user app:self];
    }
    return nil;
}

- (RLMEmailPasswordAuth *)emailPasswordAuth {
    return [[RLMEmailPasswordAuth alloc] initWithApp: self];
}

- (void)loginWithCredential:(RLMCredentials *)credentials
                 completion:(RLMUserCompletionBlock)completionHandler {
    auto completion = ^(std::shared_ptr<SyncUser> user, util::Optional<app::AppError> error) {
        if (error && error->error_code) {
            return completionHandler(nil, RLMAppErrorToNSError(*error));
        }

        completionHandler([[RLMUser alloc] initWithUser:user app:self], nil);
    };
    return RLMTranslateError([&] {
        return _app->log_in_with_credentials(credentials.appCredentials, completion);
    });
}

- (RLMUser *)switchToUser:(RLMUser *)syncUser {
    return RLMTranslateError([&] {
        return [[RLMUser alloc] initWithUser:_app->switch_user(syncUser._syncUser) app:self];
    });
}

- (RLMPushClient *)pushClientWithServiceName:(NSString *)serviceName {
    return RLMTranslateError([&] {
        return [[RLMPushClient alloc] initWithPushClient:_app->push_notification_client(serviceName.UTF8String)];
    });
}

#pragma mark - Sign In With Apple Extension

- (void)setAuthorizationDelegate:(id<RLMASLoginDelegate>)authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    _authorizationDelegate = authorizationDelegate;
}

- (id<RLMASLoginDelegate>)authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    return _authorizationDelegate;
}

- (void)setASAuthorizationControllerDelegateForController:(ASAuthorizationController *)controller API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    controller.delegate = self;
}

- (void)authorizationController:(__unused ASAuthorizationController *)controller
   didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    NSString *jwt = [[NSString alloc] initWithData:((ASAuthorizationAppleIDCredential *)authorization.credential).identityToken
                                             encoding:NSUTF8StringEncoding];
       [self loginWithCredential:[RLMCredentials credentialsWithAppleToken:jwt]
                      completion:^(RLMUser *user, NSError *error) {
           if (user) {
               [self.authorizationDelegate authenticationDidCompleteWithUser:user];
           } else {
               [self.authorizationDelegate authenticationDidCompleteWithError:error];
           }
       }];
}

- (void)authorizationController:(__unused ASAuthorizationController *)controller
           didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    [self.authorizationDelegate authenticationDidCompleteWithError:error];
}

- (RLMAppSubscriptionToken *)subscribe:(RLMAppNotificationBlock)block {
    return [[RLMAppSubscriptionToken alloc] initWithToken:_app->subscribe([block, self] (auto&) {
        block(self);
    })];
}

- (void)unsubscribe:(RLMAppSubscriptionToken *)token {
    return _app->unsubscribe(*token->_token);
}

@end


