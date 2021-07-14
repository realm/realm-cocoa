////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
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

import Foundation
import Realm
import Realm.Private

/**
 `Object` is a class used to define Realm model objects.

 In Realm you define your model classes by subclassing `Object` and adding properties to be managed.
 You then instantiate and use your custom subclasses instead of using the `Object` class directly.

 ```swift
 class Dog: Object {
     @Persisted var name: String
     @Persisted var adopted: Bool
     @Persisted var siblings: List<Dog>
 }
 ```

 ### Supported property types

 - `String`
 - `Int`, `Int8`, `Int16`, `Int32`, `Int64`
 - `Float`
 - `Double`
 - `Bool`
 - `Date`
 - `Data`
 - `Decimal128`
 - `ObjectId`
 - `UUID`
 - `AnyRealmValue`
 - Any RawRepresentable enum whose raw type is a legal property type. Enums
   must explicitly be marked as conforming to `PersistableEnum`.
 - `Object` subclasses, to model many-to-one relationships
 - `EmbeddedObject` subclasses, to model owning one-to-one relationships

 All of the types above may also be `Optional`, with the exception of
 `AnyRealmValue`. `Object` and `EmbeddedObject` subclasses *must* be Optional.

 In addition to individual values, three different collection types are supported:
 - `List<Element>`: an ordered mutable collection similar to `Array`.
 - `MutableSet<Element>`: an unordered uniquing collection similar to `Set`.
 - `Map<String, Element>`: an unordered key-value collection similar to `Dictionary`.

 The Element type of collections may be any of the supported non-collection
 property types listed above. Collections themselves may not be Optional, but
 the values inside them may be, except for lists and sets of `Object` or
 `EmbeddedObject` subclasses.

 Finally, `LinkingObjects` properties can be used to track which objects link
 to this one.

 All properties which should be stored by Realm must be explicitly marked with
 `@Persisted`. Any properties not marked with `@Persisted` will be ignored
 entirely by Realm, and may be of any type.

 ### Querying

 You can retrieve all objects of a given type from a Realm by calling the `objects(_:)` instance method.

 ### Relationships

 See our [Cocoa guide](http://realm.io/docs/cocoa) for more details.
 */
public typealias Object = RealmSwiftObject
extension Object: RealmCollectionValue {
    // MARK: Initializers

    /**
     Creates an unmanaged instance of a Realm object.

     The `value` argument is used to populate the object. It can be a key-value coding compliant object, an array or
     dictionary returned from the methods in `NSJSONSerialization`, or an `Array` containing one element for each
     managed property. An exception will be thrown if any required properties are not present and those properties were
     not defined with default values.

     When passing in an `Array` as the `value` argument, all properties must be present, valid and in the same order as
     the properties defined in the model.

     Call `add(_:)` on a `Realm` instance to add an unmanaged object into that Realm.

     - parameter value:  The value used to populate the object.
     */
    public convenience init(value: Any) {
        self.init()
        RLMInitializeWithValue(self, value, .partialPrivateShared())
    }


    // MARK: Properties

    /// The Realm which manages the object, or `nil` if the object is unmanaged.
    public var realm: Realm? {
        if let rlmReam = RLMObjectBaseRealm(self) {
            return Realm(rlmReam)
        }
        return nil
    }

    /// The object schema which lists the managed properties for the object.
    public var objectSchema: ObjectSchema {
        return ObjectSchema(RLMObjectBaseObjectSchema(self)!)
    }

    /// Indicates if the object can no longer be accessed because it is now invalid.
    ///
    /// An object can no longer be accessed if the object has been deleted from the Realm that manages it, or if
    /// `invalidate()` is called on that Realm. This property is key-value observable.
    @objc dynamic open override var isInvalidated: Bool { return super.isInvalidated }

    /// A human-readable description of the object.
    open override var description: String { return super.description }

    /**
     WARNING: This is an internal helper method not intended for public use.
     It is not considered part of the public API.
     :nodoc:
     */
    public override final class func _getProperties() -> [RLMProperty] {
        return ObjectUtil.getSwiftProperties(self)
    }

    // MARK: Object Customization

    /**
     Override this method to specify the name of a property to be used as the primary key.

     Only properties of types `String`, `Int`, `ObjectId` and `UUID` can be
     designated as the primary key. Primary key properties enforce uniqueness
     for each value whenever the property is set, which incurs minor overhead.
     Indexes are created automatically for primary key properties.

     - warning: This function is only applicable to legacy property declarations
                using `@objc`. When using `@Persisted`, use
                `@Persisted(primaryKey: true)` instead.
     - returns: The name of the property designated as the primary key, or
                `nil` if the model has no primary key.
     */
    @objc open class func primaryKey() -> String? { return nil }

    /**
     Override this method to specify the names of properties to ignore. These
     properties will not be managed by the Realm that manages the object.

     - warning: This function is only applicable to legacy property declarations
                using `@objc`. When using `@Persisted`, any properties not
                marked with `@Persisted` are automatically ignored.
     - returns: An array of property names to ignore.
     */
    @objc open class func ignoredProperties() -> [String] { return [] }

    /**
     Returns an array of property names for properties which should be indexed.

     Only string, integer, boolean, `Date`, and `NSDate` properties are supported.

     - warning: This function is only applicable to legacy property declarations
                using `@objc`. When using `@Persisted`, use
                `@Persisted(indexed: true)` instead.
     - returns: An array of property names.
     */
    @objc open class func indexedProperties() -> [String] { return [] }

    // MARK: Key-Value Coding & Subscripting

    /// Returns or sets the value of the property with the given name.
    @objc open subscript(key: String) -> Any? {
        get {
            RLMDynamicGetByName(self, key)
        }
        set {
            dynamicSet(object: self, key: key, value: newValue)
        }
    }

    // MARK: Notifications

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

     If no key paths are given, the block will be executed on any insertion,
     modification, or deletion for all object properties and nested linked
     properties. If a key path or key paths are provided,
     then the block will be called for changes which occur on those key paths. For example, if:
     ```swift
     class Dog: Object {
         @objc dynamic var name: String = ""
         @objc dynamic var adopted: Bool = false
         let siblings = List<Dog>()
     }

     // ... where `dog` is a managed Dog object.
     dog.observe(keyPaths: ["adopted"], { changes in
        // ...
     })
     ```
     - The above notification block fires for changes to the
     `adopted` property, but not for any changes made to `name`.
     - If the observed key path were `["siblings"]`, then any insertion,
     deletion, or modification to the `siblings` list trigger the block. A change to
     `someSibling.name` would not trigger the block (where `someSibling`
     is an element contained in `siblings`)
     - If the observed key path were `["siblings.name"]`, then any insertion or
     deletion to the `siblings` list would trigger the block. For objects
     contained in the `siblings` list, only modifications to their `name` property
     will trigger the block.

     - note: Multiple notification tokens on the same object which filter for
     separate key paths *do not* filter exclusively. If one key path
     change is satisified for one notification token, then all notification
     token blocks for that object will execute.

     If no queue is given, notifications are delivered via the standard run
     loop, and so can't be delivered while the run loop is blocked by other
     activity. If a queue is given, notifications are delivered to that queue
     instead. When notifications can't be delivered instantly, multiple
     notifications may be coalesced into a single notification.

     Unlike with `List` and `Results`, there is no "initial" callback made after
     you add a new notification block.

     Only objects which are managed by a Realm can be observed in this way. You
     must retain the returned token for as long as you want updates to be sent
     to the block. To stop receiving updates, call `invalidate()` on the token.

     It is safe to capture a strong reference to the observed object within the
     callback block. There is no retain cycle due to that the callback is
     retained by the returned token and not by the object itself.

     - warning: This method cannot be called during a write transaction, or when
     the containing Realm is read-only.
     - parameter keyPaths: The object properties which trigger the block to
     be called when they are modified. If `nil`, notifications will be delivered for
     any property change on the object. See comments above for more detail on linked properties.
     - parameter queue: The serial dispatch queue to receive notification on. If
     `nil`, notifications are delivered to the current thread.
     - parameter block: The block to call with information about changes to the object.
     - returns: A token which must be held for as long as you want updates to be delivered.
     */
    public func observe<T: RLMObjectBase>(keyPaths: [String]? = nil,
                                          on queue: DispatchQueue? = nil,
                                          _ block: @escaping (ObjectChange<T>) -> Void) -> NotificationToken {
        return _observe(keyPaths: keyPaths, on: queue, block)
    }

    // MARK: Dynamic list

    /**
     Returns a list of `DynamicObject`s for a given property name.

     - warning:  This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use instance variables or cast the values returned from key-value coding.

     - parameter propertyName: The name of the property.

     - returns: A list of `DynamicObject`s.

     :nodoc:
     */
    public func dynamicList(_ propertyName: String) -> List<DynamicObject> {
        if let dynamic = self as? DynamicObject {
            return dynamic[propertyName] as! List<DynamicObject>
        }
        let list = RLMDynamicGetByName(self, propertyName) as! RLMSwiftCollectionBase
        return List<DynamicObject>(objc: list._rlmCollection as! RLMArray<AnyObject>)
    }

    // MARK: Dynamic set

    /**
     Returns a set of `DynamicObject`s for a given property name.

     - warning:  This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use instance variables or cast the values returned from key-value coding.

     - parameter propertyName: The name of the property.

     - returns: A set of `DynamicObject`s.

     :nodoc:
     */
    public func dynamicMutableSet(_ propertyName: String) -> MutableSet<DynamicObject> {
        if let dynamic = self as? DynamicObject {
            return dynamic[propertyName] as! MutableSet<DynamicObject>
        }
        let set = RLMDynamicGetByName(self, propertyName) as! RLMSwiftCollectionBase
        return MutableSet<DynamicObject>(objc: set._rlmCollection as! RLMSet<AnyObject>)
    }

    // MARK: Dynamic map

    /**
     Returns a map of `DynamicObject`s for a given property name.

     - warning:  This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use instance variables or cast the values returned from key-value coding.

     - parameter propertyName: The name of the property.

     - returns: A map with a given key type with `DynamicObject` as the value.

     :nodoc:
     */
    public func dynamicMap<Key: _MapKey>(_ propertyName: String) -> Map<Key, DynamicObject> {
        if let dynamic = self as? DynamicObject {
            return dynamic[propertyName] as! Map<Key, DynamicObject>
        }
        let base = RLMDynamicGetByName(self, propertyName) as! RLMSwiftCollectionBase
        return Map<Key, DynamicObject>(objc: base._rlmCollection as! RLMDictionary<AnyObject, AnyObject>)
    }

    // MARK: Comparison
    /**
     Returns whether two Realm objects are the same.

     Objects are considered the same if and only if they are both managed by the same
     Realm and point to the same underlying object in the database.

     - note: Equality comparison is implemented by `isEqual(_:)`. If the object type
             is defined with a primary key, `isEqual(_:)` behaves identically to this
             method. If the object type is not defined with a primary key,
             `isEqual(_:)` uses the `NSObject` behavior of comparing object identity.
             This method can be used to compare two objects for database equality
             whether or not their object type defines a primary key.

     - parameter object: The object to compare the receiver to.
     */
    public func isSameObject(as object: Object?) -> Bool {
        return RLMObjectBaseAreEqual(self, object)
    }
}

extension Object: ThreadConfined {
    /**
     Indicates if this object is frozen.

     - see: `Object.freeze()`
     */
    public var isFrozen: Bool { return realm?.isFrozen ?? false }

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
    public func freeze() -> Self {
        guard let realm = realm else { throwRealmException("Unmanaged objects cannot be frozen.") }
        return realm.freeze(self)
    }

    /**
     Returns a live (mutable) reference of this object.

     This method creates a managed accessor to a live copy of the same frozen object.
     Will return self if called on an already live object.
     */
    public func thaw() -> Self? {
        guard let realm = realm else { throwRealmException("Unmanaged objects cannot be thawed.") }
        return realm.thaw(self)
    }
}

/**
 Information about a specific property which changed in an `Object` change notification.
 */
@frozen public struct PropertyChange {
    /**
     The name of the property which changed.
    */
    public let name: String

    /**
     Value of the property before the change occurred. This is not supplied if
     the change happened on the same thread as the notification and for `List`
     properties.

     For object properties this will give the object which was previously
     linked to, but that object will have its new values and not the values it
     had before the changes. This means that `previousValue` may be a deleted
     object, and you will need to check `isInvalidated` before accessing any
     of its properties.
    */
    public let oldValue: Any?

    /**
     The value of the property after the change occurred. This is not supplied
     for `List` properties and will always be nil.
    */
    public let newValue: Any?
}

/**
 Information about the changes made to an object which is passed to `Object`'s
 notification blocks.
 */
@frozen public enum ObjectChange<T: ObjectBase> {
    /**
     If an error occurs, notification blocks are called one time with a `.error`
     result and an `NSError` containing details about the error. Currently the
     only errors which can occur are when opening the Realm on a background
     worker thread to calculate the change set. The callback will never be
     called again after `.error` is delivered.
     */
    case error(_ error: NSError)
    /**
     One or more of the properties of the object have been changed.
     */
    case change(_: T, _: [PropertyChange])
    /// The object has been deleted from the Realm.
    case deleted
}

/// Object interface which allows untyped getters and setters for Objects.
/// :nodoc:
@objc(RealmSwiftDynamicObject)
@dynamicMemberLookup
public final class DynamicObject: Object {
    public override subscript(key: String) -> Any? {
        get {
            let value = RLMDynamicGetByName(self, key).flatMap(coerceToNil)
            if let array = value as? RLMArray<AnyObject> {
                return List<DynamicObject>(objc: array)
            }
            if let set = value as? RLMSet<AnyObject> {
                return MutableSet<DynamicObject>(objc: set)
            }
            if let dictionary = value as? RLMDictionary<AnyObject, AnyObject> {
                return Map<String, DynamicObject>(objc: dictionary)
            }
            return value
        }
        set(value) {
            RLMDynamicValidatedSet(self, key, value)
        }
    }

    public subscript(dynamicMember member: String) -> Any? {
        get {
            self[member]
        }
        set(value) {
            self[member] = value
        }
    }

    /// :nodoc:
    public override func value(forUndefinedKey key: String) -> Any? {
        return self[key]
    }

    /// :nodoc:
    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
        self[key] = value
    }

    /// :nodoc:
    public override class func shouldIncludeInDefaultSchema() -> Bool {
        return false
    }

    override public class func sharedSchema() -> RLMObjectSchema? {
        nil
    }
}

/**
 An enum type which can be stored on a Realm Object.

 Only `@objc` enums backed by an Int can be stored on a Realm object, and the
 enum type must explicitly conform to this protocol. For example:

 ```
 @objc enum MyEnum: Int, RealmEnum {
    case first = 1
    case second = 2
    case third = 7
 }

 class MyModel: Object {
    @objc dynamic enumProperty = MyEnum.first
    let optionalEnumProperty = RealmOptional<MyEnum>()
 }
 ```
 */
public protocol RealmEnum: RealmOptionalType, _RealmSchemaDiscoverable {
    /// :nodoc:
    static func _rlmToRawValue(_ value: Any) -> Any
    /// :nodoc:
    static func _rlmFromRawValue(_ value: Any) -> Any?
}

// MARK: - Implementation

/// :nodoc:
public extension RealmEnum where Self: RawRepresentable, Self.RawValue: _RealmSchemaDiscoverable {
    static func _rlmToRawValue(_ value: Any) -> Any {
        return (value as! Self).rawValue
    }
    static func _rlmFromRawValue(_ value: Any) -> Any? {
        return Self(rawValue: value as! RawValue)
    }
    static func _rlmPopulateProperty(_ prop: RLMProperty) {
        RawValue._rlmPopulateProperty(prop)
    }
    static var _rlmType: PropertyType { RawValue._rlmType }
}

internal func dynamicSet(object: ObjectBase, key: String, value: Any?) {
    let bridgedValue: Any?
    if let v1 = value, let v2 = v1 as? CustomObjectiveCBridgeable {
        bridgedValue = v2.objCValue
    } else if let v1 = value, let v2 = v1 as? RealmEnum {
        bridgedValue = type(of: v2)._rlmToRawValue(v2)
    } else {
        bridgedValue = value
    }
    if RLMObjectBaseRealm(object) == nil {
        object.setValue(bridgedValue, forKey: key)
    } else {
        RLMDynamicValidatedSet(object, key, bridgedValue)
    }
}

// MARK: AssistedObjectiveCBridgeable

// FIXME: Remove when `as! Self` can be written
private func forceCastToInferred<T, V>(_ x: T) -> V {
    return x as! V
}

extension Object: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> Self {
        return forceCastToInferred(objectiveCValue)
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: unsafeCastToRLMObject(), metadata: nil)
    }
}

// MARK: Key Path Strings

extension ObjectBase {
    internal func prepareForRecording() {
        let objectSchema = ObjectSchema(RLMObjectBaseObjectSchema(self)!)
        (objectSchema.rlmObjectSchema.properties + objectSchema.rlmObjectSchema.computedProperties)
            .map { (prop: $0, accessor: $0.swiftAccessor) }
            .forEach { $0.accessor?.observe($0.prop, on: self) }
    }
}

/**
 Gets the components of a given key path as a string.

 - warning: Objects that declare properties with the old `@objc dynamic` syntax are not fully supported
 by this function, and it is recommened that you use `@Persisted` to declare your properties if you wish to use
 this function to its full benefit.

 Example:
 ```
 let name = ObjectBase._name(for: \Person.dogs[0].name) // "dogs.name"
 // Note that the above KeyPath expression is only supported with properties declared
 // with `@Persisted`.
 let nested = ObjectBase._name(for: \Person.address.city.zip) // "address.city.zip"
 ```
 */
public func _name<T: ObjectBase>(for keyPath: PartialKeyPath<T>) -> String {
    if let name = keyPath._kvcKeyPathString {
        return name
    }
    let traceObject = T()
    traceObject.lastAccessedNames = NSMutableArray()
    traceObject.prepareForRecording()
    let value = traceObject[keyPath: keyPath]
    if let collection = value as? PropertyNameConvertible,
       let propertyInfo = collection.propertyInformation,
       propertyInfo.isLegacy {
        traceObject.lastAccessedNames?.add(propertyInfo.key)
    }

    if let storage = value as? RLMSwiftValueStorage {
        traceObject.lastAccessedNames?.add(RLMSwiftValueStorageGetPropertyName(storage))
    }
    return traceObject.lastAccessedNames!.componentsJoined(by: ".")
}
