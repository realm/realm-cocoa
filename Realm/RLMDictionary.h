////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

@class RLMObject, RLMResults<RLMObjectType>, RLMDictionaryChange;

/**
 `RLMDictionary` is a container type in Realm representing a dynamic collection of key-value pairs.

 Unlike `NSDictionary`, `RLMDictionary`s hold a single key and value type.
 This is referred to in these docs as the “type” and “keyType” of the dictionary.

 When declaring an `RLMDictionary` property, the object type and keyType must be marked as conforming to a
 protocol by the same name as the objects it should contain.

     RLM_COLLECTION_TYPE(ObjectType)
     ...
     @property RLMDictionary<NSString *, ObjectType *><RLMString, ObjectType> *objectTypeDictionary;

 `RLMDictionary`s can be queried with the same predicates as `RLMObject` and `RLMResult`s.

 `RLMDictionary`s cannot be created directly. `RLMDictionary` properties on `RLMObject`s are
 lazily created when accessed, or can be obtained by querying a Realm.

 ### Key-Value Observing

 `RLMDictionary` supports dictionary key-value observing on `RLMDictionary` properties on `RLMObject`
 subclasses, and the `invalidated` property on `RLMDictionary` instances themselves is
 key-value observing compliant when the `RLMDictionary` is attached to a managed
 `RLMObject` (`RLMDictionary`s on unmanaged `RLMObject`s will never become invalidated).
 */
@interface RLMDictionary<RLMKeyType, RLMObjectType>: NSObject<RLMCollection>

#pragma mark - Properties

/**
 The number of entries in the dictionary.
 */
@property (nonatomic, readonly, assign) NSUInteger count;

/**
 The type of the objects in the dictionary.
 */
@property (nonatomic, readonly, assign) RLMPropertyType type;

/**
 The type of the key used in this dictionary.
 */
@property (nonatomic, readonly, assign) RLMPropertyType keyType;

/**
 Indicates whether the objects in the collection can be `nil`.
 */
@property (nonatomic, readonly, getter = isOptional) BOOL optional;

/**
 The class name of the objects contained in the dictionary.

 Will be `nil` if `type` is not RLMPropertyTypeObject.
 */
@property (nonatomic, readonly, copy, nullable) NSString *objectClassName;

/**
 The Realm which manages the dictionary. Returns `nil` for unmanaged dictionary.
 */
@property (nonatomic, readonly, nullable) RLMRealm *realm;

/**
 Indicates if the dictionary can no longer be accessed.
 */
@property (nonatomic, readonly, getter = isInvalidated) BOOL invalidated;

/**
 Indicates if the dictionary is frozen.

 Frozen dictionaries are immutable and can be accessed from any thread. Frozen dictionaries
 are created by calling `-freeze` on a managed live dictionary. Unmanaged dictionaries are
 never frozen.
 */
@property (nonatomic, readonly, getter = isFrozen) BOOL frozen;

#pragma mark - Accessing Objects from a Dictionary

/**
 Returns the value associated with a given key.

 @param key The name of the property.

 @discussion If key does not start with “@”, invokes object(forKey:). If key does start
 with “@”, strips the “@” and invokes [super valueForKey:] with the rest of the key.

 @return A value associated with a given key or `nil`.
 */
- (nullable id)valueForKey:(nonnull RLMKeyType)key;

/**
 Returns an array containing the dictionary’s keys.

 @note The order of the elements in the array is not defined.
 */
@property(readonly, copy) NSArray<RLMKeyType> *allKeys;

/**
 Returns an array containing the dictionary’s values.

 @note The order of the elements in the array is not defined.
 */
@property(readonly, copy) NSArray<RLMObjectType> *allValues;

/**
 Returns the value associated with a given key.

 @note `nil` will be returned if no value is associated with a given key. NSNull will be returned
       where null is associated with the key.

 @param key The key for which to return the corresponding value.

 @return The value associated with key.
 */
- (nullable RLMObjectType)objectForKey:(nonnull RLMKeyType)key;

/**
 Returns the value associated with a given key.

 @note `nil` will be returned if no value is associated with a given key. NSNull will be returned
       where null is associated with the key.

 @param key The key for which to return the corresponding value.

 @return The value associated with key.
 */
- (nullable RLMObjectType)objectForKeyedSubscript:(RLMKeyType)key;

/**
 Applies a given block object to the each key-value pair of the dictionary.

 @param block A block object to operate on entries in the dictionary.

 @note If the block sets *stop to YES, the enumeration stops.
 */
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(RLMKeyType key, RLMObjectType obj, BOOL *stop))block;

#pragma mark - Adding, Removing, and Replacing Objects in a Dictionary

/**
 Replace the contents of a dictionary with the contents of another dictionary - NSDictionary or RLMDictionary.

 This will remove all elements in this dictionary and then apply each element from the given dictionary.

 @warning This method may only be called during a write transaction.
 @warning If otherDictionary is self this will result in an empty dictionary.
 */
- (void)setDictionary:(id)otherDictionary;

/**
 Removes all contents in the dictionary.

 @warning This method may only be called during a write transaction.
 */
- (void)removeAllObjects;

/**
 Removes from the dictionary entries specified by elements in a given array. If a given key does not
 exist, no mutation will happen for that key.

 @warning This method may only be called during a write transaction.
 */
- (void)removeObjectsForKeys:(NSArray<RLMKeyType> *)keyArray;

/**
 Removes a given key and its associated value from the dictionary. If the key does not exist the dictionary
 will not be modified.

 @warning This method may only be called during a write transaction.
 */
- (void)removeObjectForKey:(RLMKeyType)key;

/**
 Adds a given key-value pair to the dictionary if the key is not present, or updates the value for the given key
 if the key already present.

 @warning This method may only be called during a write transaction.
 */
- (void)setObject:(nullable RLMObjectType)obj forKeyedSubscript:(RLMKeyType)key;

/**
 Adds a given key-value pair to the dictionary if the key is not present, or updates the value for the given key
 if the key already present.

 @warning This method may only be called during a write transaction.
 */
- (void)setObject:(nullable RLMObjectType)anObject forKey:(RLMKeyType)aKey;

/**
  Adds to the receiving dictionary the entries from another dictionary.

  @note If the receiving dictionary contains the same key(s) as the otherDictionary, then
        the receiving dictionary will update each key-value pair for the matching key.
 
  @warning This method may only be called during a write transaction.

  @param otherDictionary An enumerable object such as `NSDictionary` or `RLMDictionary` which contains objects of the
         same type as the receiving dictionary.
 */
- (void)addEntriesFromDictionary:(id <NSFastEnumeration>)otherDictionary;

#pragma mark - Querying a Dictionary

/**
 Returns all the values matching the given predicate in the dictionary.

 @note The keys in the dictionary are ignored when quering values, and they will not be returned in the `RLMResults`.

 @param predicateFormat A predicate format string, optionally followed by a variable number of arguments.

 @return                An `RLMResults` of objects that match the given predicate.
 */
- (RLMResults<RLMObjectType> *)objectsWhere:(NSString *)predicateFormat, ...;

/// :nodoc:
- (RLMResults<RLMObjectType> *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

/**
 Returns all the values matching the given predicate in the dictionary.

 @note The keys in the dictionary are ignored when quering values, and they will not be returned in the `RLMResults`.

 @param predicate   The predicate with which to filter the objects.

 @return            An `RLMResults` of objects that match the given predicate
 */
- (RLMResults<RLMObjectType> *)objectsWithPredicate:(NSPredicate *)predicate;

/**
 Returns a sorted RLMResults of all values in the dictionary.

 @note The keys in the dictionary are ignored when sorting values, and they will not be returned in the `RLMResults`.

 @param keyPath     The key path to sort by.
 @param ascending   The direction to sort in.

 @return    An `RLMResults` sorted by the specified key path.
 */- (RLMResults<RLMObjectType> *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending;

/**
 Returns a sorted RLMResults of all values in the dictionary.

 @note The keys in the dictionary are ignored when sorting values, and they will not be returned in the `RLMResults`.

 @param properties  An array of `RLMSortDescriptor`s to sort by.

 @return    An `RLMResults` sorted by the specified properties.
 */
- (RLMResults<RLMObjectType> *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties;

/**
 Returns a distinct `RLMResults` from all values in the dictionary.

 @note The keys in the dictionary are ignored, and they will not be returned in the `RLMResults`.

 @param keyPaths     The key paths to distinct on.

 @return    An `RLMResults` with the distinct values of the keypath(s).
 */
- (RLMResults<RLMObjectType> *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths;

#pragma mark - Aggregating Property Values

/**
 Returns the minimum (lowest) value of the given property among all the values in the dictionary.

     NSNumber *min = [object.dictionaryProperty minOfProperty:@"age"];

 @param property The property whose minimum value is desired. Only properties of
                 types `int`, `float`, `double`, `NSDate`, `RLMValue` and `RLMDecimal128` are supported.

 @return The minimum value of the property, or `nil` if the dictionary is empty.
 */
- (nullable id)minOfProperty:(NSString *)property;

/**
 Returns the maximum (highest) value of the given property among all the objects in the dictionary.

     NSNumber *max = [object.dictionaryProperty maxOfProperty:@"age"];

 @param property The property whose minimum value is desired. Only properties of
                 types `int`, `float`, `double`, `NSDate`, `RLMValue` and `RLMDecimal128` are supported.

 @return The maximum value of the property, or `nil` if the dictionary is empty.
 */
- (nullable id)maxOfProperty:(NSString *)property;

/**
 Returns the sum of distinct values of a given property over all the objects in the dictionary.

     NSNumber *sum = [object.dictionaryProperty sumOfProperty:@"age"];

 @param property The property whose minimum value is desired. Only properties of
                 types `int`, `float`, `double`, `RLMValue` and  `RLMDecimal128` are supported.

 @return The sum of the given property.
 */
- (NSNumber *)sumOfProperty:(NSString *)property;

/**
 Returns the average value of a given property over the objects in the dictionary.

     NSNumber *average = [object.dictionaryProperty averageOfProperty:@"age"];

 @param property The property whose minimum value is desired. Only properties of
                 types `int`, `float`, `double`, `NSDate`, `RLMValue` and `RLMDecimal128` are supported.

 @return The average value of the given property, or `nil` if the dictionary is empty.
 */
- (nullable NSNumber *)averageOfProperty:(NSString *)property;

#pragma mark - Notifications

/**
 Registers a block to be called each time the dictionary changes.

 The block will be asynchronously called with the initial dictionary, and then
 called again after each write transaction which changes any of the keys or values
 within the dictionary.

 The `changes` parameter will be `nil` the first time the block is called.
 For each call after that, it will contain information about
 which keys in the dictionary were added, modified or deleted. If a write transaction
 did not modify any keys or values in the dictionary, the block is not called at all.

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
     self.token = [person.dogs addNotificationBlock(RLMDictionary<NSString *, Dog *><RLMString, Dog> *dogs,
                                       RLMDictionaryChange *changes,
                                       NSError *error) {
         // Only fired once for the example
         NSLog(@"dogs.count: %zu", dogs.count); // => 1
     }];
     [realm transactionWithBlock:^{
         Dog *dog = [[Dog alloc] init];
         dog.name = @"Rex";
         person.dogs[@"frenchBulldog"] = dog;
     }];
     // end of run loop execution context

 You must retain the returned token for as long as you want updates to continue
 to be sent to the block. To stop receiving updates, call `-invalidate` on the token.

 @warning This method cannot be called during a write transaction, or when the
          containing Realm is read-only.
 @warning This method may only be called on a non-frozen managed dictionary.

 @param block The block to be called each time the dictionary changes.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary<RLMKeyType, RLMObjectType> *_Nullable dictionary,
                                                         RLMDictionaryChange *_Nullable changes,
                                                         NSError *_Nullable error))block
__attribute__((warn_unused_result));

/**
 Registers a block to be called each time the dictionary changes.

 The block will be asynchronously called with the initial dictionary, and then
 called again after each write transaction which changes any of the key-value in
 the dictionary or which objects are in the results.

 The `changes` parameter will be `nil` the first time the block is called.
 For each call after that, it will contain information about
 which keys in the dictionary were added or modified. If a write transaction
 did not modify any objects in the dictionary, the block is not called at all.

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
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary<RLMKeyType, RLMObjectType> *_Nullable dictionary,
                                                         RLMDictionaryChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                         queue:(nullable dispatch_queue_t)queue
__attribute__((warn_unused_result));

// TODO: docs
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary<RLMKeyType, RLMObjectType> *_Nullable dictionary,
                                                         RLMDictionaryChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(nullable dispatch_queue_t)queue
__attribute__((warn_unused_result));

// TODO: docs
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary<RLMKeyType, RLMObjectType> *_Nullable dictionary,
                                                         RLMDictionaryChange *_Nullable changes,
                                                         NSError *_Nullable error))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
__attribute__((warn_unused_result));

#pragma mark - Freeze

/**
 Returns a frozen (immutable) snapshot of a dictionary.

 The frozen copy is an immutable dictionary which contains the same data as this
 dictionary currently contains, but will not update when writes are made to the
 containing Realm. Unlike live dictionaries, frozen dictionaries can be accessed from any
 thread.

 @warning This method cannot be called during a write transaction, or when the
          containing Realm is read-only.
 @warning This method may only be called on a managed dictionary.
 @warning Holding onto a frozen dictionary for an extended period while performing
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
 `-[RLMDictionary init]` is not available because `RLMDictionary`s cannot be created directly.
 `RLMDictionary` properties on `RLMObject`s are lazily created when accessed.
 */
- (instancetype)init __attribute__((unavailable("RLMDictionary cannot be created directly")));
/**
 `+[RLMDictionary new]` is not available because `RLMDictionary`s cannot be created directly.
 `RLMDictionary` properties on `RLMObject`s are lazily created when accessed.
 */
+ (instancetype)new __attribute__((unavailable("RLMDictionary cannot be created directly")));

@end

/**
 A `RLMDictionaryChange` object encapsulates information about changes to dictionaries
 that are reported by Realm notifications.

 `RLMDictionaryChange` is passed to the notification blocks registered with
 `-addNotificationBlock` on `RLMDictionary`, and reports what keys in the
 dictionary changed since the last time the notification block was called.
 */
@interface RLMDictionaryChange : NSObject
/// The keys in the new version of the dictionary which were newly inserted.
@property (nonatomic, readonly) NSArray<id> *insertions;

/// The keys in the new version of the dictionary which were modified.
@property (nonatomic, readonly) NSArray<id> *modifications;

/// The keys which were deleted from the old version.
@property (nonatomic, readonly) NSArray<id> *deletions;
@end

NS_ASSUME_NONNULL_END
