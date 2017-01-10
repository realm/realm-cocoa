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

#import "RLMHandover.h"
#import "thread_confined.hpp"

@class RLMRealm;

NS_ASSUME_NONNULL_BEGIN

@protocol RLMThreadConfined_Private

@property (readonly) realm::AnyThreadConfined rlm_handoverData;
@property (readonly, nullable) id rlm_handoverMetadata;
+ (instancetype)rlm_objectWithHandoverData:(realm::AnyThreadConfined&)data
                                  metadata:(nullable id)metadata inRealm:(RLMRealm *)realm;

@end

@interface RLMThreadHandover ()

- (instancetype)initWithRealm:(RLMRealm *)realm objects:(NSArray<id<RLMThreadConfined>> *)objects;

@end

NS_ASSUME_NONNULL_END
