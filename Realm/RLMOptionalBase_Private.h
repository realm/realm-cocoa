////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

#import <Realm/RLMOptionalBase.h>

NS_ASSUME_NONNULL_BEGIN

@class RLMObjectBase, RLMProperty;

/// :nodoc:
@interface RLMOptionalBase ()
- (instancetype)init;
@property (nonatomic, weak) RLMObjectBase *object NS_SWIFT_UNAVAILABLE("");
@property (nonatomic, unsafe_unretained) RLMProperty *property NS_SWIFT_UNAVAILABLE("");
@property (nonatomic, strong, nullable) id underlyingValue NS_REFINED_FOR_SWIFT;
@end

NS_ASSUME_NONNULL_END
