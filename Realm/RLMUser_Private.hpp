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

#import "RLMUser_Private.h"

#import "RLMSyncConfiguration.h"
#import "RLMSyncUtil_Private.h"

#import <realm/object-store/sync/sync_user.hpp>
#import <realm/sync/config.hpp>

@class RLMSyncConfiguration, RLMSyncSessionRefreshHandle, RLMApp;

NS_ASSUME_NONNULL_BEGIN

class CocoaSyncUserContext : public realm::SyncUserContext {
public:

private:
    /**
     A map of paths to 'refresh handles'.

     A refresh handle is an object that encapsulates the concept of periodically
     refreshing the Realm's access token before it expires. Tokens are indexed by their
     paths (e.g. `/~/path/to/realm`).
     */
    std::unordered_map<std::string, RLMSyncSessionRefreshHandle *> m_refresh_handles;
    std::mutex m_mutex;
};

@interface RLMUser ()
- (instancetype)initWithUser:(std::shared_ptr<realm::SyncUser>)user app:(RLMApp *)app RLM_OBJC_DIRECT;
- (std::string)pathForPartitionValue:(std::string const&)partitionValue RLM_OBJC_DIRECT;
- (std::shared_ptr<realm::SyncUser>)_syncUser RLM_OBJC_DIRECT;
+ (void)_setUpBindingContextFactory;
@property (weak, readonly) RLMApp *app;

@end

NS_ASSUME_NONNULL_END
