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

#import <Foundation/Foundation.h>

#import <Realm/RLMObjectBase.h>
#import <Realm/RLMThreadSafeReference.h>

NS_ASSUME_NONNULL_BEGIN

@class RLMObjectSchema, RLMPropertyDescriptor, RLMRealm, RLMNotificationToken, RLMPropertyChange;
typedef void (^RLMObjectChangeBlock)(BOOL deleted,
                                     NSArray<RLMPropertyChange *> *_Nullable changes,
                                     NSError *_Nullable error);
/**
 `RLMEmbeddedObject` is a base class used to define Realm model objects.

 Embedded objects work similarly to normal objects, but are owned by a single
 parent Object (which itself may be embedded). Unlike normal top-level objects,
 embedded objects cannot be directly created in or added to a Realm. Instead,
 they can only be created as part of a parent object, or by assigning an
 unmanaged object to a parent object's property. Embedded objects are
 automatically deleted when the parent object is deleted or when the parent is
 modified to no longer point at the embedded object, either by reassigning an
 RLMObject property or by removing the embedded object from the array containing
 it.

 Embedded objects can only ever have a single parent object which links to them,
 and attempting to link to an existing managed embedded object will throw an
 exception.

 The property types supported on `RLMEmbeddedObject` are the same as for
 `RLMObject`, except for that embedded objects cannot link to top-level objects,
 so `RLMObject` and `RLMArray<RLMObject>` properties are not supported
 (`RLMEmbeddedObject` and `RLMArray<RLMEmbeddedObject>` *are*).

 Embedded objects cannot have primary keys or indexed properties.
 */

@interface RLMEmbeddedObject : RLMObjectBase <RLMThreadConfined>

#pragma mark - Creating & Initializing Objects

/**
 Creates an unmanaged instance of a Realm object.

 Unmanaged embedded objects can be added to a Realm by assigning them to an
 object property of a managed Realm object or by adding them to a managed
 RLMArray.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 Creates an unmanaged instance of a Realm object.

 Pass in an `NSArray` or `NSDictionary` instance to set the values of the object's properties.

 Unmanaged embedded objects can be added to a Realm by assigning them to an
 object property of a managed Realm object or by adding them to a managed
 RLMArray.
 */
- (instancetype)initWithValue:(id)value;

/**
 Returns the class name for a Realm object subclass.

 @warning Do not override. Realm relies on this method returning the exact class
          name.

 @return  The class name for the model class.
 */
+ (NSString *)className;

#pragma mark - Properties

/**
 The Realm which manages the object, or `nil` if the object is unmanaged.
 */
@property (nonatomic, readonly, nullable) RLMRealm *realm;

/**
 The object schema which lists the managed properties for the object.
 */
@property (nonatomic, readonly) RLMObjectSchema *objectSchema;

/**
 Indicates if the object can no longer be accessed because it is now invalid.

 An object can no longer be accessed if the object has been deleted from the Realm that manages it, or
 if `invalidate` is called on that Realm.
 */
@property (nonatomic, readonly, getter = isInvalidated) BOOL invalidated;

/**
 Indicates if this object is frozen.

 @see `-[RLMEmbeddedObject freeze]`
 */
@property (nonatomic, readonly, getter = isFrozen) BOOL frozen;

#pragma mark - Customizing your Objects

/**
 Override this method to specify the default values to be used for each property.

 @return    A dictionary mapping property names to their default values.
 */
+ (nullable NSDictionary *)defaultPropertyValues;

/**
 Override this method to specify the names of properties to ignore. These properties will not be managed by the Realm
 that manages the object.

 @return    An array of property names to ignore.
 */
+ (nullable NSArray<NSString *> *)ignoredProperties;

/**
 Override this method to specify the names of properties that are non-optional (i.e. cannot be assigned a `nil` value).

 By default, all properties of a type whose values can be set to `nil` are
 considered optional properties. To require that an object in a Realm always
 store a non-`nil` value for a property, add the name of the property to the
 array returned from this method.

 Properties of `RLMEmbeddedObject` type cannot be non-optional. Array and
 `NSNumber` properties can be non-optional, but there is no reason to do so:
 arrays do not support storing nil, and if you want a non-optional number you
 should instead use the primitive type.

 @return    An array of property names that are required.
 */
+ (NSArray<NSString *> *)requiredProperties;

/**
 Override this method to provide information related to properties containing linking objects.

 Each property of type `RLMLinkingObjects` must have a key in the dictionary returned by this method consisting
 of the property name. The corresponding value must be an instance of `RLMPropertyDescriptor` that describes the class
 and property that the property is linked to.

     return @{ @"owners": [RLMPropertyDescriptor descriptorWithClass:Owner.class propertyName:@"dogs"] };

 @return     A dictionary mapping property names to `RLMPropertyDescriptor` instances.
 */
+ (NSDictionary<NSString *, RLMPropertyDescriptor *> *)linkingObjectsProperties;

#pragma mark - Notifications

/**
 Registers a block to be called each time the object changes.

 The block will be asynchronously called after each write transaction which
 deletes the object or modifies any of the managed properties of the object,
 including self-assignments that set a property to its existing value.

 For write transactions performed on different threads or in differen
 processes, the block will be called when the managing Realm is
 (auto)refreshed to a version including the changes, while for local write
 transactions it will be called at some point in the future after the write
 transaction is committed.

 Notifications are delivered via the standard run loop, and so can't be
 delivered while the run loop is blocked by other activity. When notifications
 can't be delivered instantly, multiple notifications may be coalesced into a
 single notification.

 Unlike with `RLMArray` and `RLMResults`, there is no "initial" callback made
 after you add a new notification block.

 Only objects which are managed by a Realm can be observed in this way. You
 must retain the returned token for as long as you want updates to be sent to
 the block. To stop receiving updates, call `-invalidate` on the token.

 It is safe to capture a strong reference to the observed object within the
 callback block. There is no retain cycle due to that the callback is retained
 by the returned token and not by the object itself.

 @warning This method cannot be called during a write transaction, when the
          containing Realm is read-only, or on an unmanaged object.

 @param block The block to be called whenever a change occurs.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block;

/**
 Registers a block to be called each time the object changes.

 The block will be asynchronously called after each write transaction which
 deletes the object or modifies any of the managed properties of the object,
 including self-assignments that set a property to its existing value.

 For write transactions performed on different threads or in different
 processes, the block will be called when the managing Realm is
 (auto)refreshed to a version including the changes, while for local write
 transactions it will be called at some point in the future after the write
 transaction is committed.

 Notifications are delivered on the given queue. If the queue is blocked and
 notifications can't be delivered instantly, multiple notifications may be
 coalesced into a single notification.

 Unlike with `RLMArray` and `RLMResults`, there is no "initial" callback made
 after you add a new notification block.

 Only objects which are managed by a Realm can be observed in this way. You
 must retain the returned token for as long as you want updates to be sent to
 the block. To stop receiving updates, call `-invalidate` on the token.

 It is safe to capture a strong reference to the observed object within the
 callback block. There is no retain cycle due to that the callback is retained
 by the returned token and not by the object itself.

 @warning This method cannot be called during a write transaction, when the
          containing Realm is read-only, or on an unmanaged object.
 @warning The queue must be a serial queue.

 @param block The block to be called whenever a change occurs.
 @param queue The serial queue to deliver notifications to.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block queue:(dispatch_queue_t)queue;

/**
 Registers a block to be called each time the object changes.

 The block will be asynchronously called after each write transaction which
 deletes the object or modifies any of the managed properties of the object,
 including self-assignments that set a property to its existing value.

 For write transactions performed on different threads or in different
 processes, the block will be called when the managing Realm is
 (auto)refreshed to a version including the changes, while for local write
 transactions it will be called at some point in the future after the write
 transaction is committed.

 Notifications are delivered on the given queue. If the queue is blocked and
 notifications can't be delivered instantly, multiple notifications may be
 coalesced into a single notification.

 Unlike with `RLMArray` and `RLMResults`, there is no "initial" callback made
 after you add a new notification block.

 Only objects which are managed by a Realm can be observed in this way. You
 must retain the returned token for as long as you want updates to be sent to
 the block. To stop receiving updates, call `-invalidate` on the token.

 It is safe to capture a strong reference to the observed object within the
 callback block. There is no retain cycle due to that the callback is retained
 by the returned token and not by the object itself.

 @warning This method cannot be called during a write transaction, when the
          containing Realm is read-only, or on an unmanaged object.
 @warning The queue must be a serial queue.

 @param block The block to be called whenever a change occurs.
 @param keyPaths The block will be called for changes occuring on these keypaths. If no
 key paths are given, notifications are delivered for every property key path.
 @param queue The serial queue to deliver notifications to.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block keyPaths:(NSArray<NSString *> *)keyPaths queue:(dispatch_queue_t)queue;

/**
 Registers a block to be called each time the object changes.

 The block will be asynchronously called after each write transaction which
 deletes the object or modifies any of the managed properties of the object,
 including self-assignments that set a property to its existing value.

 For write transactions performed on different threads or in different
 processes, the block will be called when the managing Realm is
 (auto)refreshed to a version including the changes, while for local write
 transactions it will be called at some point in the future after the write
 transaction is committed.

 Notifications are delivered on the given queue. If the queue is blocked and
 notifications can't be delivered instantly, multiple notifications may be
 coalesced into a single notification.

 Unlike with `RLMArray` and `RLMResults`, there is no "initial" callback made
 after you add a new notification block.

 Only objects which are managed by a Realm can be observed in this way. You
 must retain the returned token for as long as you want updates to be sent to
 the block. To stop receiving updates, call `-invalidate` on the token.

 It is safe to capture a strong reference to the observed object within the
 callback block. There is no retain cycle due to that the callback is retained
 by the returned token and not by the object itself.

 @warning This method cannot be called during a write transaction, when the
          containing Realm is read-only, or on an unmanaged object.
 @warning The queue must be a serial queue.

 @param block The block to be called whenever a change occurs.
 @param keyPaths The block will be called for changes occuring on these keypaths. If no
 key paths are given, notifications are delivered for every property key path.
 @return A token which must be held for as long as you want updates to be delivered.
 */
- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block keyPaths:(NSArray<NSString *> *)keyPaths;

#pragma mark - Other Instance Methods

/**
 Returns YES if another Realm object instance points to the same object as the
 receiver in the Realm managing the receiver.

 For frozen objects and object types with a primary key, `isEqual:` is
 overridden to use the same logic as this method (along with a corresponding
 implementation for `hash`). Non-frozen objects without primary keys use
 pointer identity for `isEqual:` and `hash`.

 @param object  The object to compare the receiver to.

 @return    Whether the object represents the same object as the receiver.
 */
- (BOOL)isEqualToObject:(RLMEmbeddedObject *)object;

/**
 Returns a frozen (immutable) snapshot of this object.

 The frozen copy is an immutable object which contains the same data as this
 object currently contains, but will not update when writes are made to the
 containing Realm. Unlike live objects, frozen objects can be accessed from any
 thread.

 - warning: Holding onto a frozen object for an extended period while performing write
 transaction on the Realm may result in the Realm file growing to large sizes. See
 `Realm.Configuration.maximumNumberOfActiveVersions` for more information.
 - warning: This method can only be called on a managed object.
 */
- (instancetype)freeze NS_RETURNS_RETAINED;

/**
 Returns a live (mutable) reference of this object.

 This method creates a managed accessor to a live copy of the same frozen object.
 Will return self if called on an already live object.
 */
- (instancetype)thaw;

#pragma mark - Dynamic Accessors

/// :nodoc:
- (nullable id)objectForKeyedSubscript:(NSString *)key;

/// :nodoc:
- (void)setObject:(nullable id)obj forKeyedSubscript:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
