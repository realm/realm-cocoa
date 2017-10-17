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
     @objc dynamic var name: String = ""
     @objc dynamic var adopted: Bool = false
     let siblings = List<Dog>()
 }
 ```

 ### Supported property types

 - `String`, `NSString`
 - `Int`
 - `Int8`, `Int16`, `Int32`, `Int64`
 - `Float`
 - `Double`
 - `Bool`
 - `Date`, `NSDate`
 - `Data`, `NSData`
 - `RealmOptional<Value>` for optional numeric properties
 - `Object` subclasses, to model many-to-one relationships
 - `List<Element>`, to model many-to-many relationships

 `String`, `NSString`, `Date`, `NSDate`, `Data`, `NSData` and `Object` subclass properties can be declared as optional.
 `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `Float`, `Double`, `Bool`, and `List` properties cannot. To store an optional
 number, use `RealmOptional<Int>`, `RealmOptional<Float>`, `RealmOptional<Double>`, or `RealmOptional<Bool>` instead,
 which wraps an optional numeric value.

 All property types except for `List` and `RealmOptional` *must* be declared as `@objc dynamic var`. `List` and
 `RealmOptional` properties must be declared as non-dynamic `let` properties. Swift `lazy` properties are not allowed.

 Note that none of the restrictions listed above apply to properties that are configured to be ignored by Realm.

 ### Querying

 You can retrieve all objects of a given type from a Realm by calling the `objects(_:)` instance method.

 ### Relationships

 See our [Cocoa guide](http://realm.io/docs/cocoa) for more details.
 */
@objc(RealmSwiftObject)
open class Object: RLMObjectBase, ThreadConfined, RealmCollectionValue {
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public static func _rlmArray() -> RLMArray<AnyObject> {
        return RLMArray(objectClassName: className())
    }

    // MARK: Initializers

    /**
     Creates an unmanaged instance of a Realm object.

     Call `add(_:)` on a `Realm` instance to add an unmanaged object into that Realm.

     - see: `Realm().add(_:)`
     */
    public override required init() {
        super.init()
    }

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
    public init(value: Any) {
        super.init(value: value, schema: .partialPrivateShared())
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
    /// `invalidate()` is called on that Realm.
    public override final var isInvalidated: Bool { return super.isInvalidated }

    /// A human-readable description of the object.
    open override var description: String { return super.description }

    /**
     WARNING: This is an internal helper method not intended for public use.
     :nodoc:
     */
    public override final class func className() -> String {
        return super.className()
    }

    /**
     WARNING: This is an internal helper method not intended for public use.
     :nodoc:
     */
    public override final class func objectUtilClass(_ isSwift: Bool) -> AnyClass {
        return ObjectUtil.self
    }


    // MARK: Object Customization

    /**
     Override this method to specify the name of a property to be used as the primary key.

     Only properties of types `String` and `Int` can be designated as the primary key. Primary key properties enforce
     uniqueness for each value whenever the property is set, which incurs minor overhead. Indexes are created
     automatically for primary key properties.

     - returns: The name of the property designated as the primary key, or `nil` if the model has no primary key.
     */
    @objc open class func primaryKey() -> String? { return nil }

    /**
     Override this method to specify the names of properties to ignore. These properties will not be managed by
     the Realm that manages the object.

     - returns: An array of property names to ignore.
     */
    @objc open class func ignoredProperties() -> [String] { return [] }

    /**
     Returns an array of property names for properties which should be indexed.

     Only string, integer, boolean, `Date`, and `NSDate` properties are supported.

     - returns: An array of property names.
     */
    @objc open class func indexedProperties() -> [String] { return [] }

    // MARK: Key-Value Coding & Subscripting

    /// Returns or sets the value of the property with the given name.
    @objc open subscript(key: String) -> Any? {
        get {
            if realm == nil {
                return value(forKey: key)
            }
            return RLMDynamicGetByName(self, key, true)
        }
        set(value) {
            if realm == nil {
                setValue(value, forKey: key)
            } else {
                RLMDynamicValidatedSet(self, key, value)
            }
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

     Notifications are delivered via the standard run loop, and so can't be
     delivered while the run loop is blocked by other activity. When
     notifications can't be delivered instantly, multiple notifications may be
     coalesced into a single notification.

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

     - parameter block: The block to call with information about changes to the object.
     - returns: A token which must be held for as long as you want updates to be delivered.
     */
    public func observe(_ block: @escaping (ObjectChange) -> Void) -> NotificationToken {
        return RLMObjectAddNotificationBlock(self, { names, oldValues, newValues, error in
            if let error = error {
                block(.error(error as NSError))
                return
            }
            guard let names = names, let newValues = newValues else {
                block(.deleted)
                return
            }

            block(.change((0..<newValues.count).map { i in
                PropertyChange(name: names[i], oldValue: oldValues?[i], newValue: newValues[i])
            }))
        })
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
        return noWarnUnsafeBitCast(RLMDynamicGetByName(self, propertyName, true) as! RLMListBase,
                                   to: List<DynamicObject>.self)
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

    // MARK: Private functions

    // FIXME: None of these functions should be exposed in the public interface.

    /**
    WARNING: This is an internal initializer not intended for public use.
    :nodoc:
    */
    public override required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }

    /**
    WARNING: This is an internal initializer not intended for public use.
    :nodoc:
    */
    public override required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
}

/**
 Information about a specific property which changed in an `Object` change notification.
 */
public struct PropertyChange {
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
public enum ObjectChange {
    /**
     If an error occurs, notification blocks are called one time with a `.error`
     result and an `NSError` containing details about the error. Currently the
     only errors which can occur are when opening the Realm on a background
     worker thread to calculate the change set. The callback will never be
     called again after `.error` is delivered.
     */
    case error(_: NSError)
    /**
     One or more of the properties of the object have been changed.
     */
    case change(_: [PropertyChange])
    /// The object has been deleted from the Realm.
    case deleted
}

/// Object interface which allows untyped getters and setters for Objects.
/// :nodoc:
public final class DynamicObject: Object {
    public override subscript(key: String) -> Any? {
        get {
            let value = RLMDynamicGetByName(self, key, false)
            if let array = value as? RLMArray<AnyObject> {
                return List<DynamicObject>(rlmArray: array)
            }
            return value
        }
        set(value) {
            RLMDynamicValidatedSet(self, key, value)
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
}

/// :nodoc:
/// Internal class. Do not use directly.
@objc(RealmSwiftObjectUtil)
public class ObjectUtil: NSObject {
    @objc private class func swiftVersion() -> NSString {
        return swiftLanguageVersion as NSString
    }

    @objc private class func ignoredPropertiesForClass(_ type: AnyClass) -> NSArray? {
        if let type = type as? Object.Type {
            return type.ignoredProperties() as NSArray?
        }
        return nil
    }

    @objc private class func indexedPropertiesForClass(_ type: AnyClass) -> NSArray? {
        if let type = type as? Object.Type {
            return type.indexedProperties() as NSArray?
        }
        return nil
    }

    @objc private class func linkingObjectsPropertiesForClass(_ type: AnyClass) -> NSDictionary? {
        // Not used for Swift. getLinkingObjectsProperties(_:) is used instead.
        return nil
    }

    // If the property is a storage property for a lazy Swift property, return
    // the base property name (e.g. `foo.storage` becomes `foo`). Otherwise, nil.
    private static func baseName(forLazySwiftProperty name: String) -> String? {
        // A Swift lazy var shows up as two separate children on the reflection tree:
        // one named 'x', and another that is optional and is named 'x.storage'. Note
        // that '.' is illegal in either a Swift or Objective-C property name.
        if let storageRange = name.range(of: ".storage", options: [.anchored, .backwards]) {
            #if swift(>=4.0)
                return String(name[..<storageRange.lowerBound])
            #else
                return name.substring(to: storageRange.lowerBound)
            #endif
        }
        return nil
    }

    // Reflect an object, returning only children representing managed Realm properties.
    private static func getNonIgnoredMirrorChildren(for object: Any) -> [Mirror.Child] {
        let ignoredPropNames: Set<String>
        if let realmObject = object as? Object {
            ignoredPropNames = Set(type(of: realmObject).ignoredProperties())
        } else {
            ignoredPropNames = Set()
        }
        // No HKT in Swift, unfortunately
        return Mirror(reflecting: object).children.filter { (prop: Mirror.Child) -> Bool in
            guard let label = prop.label else {
                return false
            }
            if ignoredPropNames.contains(label) {
                // Ignored property.
                return false
            }
            if let lazyBaseName = baseName(forLazySwiftProperty: label) {
                if ignoredPropNames.contains(lazyBaseName) {
                    // Ignored lazy property.
                    return false
                }
                // Managed lazy property; not currently supported.
                // FIXME: revisit this once Swift gets property behaviors/property macros.
                throwRealmException("Lazy managed property '\(lazyBaseName)' is not allowed on a Realm Swift object"
                    + " class. Either add the property to the ignored properties list or make it non-lazy.")
            }
            return true
        }
    }

    // Build optional property metadata for a given property.
    // swiftlint:disable:next cyclomatic_complexity
    private static func getOptionalPropertyMetadata(for child: Mirror.Child, at index: Int) -> RLMGenericPropertyMetadata? {
        guard let name = child.label else {
            return nil
        }
        let mirror = Mirror(reflecting: child.value)
        let type = mirror.subjectType
        let code: PropertyType
        if type is Optional<String>.Type || type is Optional<NSString>.Type {
            code = .string
        } else if type is Optional<Date>.Type {
            code = .date
        } else if type is Optional<Data>.Type {
            code = .data
        } else if type is Optional<Object>.Type {
            code = .object
        } else if type is RealmOptional<Int>.Type ||
            type is RealmOptional<Int8>.Type ||
            type is RealmOptional<Int16>.Type ||
            type is RealmOptional<Int32>.Type ||
            type is RealmOptional<Int64>.Type {
            code = .int
        } else if type is RealmOptional<Float>.Type {
            code = .float
        } else if type is RealmOptional<Double>.Type {
            code = .double
        } else if type is RealmOptional<Bool>.Type {
            code = .bool
        } else if type is Optional<RealmInteger>.Type {
            code = .int
        } else if type is RealmInteger.Type {
            return nil
        } else if child.value is RLMOptionalBase {
            throwRealmException("'\(type)' is not a valid RealmOptional type.")
            code = .int // ignored
        } else if mirror.displayStyle == .optional || type is ExpressibleByNilLiteral.Type {
            return RLMGenericPropertyMetadata(forNilLiteralOptionalProperty: name, index: index)
        } else {
            return nil
        }
        return RLMGenericPropertyMetadata(forOptionalProperty: name, type: Int(code.rawValue), index: index)
    }

    @objc private class func getSwiftGenericProperties(_ object: Any) -> [RLMGenericPropertyMetadata] {
        return getNonIgnoredMirrorChildren(for: object).enumerated().flatMap { idx, prop in
            if let value = prop.value as? LinkingObjectsBase {
                return RLMGenericPropertyMetadata(forLinkingObjectsProperty: prop.label!,
                                                  className: value.objectClassName,
                                                  linkedPropertyName: value.propertyName,
                                                  index: idx)
            } else if prop.value is RLMListBase {
                return RLMGenericPropertyMetadata(forListProperty: prop.label!, index: idx)
            } else if let optional = getOptionalPropertyMetadata(for: prop, at: idx) {
                return optional
            }
            // TODO: what about RealmInteger?
            return nil
        }
    }

    @objc private class func requiredPropertiesForClass(_: Any) -> [String] {
        return []
    }
}

// MARK: AssistedObjectiveCBridgeable

// FIXME: Remove when `as! Self` can be written
private func forceCastToInferred<T, V>(_ x: T) -> V {
    return x as! V
}

extension Object: AssistedObjectiveCBridgeable {
    static func bridging(from objectiveCValue: Any, with metadata: Any?) -> Self {
        return forceCastToInferred(objectiveCValue)
    }

    var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: unsafeCastToRLMObject(), metadata: nil)
    }
}

// MARK: - Migration assistance

extension Object {
    /// :nodoc:
    @available(*, unavailable, renamed: "observe()")
    public func addNotificationBlock(_ block: @escaping (ObjectChange) -> Void) -> NotificationToken {
        fatalError()
    }

#if os(OSX)
#else
    /// :nodoc:
    @available(*, unavailable, renamed: "isSameObject(as:)") public func isEqual(to object: Any?) -> Bool {
        fatalError()
    }
#endif
}
