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

#import "RLMThreadSafeReference.h"

#import <Realm/RLMConstants.h>

#import <realm/object-store/thread_safe_reference.hpp>

NS_ASSUME_NONNULL_BEGIN

@protocol RLMThreadConfined_Private <NSObject>

// Constructs a new `ThreadSafeReference`
- (realm::ThreadSafeReference)makeThreadSafeReference;

// The extra information needed to construct an instance of this type from the Object Store type
@property (nonatomic, readonly, nullable) id objectiveCMetadata;

// Constructs an new instance of this type
+ (nullable instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                              metadata:(nullable id)metadata
                                                 realm:(RLMRealm *)realm;
@end

@interface RLMThreadSafeReference ()

- (nullable id<RLMThreadConfined>)resolveReferenceInRealm:(RLMRealm *)realm RLM_OBJC_DIRECT;

@end

NS_ASSUME_NONNULL_END
