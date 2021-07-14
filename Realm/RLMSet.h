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

#import <Realm/RLMCollection.h>

NS_ASSUME_NONNULL_BEGIN

@class RLMObject, RLMResults<RLMObjectType>;

/**
 A collection datatype used for storing distinct objects.

 - Note:
 `RLMSet` supports storing primitive and `RLMObject` types. `RLMSet` does not support storing
 Embedded Realm Objects.
 */
@interface RLMSet<RLMObjectType> : NSObject<RLMCollection>

#pragma mark - Properties

/**
 The number of objects in the set.
 */
@property (nonatomic, readonly, assign) NSUInteger count;

/**
 The type of the objects in the set.
 */
@property (nonatomic, readonly, assign) RLMPropertyType type;

/**
 Indicates whether the objects in the collection can be `nil`.
 */
@property (nonatomic, readonly, getter = isOptional) BOOL optional;

/**
 The objects in the RLMSet as an NSArray value.
 */
@property (nonatomic, readonly) NSArray<RLMObjectType> *allObjects;

/**
 The class name of the objects contained in the set.

 Will be `nil` if `type` is not RLMPropertyTypeObject.
 */
@property (nonatomic, readonly, copy, nullable) NSString *objectClassName;

/**
 The Realm which manages the set. Returns `nil` for unmanaged set.
 */
@property (nonatomic, readonly, nullable) RLMRealm *realm;

/**
 Indicates if the set can no longer be accessed.
 */
@property (nonatomic, readonly, getter = isInvalidated) BOOL invalidated;

/**
 Indicates if the set is frozen.

 Frozen sets are immutable and can be accessed from any thread. Frozen sets
 are created by calling `-freeze` on a managed live set. Unmanaged sets are
 never frozen.
 */
@property (nonatomic, readonly, getter = isFrozen) BOOL frozen;

#pragma mark - Adding, Removing, and Replacing Objects in a Set

/**
 Adds an object to the set if it is not already present.

 @warning This method may only be called during a write transaction.

 @param object  An object of the type contained in the set.
 */
- (void)addObject:(RLMObjectType)object;

/**
 Adds an array of distinct objects to the set.

 @warning This method may only be called during a write transaction.

 @param objects     An enumerable object such as `NSArray`, `NSSet` or `RLMResults` which contains objects of the
                    same class as the set.
 */
- (void)addObjects:(id<NSFastEnumeration>)objects;

/**
 Removes a given object from the set.

 @warning This method may only be called during a write transaction.

 @param object The object in the set that you want to remove.
 */
- (void)removeObject:(RLMObjectType)object;

/**
 Removes all objects from the set.

 @warning This method may only be called during a write transaction.
 */
- (void)removeAllObjects;

/**
 Empties the receiving set, then adds each object contained in another given set.

 @warning This method may only be called during a write transaction.

 @param set The RLMSet whose members replace the receiving set's content.
 */
- (void)setSet:(RLMSet<RLMObjectType> *)set;

/**
 Removes from the receiving set each object that isn’t a member of another given set.

 @warning This method may only be called during a write transaction.

 @param set The RLMSet with which to perform the intersection.
 */
- (void)intersectSet:(RLMSet<RLMObjectType> *)set;

/**
 Removes each object in another given set from the receiving set, if present.

 @warning This method may only be called during a write transaction.

 @param set The set of objects to remove from the receiving set.
 */
- (void)minusSet:(RLMSet<RLMObjectType> *)set;

/**
 Adds each object in another given set to the receiving set, if not present.

 @warning This method may only be called during a write transaction.

 @param set The set of objects to add to the receiving set.
 */
- (void)unionSet:(RLMSet<RLMObjectType> *)set;

#pragma mark - Querying a Set

/// :nodoc:
- (RLMResults<RLMObjectType> *)objectsWhere:(NSString *)predicateFormat, ...;

/// :nodoc:
- (RLMResults<RLMObjectType> *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

/// :nodoc:
- (RLMResults<RLMObjectType> *)objectsWithPredicate:(NSPredicate *)predicate;

/// :nodoc:
- (RLMResults<RLMObjectType> *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending;

/// :nodoc:
- (RLMResults<RLMObjectType> *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties;

/// :nodoc:
- (RLMResults<RLMObjectType> *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths;

/**
 Returns a Boolean value that indicates whether at least one object in the receiving set is also present in another given set.

 @param set The RLMSet to compare the receiving set to.

 @return YES if at least one object in the receiving set is also present in otherSet, otherwise NO.
 */
- (BOOL)intersectsSet:(RLMSet<RLMObjectType> *)set;

/**
 Returns a Boolean value that indicates whether every object in the receiving set is also present in another given set.

 @param set The RLMSet to compare the receiving set to.

 @return YES if every object in the receiving set is also present in otherSet, otherwise NO.
 */
- (BOOL)isSubsetOfSet:(RLMSet<RLMObjectType> *)set;

/**
 Returns a Boolean value that indicates whether a given object is present in the set.

 @param anObject An object to look for in the set.

 @return YES if anObject is present in the set, otherwise NO.
 */
- (BOOL)containsObject:(RLMObjectType)anObject;

/**
 Compares the receiving set to another set.

 @param otherSet The set with which to compare the receiving set.

 @return YES if the contents of otherSet are equal to the contents of the receiving set, otherwise NO.
 */
- (BOOL)isEqualToSet:(RLMSet<RLMObjectType> *)otherSet;

#pragma mark - Notifications

/**
 Registers a block to be called each time the set changes.

 The block will be asynchronously called with the initial set, and then
 called again after each write transaction which changes any of the objects in
 the set, which objects are in the results, or the order of the objects in the
 set.

 The `changes` parameter will be `nil` the first time the block is called.
 For each call after that, it will contain information about
 which rows in the set were added, removed or modified. If a write transaction
 did not modify any objects in the set, the block is not called at all.
 See the `RLMCollectionChange` documentation for information on how the changes
 are reported and an example of updating a `UITableView`.

 If an error occurs the block will be called with `nil` for the results
 parameter and a non-`nil` error. Currently the only errors that can occur are
 when opening the Realm on the background worker thread.

 Notifications are delivered via the standard run loop, and so can't be
 delivered while the run loop is blocked by other activity. When
 notifications can't be delivered instantly, multiple notifications may be
 coalesced into a single notification. This can include the notification
 with the initial results. For example, the following code performs a write
 transaction immediately after adding the notification block, so there is no
 opportunity for the initial notification to be delivered first. As a
 result, the initial notification will reflect the state of the Realm after
 the write transaction.

     Person *person = [[Person allObjectsInRealm:realm] firstObject];
     NSLog(@"person.dogs.count: %zu", person.dogs.count); // => 0
     self.token = [person.dogs addNotificationBlock(RLMSet<Dog *> *dogs,
                                                    RLMCollectionChange *changes,
                                                    NSError *error) {
         // Only fired once for the example
         NSLog(@"dogs.count: %zu", dogs.count) // => 1
     }];
     [realm transactionWithBlock:^{
         Dog *dog = [[Dog alloc] init];
         dog.name = @"Rex";
         [person.dogs addObject:dog];
     }];
     // end of run loop execution context

 You must retain the returned token for as long as you want updates to continue
 to be sent to the block. To stop receiving updates, call `-invalidate` on the token.

 @warning This method cannot be called during a write transaction, or when the
          containing Realm is read-only.
 @warning This method may only be called on a non-frozen managed set.

 @param block The block to be called each time the set changes.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet<RLMObjectType> *_Nullable set,
                                                         RLMCollectionChange *_Nullable changes,
                                                         NSError *_Nullable error))block
__attribute__((warn_unused_result));

/**
 Registers a block to be called each time the set changes.

 The block will be asynchronously called with the initial set, and then
 called again after each write transaction which changes any of the objects in
 the set, which objects are in the results, or the order of the objects in the
 set.

 The `changes` parameter will be `nil` the first time the block is called.
 For each call after that, it will contain information about
 which rows in the set were added, removed or modified. If a write transaction
 did not modify any objects in the set, the block is not called at all.
 See the `RLMCollectionChange` documentation for information on how the changes
 are reported and an example of updating a `UITableView`.

 If an error occurs the block will be called with `nil` for the results
 parameter and a non-`nil` error. Currently the only errors that can occur are
 when opening the Realm on the background worker thread.

 Notifications are delivered on the given queue. If the queue is blocked and
 notifications can't be delivered instantly, multiple notifications may be
 coalesced into a single notification.

 You must retain the returned token for as long as you want updates to continue
 to be sent to the block. To stop receiving updates, call `-invalidate` on the token.

 @warning This method cannot be called when the containing Realm is read-only or frozen.
 @warning The queue must be a serial queue.

 @param block The block to be called whenever a change occurs.
 @param queue The serial queue to deliver notifications to.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet<RLMObjectType> *_Nullable set,
                                                         RLMCollectionChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                         queue:(nullable dispatch_queue_t)queue
__attribute__((warn_unused_result));

// TODO: order correctly
// TODO: docs
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet<RLMObjectType> *_Nullable set,
                                                         RLMCollectionChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(nullable dispatch_queue_t)queue
__attribute__((warn_unused_result));

// TODO: docs
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet<RLMObjectType> *_Nullable set,
                                                         RLMCollectionChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
__attribute__((warn_unused_result));

#pragma mark - Aggregating Property Values

/**
 Returns the minimum (lowest) value of the given property among all the objects in the set.

     NSNumber *min = [object.setProperty minOfProperty:@"age"];

 @warning You cannot use this method on `RLMObject`,  `RLMArray`,  `RLMSet`, and `NSData` properties.

 @param property The property whose minimum value is desired. Only properties of
                 types `int`, `float`, `double`, and `NSDate` are supported.

 @return The minimum value of the property, or `nil` if the set is empty.
 */
- (nullable id)minOfProperty:(NSString *)property;

/**
 Returns the maximum (highest) value of the given property among all the objects in the set.

     NSNumber *max = [object.setProperty maxOfProperty:@"age"];

 @warning You cannot use this method on `RLMObject`, `RLMArray`,  `RLMSet`, and `NSData` properties.

 @param property The property whose maximum value is desired. Only properties of
                 types `int`, `float`, `double`, and `NSDate` are supported.

 @return The maximum value of the property, or `nil` if the set is empty.
 */
- (nullable id)maxOfProperty:(NSString *)property;

/**
 Returns the sum of distinct values of a given property over all the objects in the set.

     NSNumber *sum = [object.setProperty sumOfProperty:@"age"];

 @warning You cannot use this method on `RLMObject`, `RLMArray`,  `RLMSet and `NSData` properties.

 @param property The property whose values should be summed. Only properties of
                 types `int`, `float`, and `double` are supported.

 @return The sum of the given property.
 */
- (NSNumber *)sumOfProperty:(NSString *)property;

/**
 Returns the average value of a given property over the objects in the set.

     NSNumber *average = [object.setProperty averageOfProperty:@"age"];

 @warning You cannot use this method on `RLMObject`, `RLMSet`,  `RLMArray`, and `NSData` properties.

 @param property The property whose average value should be calculated. Only
                 properties of types `int`, `float`, and `double` are supported.

 @return    The average value of the given property, or `nil` if the set is empty.
 */
- (nullable NSNumber *)averageOfProperty:(NSString *)property;

#pragma mark - Freeze

/**
 Returns a frozen (immutable) snapshot of this set.

 The frozen copy is an immutable set which contains the same data as this
 et currently contains, but will not update when writes are made to the
 containing Realm. Unlike live sets, frozen sets can be accessed from any
 thread.

 @warning This method cannot be called during a write transaction, or when the
          containing Realm is read-only.
 @warning This method may only be called on a managed set.
 @warning Holding onto a frozen set for an extended period while performing
          write transaction on the Realm may result in the Realm file growing
          to large sizes. See `RLMRealmConfiguration.maximumNumberOfActiveVersions`
          for more information.
 */
- (instancetype)freeze;

/**
 Returns a live version of this frozen collection.

 This method resolves a reference to a live copy of the same frozen collection.
 If called on a live collection, will return itself.
*/
- (instancetype)thaw;

#pragma mark - Unavailable Methods

/**
 `-[RLMSet init]` is not available because `RLMSet`s cannot be created directly.
 ``RLMSet` properties on `RLMObject`s are lazily created when accessed.
 */
- (instancetype)init __attribute__((unavailable("RLMSets cannot be created directly")));

/**
 `+[RLMSet new]` is not available because `RLMSet`s cannot be created directly.
 `RLMSet` properties on `RLMObject`s are lazily created when accessed.
 */
+ (instancetype)new __attribute__((unavailable("RLMSet cannot be created directly")));

@end

/// :nodoc:
@interface RLMSet (Swift)
// for use only in Swift class definitions
- (instancetype)initWithObjectClassName:(NSString *)objectClassName;
@end

NS_ASSUME_NONNULL_END
