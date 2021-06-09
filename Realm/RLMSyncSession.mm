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

#import "RLMSyncSession_Private.hpp"

#import "RLMApp.h"
#import "RLMRealm_Private.hpp"
#import "RLMSyncConfiguration_Private.hpp"
#import "RLMUser_Private.hpp"
#import "RLMSyncManager_Private.hpp"
#import "RLMSyncUtil_Private.hpp"

#import <realm/object-store/sync/async_open_task.hpp>
#import <realm/object-store/sync/sync_session.hpp>

using namespace realm;

@interface RLMSyncErrorActionToken () {
@public
    std::string _originalPath;
    BOOL _isValid;
}
@end

@interface RLMProgressNotificationToken() {
    uint64_t _token;
    std::weak_ptr<SyncSession> _session;
}
@end

@implementation RLMProgressNotificationToken

- (void)suppressNextNotification {
    // No-op, but implemented in case this token is passed to
    // `-[RLMRealm commitWriteTransactionWithoutNotifying:]`.
}

- (void)invalidate {
    if (auto session = _session.lock()) {
        session->unregister_progress_notifier(_token);
        _session.reset();
        _token = 0;
    }
}

- (void)dealloc {
    if (_token != 0) {
        NSLog(@"RLMProgressNotificationToken released without unregistering a notification. "
              @"You must hold on to the RLMProgressNotificationToken and call "
              @"-[RLMProgressNotificationToken invalidate] when you no longer wish to receive "
              @"progress update notifications.");
    }
}

- (nullable instancetype)initWithTokenValue:(uint64_t)token
                                    session:(std::shared_ptr<SyncSession>)session {
    if (token == 0) {
        return nil;
    }
    if (self = [super init]) {
        _token = token;
        _session = session;
        return self;
    }
    return nil;
}

@end

@interface RLMSyncSession ()
@property (class, nonatomic, readonly) dispatch_queue_t notificationsQueue;
@property (atomic, readwrite) RLMSyncConnectionState connectionState;
@end

@implementation RLMSyncSession

+ (dispatch_queue_t)notificationsQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("io.realm.sync.sessionsNotificationQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static RLMSyncConnectionState convertConnectionState(SyncSession::ConnectionState state) {
    switch (state) {
        case SyncSession::ConnectionState::Disconnected: return RLMSyncConnectionStateDisconnected;
        case SyncSession::ConnectionState::Connecting:   return RLMSyncConnectionStateConnecting;
        case SyncSession::ConnectionState::Connected:    return RLMSyncConnectionStateConnected;
    }
}

- (instancetype)initWithSyncSession:(std::shared_ptr<SyncSession> const&)session {
    if (self = [super init]) {
        _session = session;
        _connectionState = convertConnectionState(session->connection_state());
        // No need to save the token as RLMSyncSession always outlives the
        // underlying SyncSession
        session->register_connection_change_callback([=](auto, auto newState) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.connectionState = convertConnectionState(newState);
            });
        });
        return self;
    }
    return nil;
}

- (RLMSyncConfiguration *)configuration {
    if (auto session = _session.lock()) {
        return [[RLMSyncConfiguration alloc] initWithRawConfig:session->config()];
    }
    return nil;
}

- (NSURL *)realmURL {
    if (auto session = _session.lock()) {
        if (auto url = session->full_realm_url()) {
            return [NSURL URLWithString:@(url->c_str())];
        }
    }
    return nil;
}

- (RLMUser *)parentUser {
    if (auto session = _session.lock()) {
        if (auto app = session->user()->sync_manager()->app().lock()) {
            auto rlmApp = [RLMApp appWithId:@(app->config().app_id.data())];
            return [[RLMUser alloc] initWithUser:session->user() app:rlmApp];
        }
    }
    return nil;
}

- (RLMSyncSessionState)state {
    if (auto session = _session.lock()) {
        if (session->state() == SyncSession::PublicState::Inactive) {
            return RLMSyncSessionStateInactive;
        }
        return RLMSyncSessionStateActive;
    }
    return RLMSyncSessionStateInvalid;
}

- (void)suspend {
    if (auto session = _session.lock()) {
        session->log_out();
    }
}

- (void)resume {
    if (auto session = _session.lock()) {
        session->revive_if_needed();
    }
}

static std::function<void(std::error_code)> wrapCallback(dispatch_queue_t queue, void(^callback)(NSError *)) {
    queue = queue ?: dispatch_get_main_queue();
    return [=](std::error_code err) {
        NSError *error = err == std::error_code{} ? nil : make_sync_error(err);
        dispatch_async(queue, ^{
            callback(error);
        });
    };
}

- (BOOL)waitForUploadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback {
    if (auto session = _session.lock()) {
        session->wait_for_upload_completion(wrapCallback(queue, callback));
        return YES;
    }
    return NO;
}

- (BOOL)waitForDownloadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback {
    if (auto session = _session.lock()) {
        session->wait_for_download_completion(wrapCallback(queue, callback));
        return YES;
    }
    return NO;
}

static std::function<void(uint64_t, uint64_t)> wrapCallback(dispatch_queue_t queue, RLMProgressNotificationBlock block) {
    return [=](uint64_t transferred, uint64_t transferrable) {
        dispatch_async(queue, ^{
            @autoreleasepool {
                block(static_cast<NSUInteger>(transferred),
                      static_cast<NSUInteger>(transferrable));
            }
        });
    };
}

- (RLMProgressNotificationToken *)addProgressNotificationForDirection:(RLMSyncProgressDirection)direction
                                                                 mode:(RLMSyncProgressMode)mode
                                                                block:(RLMProgressNotificationBlock)block {
    if (auto session = _session.lock()) {
        dispatch_queue_t queue = RLMSyncSession.notificationsQueue;
        auto notifier_direction = (direction == RLMSyncProgressDirectionUpload
                                   ? SyncSession::NotifierType::upload
                                   : SyncSession::NotifierType::download);
        bool is_streaming = (mode == RLMSyncProgressModeReportIndefinitely);
        uint64_t token = session->register_progress_notifier(wrapCallback(queue, block),
                                                             notifier_direction, is_streaming);
        return [[RLMProgressNotificationToken alloc] initWithTokenValue:token session:std::move(session)];
    }
    return nil;
}

+ (void)immediatelyHandleError:(RLMSyncErrorActionToken *)token syncManager:(RLMSyncManager *)syncManager {
    if (!token->_isValid) {
        return;
    }
    token->_isValid = NO;

    [syncManager syncManager]->immediately_run_file_actions(std::move(token->_originalPath));
}

+ (nullable RLMSyncSession *)sessionForRealm:(RLMRealm *)realm {
    auto& config = realm->_realm->config().sync_config;
    if (!config) {
        return nil;
    }
    if (auto session = config->user->session_for_on_disk_path(realm->_realm->config().path)) {
        return [[RLMSyncSession alloc] initWithSyncSession:session];
    }
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<RLMSyncSession: %p> {\n"
            "\tstate = %d;\n"
            "\tconnectionState = %d;\n"
            "\trealmURL = %@;\n"
            "\tuser = %@;\n"
            "}",
            (__bridge void *)self,
            static_cast<int>(self.state),
            static_cast<int>(self.connectionState),
            self.realmURL,
            self.parentUser.identifier];
}

@end

// MARK: - Error action token

@implementation RLMSyncErrorActionToken

- (instancetype)initWithOriginalPath:(std::string)originalPath {
    if (self = [super init]) {
        _isValid = YES;
        _originalPath = std::move(originalPath);
        return self;
    }
    return nil;
}

@end

@implementation RLMAsyncOpenTask {
    bool _cancel;
    std::vector<std::function<void(uint64_t, uint64_t)>> _blocks;
}

- (void)addProgressNotificationOnQueue:(dispatch_queue_t)queue block:(RLMProgressNotificationBlock)block {
    @synchronized (self) {
        if (_task) {
            _task->register_download_progress_notifier(wrapCallback(queue, block));
        }
        else if (!_cancel) {
            _blocks.push_back(wrapCallback(queue, block));
        }
    }
}

- (void)addProgressNotificationBlock:(RLMProgressNotificationBlock)block {
    [self addProgressNotificationOnQueue:dispatch_get_main_queue() block:block];
}

- (void)cancel {
    @synchronized (self) {
        if (_task) {
            _task->cancel();
        }
        else {
            _cancel = true;
            _blocks.clear();
        }
    }
}

- (void)setTask:(std::shared_ptr<realm::AsyncOpenTask>)task {
    @synchronized (self) {
        _task = task;
        if (_cancel) {
            _task->cancel();
        }
        for (auto& block : _blocks) {
            _task->register_download_progress_notifier(std::move(block));
        }
        _blocks.clear();
    }
}
@end
