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

#import "RLMSyncConfiguration_Private.h"

#import <functional>
#import <memory>

namespace realm {
class SyncSession;
struct SyncConfig;
struct SyncError;
using SyncSessionErrorHandler = void(std::shared_ptr<SyncSession>, SyncError);
}

NS_ASSUME_NONNULL_BEGIN

@interface RLMSyncConfiguration ()

- (instancetype)initWithUser:(RLMUser *)user
              partitionValue:(id<RLMBSON>)partitionValue
               customFileURL:(nullable NSURL *)customFileURL
                  stopPolicy:(RLMSyncStopPolicy)stopPolicy;

- (instancetype)initWithRawConfig:(realm::SyncConfig)config RLM_OBJC_DIRECT;

- (realm::SyncConfig&)rawConfiguration RLM_OBJC_DIRECT;

@end

NS_ASSUME_NONNULL_END
