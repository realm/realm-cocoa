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

#import <Foundation/Foundation.h>

#import <Realm/RLMOptionalBase.h>

@protocol RLMInt;

NS_ASSUME_NONNULL_BEGIN

/**
 A `RLMInteger` represents an integer property on a `RLMObject` subclass
 that supports advanced Realm-specific functionality.

 `RLMInteger` properties are backed by integer columns within the underlying
 database, and are treated the same as normal 64-bit integer properties. No
 migration is required to go change a property of `NSNumber<RLMInt>` or `int`
 type into one of `RLMInteger` type, or vice versa; however, nullability must
 be preserved.

 A `RLMInteger` property normally represents an optional integer; it can be
 defined to represent a required integer by including the property's name in
 the array returned by the model object's `requiredProperties` class method.

 You may either work with the APIs of a `RLMInteger` instance, or you may
 directly assign to a `RLMInteger` property on a model object. If a
 `RLMInteger` is directly assigned to, it takes on the integer value of
 the other `RLMInteger` instance at the time the assignment takes place.
 */
@interface RLMInteger : RLMOptionalBase

/**
 Increment the value of the integer. Both negative and positive values can
 be passed in.

 Prefer incrementing an integer value using this API over getting, locally
 incrementing, and setting the integer value. This API allows the value to
 be incremented in a way that guarantees that the change will not be lost,
 even if other clients are incrementing the value and pushing their changes
 to a Realm Object Server, as long as the value is not also being set using
 the `value` property.

 @warning If the object the integer belongs to is managed, this method must
          only be called within a write transaction.

 @warning If the value of the integer is nil, an exception will be thrown.
 */
- (void)incrementValueBy:(NSInteger)delta;

/**
 The boxed value of the integer.

 Note that in the context of sync, setting the value of the integer may
 cause increment operations from other clients to be lost or ignored,
 depending on how any conflicts are resolved.
 */
@property (nonatomic, nullable) NSNumber<RLMInt> *value NS_REFINED_FOR_SWIFT;

/**
 Create a new instance set to the provided numeric value.
 */
- (instancetype)initWithValue:(nullable NSNumber<RLMInt> *)value NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
