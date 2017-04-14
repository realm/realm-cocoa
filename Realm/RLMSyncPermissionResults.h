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

#import "RLMSyncUser.h"
#import "RLMRealm.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    RLMSyncPermissionResultsSortPropertyPath,
    RLMSyncPermissionResultsSortPropertyUserID,
} RLMSyncPermissionResultsSortProperty;

@class RLMSyncPermissionValue;

/**
 An object representing the results of a permissions query.

 Permissions results objects are thread-confined, and should not be shared across
 threads.
 */
@interface RLMSyncPermissionResults : NSObject<NSFastEnumeration>

/// The number of results contained within the object.
@property (nonatomic, readonly) NSInteger count;

/**
 Return the first permission, or nil if the collection is empty.
 */
- (nullable RLMSyncPermissionValue *)firstObject;

/**
 Return the last permission, or nil if the collection is empty.
 */
- (nullable RLMSyncPermissionValue *)lastObject;

/**
 Retrieve the permission value at the given index. Throws an exception if the index
 is out of bounds.
 */
- (RLMSyncPermissionValue *)objectAtIndex:(NSInteger)index;

/**
 Returns the index of the permission in the collection, or `NSNotFound` if the permission
 is not found in the collection.
 */
- (NSUInteger)indexOfObject:(RLMSyncPermissionValue *)object;

/**
 Register a notification block upon the results object. The block will be called
 whenever the contents of the results object changes.

 This method returns a token. Hold on to the token for as long as notifications
 are desired. Call `-stop` on the token to stop notifications, and before
 deallocating the token.
 */
- (RLMNotificationToken *)addNotificationBlock:(RLMPermissionStatusBlock)block;

#pragma mark - Queries

/**
 Return all permissions matching the given predicate in the collection.

 @note Valid properties to filter on are `path` and `userId`, as well as
       the boolean properties `mayRead`, `mayWrite`, and `mayManage`.
 */
- (RLMSyncPermissionResults *)objectsWithPredicate:(NSPredicate *)predicate;

/**
 Return a sorted `RLMSyncPermissionResults` from the collection, sorted based on
 the given property.
 */
- (RLMSyncPermissionResults *)sortedResultsUsingProperty:(RLMSyncPermissionResultsSortProperty)property
                                               ascending:(BOOL)ascending;

#pragma mark - Misc

/// :nodoc:
- (instancetype)init __attribute__((unavailable("RLMSyncPermissionResults cannot be created directly")));

/// :nodoc:
+ (instancetype)new __attribute__((unavailable("RLMSyncPermissionResults cannot be created directly")));

@end

NS_ASSUME_NONNULL_END
