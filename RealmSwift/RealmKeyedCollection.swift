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

import Foundation
import Realm

/**
 A homogenous key-value collection of `Object`s which can be retrieved, filtered, sorted, and operated upon.
*/
public protocol RealmKeyedCollection: Sequence, ThreadConfined, CustomStringConvertible {
    /// The type of key associated with this collection
    associatedtype Key: _MapKey
    /// The type of value associated with this collection.
    associatedtype Value: RealmCollectionValue

    // MARK: Properties

    /// The Realm which manages the map, or `nil` if the map is unmanaged.
    var realm: Realm? { get }

    /// Indicates if the map can no longer be accessed.
    var isInvalidated: Bool { get }

    /// Returns the number of key-value pairs in this map.
    var count: Int { get }

     /// A human-readable description of the objects contained in the Map.
    var description: String { get }

    // MARK: Mutation

    /**
     Updates the value stored in the dictionary for the given key, or adds a new key-value pair if the key does not exist.

     - Note:If the value being added to the dictionary is an unmanaged object and the dictionary is managed
            then that unmanaged object will be added to the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter value: a value's key path predicate.
     - parameter forKey: The direction to sort in.
     */
    func updateValue(_ value: Value, forKey key: Key)

    /**
     Removes the given key and its associated object, only if the key exists in the dictionary. If the key does not
     exist, the dictionary will not be modified.

     - warning: This method may only be called during a write transaction.
     */
    func removeObject(for key: Key)

    /**
     Removes all objects from the dictionary. The objects are not removed from the Realm that manages them.

     - warning: This method may only be called during a write transaction.
     */
    func removeAll()

    /**
     Returns the value for a given key, or sets a value for a key should the subscript be used for an assign.

     - Note:If the value being added to the dictionary is an unmanaged object and the dictionary is managed
            then that unmanaged object will be added to the Realm.

     - Note:If the value being assigned for a key is `nil` then that key will be removed from the dictionary.

     - warning: This method may only be called during a write transaction.

     - parameter key: The key.
     */
    subscript(key: Key) -> Value? { get set }

    // MARK: KVC

    /**
     Returns a type of `Value` for a specified key if it exists in the map.

     Note that when using key-value coding, the key must be a string.

     - parameter key: The key to the property whose values are desired.
     */
    func value(forKey key: String) -> AnyObject?

    /**
     Returns a type of `Value` for a specified key if it exists in the map.

     - parameter keyPath: The key to the property whose values are desired.
     */
    func value(forKeyPath keyPath: String) -> AnyObject?

    /**
     Adds a given key-value pair to the dictionary or updates a given key should it already exist.

     - warning: This method can only be called during a write transaction.

     - parameter value: The object value.
     - parameter key:   The name of the property whose value should be set on each object.
    */
    func setValue(_ value: Any?, forKey key: String)

    // MARK: Filtering

    /**
     Returns a `Results` containing all matching values in the dictionary with the given predicate.

     - Note: This will return the values in the dictionary, and not the key-value pairs.

     - parameter predicate: The predicate with which to filter the values.
     */
    func filter(_ predicate: NSPredicate) -> Results<Value>

    /**
     Returns a Boolean value indicating whether the Map contains the key-value pair
     satisfies the given predicate

     - parameter where: a closure that test if any key-pair of the given map represents the match.
     */
    func contains(where predicate: @escaping (_ key: Key, _ value: Value) -> Bool) -> Bool

    // MARK: Sorting

    /**
     Returns a `Results` containing the objects in the dictionary, but sorted.

     Objects are sorted based on their values. For example, to sort a dictionary of `Date`s from
     neweset to oldest based, you might call `dates.sorted(ascending: true)`.

     - parameter ascending: The direction to sort in.
     */
    func sorted(ascending: Bool) -> Results<Value>

    /**
     Returns a `Results` containing the objects in the dictionary, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a dictionary of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: Dictionaries may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:  The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    func sorted(byKeyPath keyPath: String, ascending: Bool) -> Results<Value>

    /**
     Returns a `Results` containing the objects in the dictionary, but sorted.

     - warning: Dictionaries may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`
    */
    func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Value>
        where S.Iterator.Element == SortDescriptor

    /// Returns all of the keys in this dictionary.
    var keys: [Key] { get }

    /// Returns all of the values in the dictionary.
    var values: [Value] { get }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the objects in the collection, or `nil` if the
     dictionary is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    func min<T: MinMaxType>(ofProperty property: String) -> T?

    /**
     Returns the maximum (highest) value of the given property among all the objects in the dictionary, or `nil` if the
     dictionary is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    func max<T: MinMaxType>(ofProperty property: String) -> T?

    /**
    Returns the sum of the given property for objects in the dictionary, or `nil` if the dictionary is empty.

    - warning: Only names of properties of a type conforming to the `AddableType` protocol can be used.

    - parameter property: The name of a property conforming to `AddableType` to calculate sum on.
    */
    func sum<T: AddableType>(ofProperty property: String) -> T

    /**
     Returns the average value of a given property over all the objects in the dictionary, or `nil` if
     the dictionary is empty.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    func average<T: AddableType>(ofProperty property: String) -> T?

    // MARK: Notifications

    /**
     Registers a block to be called each time the dictionary changes.

     The block will be asynchronously called with the initial dictionary, and then called again after each write
     transaction which changes either any of the keys or values in the dictionary.

     The `change` parameter that is passed to the block reports, in the form of keys within the dictionary, which of
     the key-value pairs were added, removed, or modified during each write transaction.

     At the time when the block is called, the dictionary will be fully evaluated and up-to-date, and as long as you do
     not perform a write transaction on the same thread or explicitly call `realm.refresh()`, accessing it will never
     perform blocking work.

     If no queue is given, notifications are delivered via the standard run loop, and so can't be delivered while the
     run loop is blocked by other activity. If a queue is given, notifications are delivered to that queue instead. When
     notifications can't be delivered instantly, multiple notifications may be coalesced into a single notification.
     This can include the notification with the initial collection.

     For example, the following code performs a write transaction immediately after adding the notification block, so
     there is no opportunity for the initial notification to be delivered first. As a result, the initial notification
     will reflect the state of the Realm after the write transaction.

     ```swift
     let myStringMap = myObject.stringMap
     print("myStringMap.count: \(myStringMap?.count)") // => 0
     let token = myStringMap.observe { changes in
         switch changes {
         case .initial(let myStringMap):
             // Will print "myStringMap.count: 1"
             print("myStringMap.count: \(myStringMap.count)")
            print("Dog Name: \(myStringMap["nameOfDog"])") // => "Rex"
             break
         case .update:
             // Will not be hit in this example
             break
         case .error:
             break
         }
     }
     try! realm.write {
         myStringMap["nameOfDog"] = "Rex"
     }
     // end of run loop execution context
     ```

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `invalidate()` on the token.

     - warning: This method cannot be called during a write transaction, or when the containing Realm is read-only.

     - parameter queue: The serial dispatch queue to receive notification on. If
                        `nil`, notifications are delivered to the current thread.
     - parameter block: The block to be called whenever a change occurs.
     - returns: A token which must be held for as long as you want updates to be delivered.
     */
    func observe(on queue: DispatchQueue?,
                 _ block: @escaping (RealmMapChange<Self>) -> Void)
    -> NotificationToken

    // MARK: Frozen Objects

    /// Returns if this collection is frozen
    var isFrozen: Bool { get }

    /**
     Returns a frozen (immutable) snapshot of this collection.

     The frozen copy is an immutable collection which contains the same data as this collection
    currently contains, but will not update when writes are made to the containing Realm. Unlike
    live collections, frozen collections can be accessed from any thread.

     - warning: This method cannot be called during a write transaction, or when the containing
    Realm is read-only.
     - warning: Holding onto a frozen collection for an extended period while performing write
     transaction on the Realm may result in the Realm file growing to large sizes. See
     `Realm.Configuration.maximumNumberOfActiveVersions` for more information.
    */
    func freeze() -> Self

    /**
     Returns a live (mutable) version of this frozen collection.

     This method resolves a reference to a live copy of the same frozen collection.
     If called on a live collection, will return itself.
    */
    func thaw() -> Self?
}

/**
 Protocol for RealmKeyedCollections where the Value is of an Object type that
 enables aggregatable operations.
 */
public extension RealmKeyedCollection where Value: OptionalProtocol, Value.Wrapped: ObjectBase, Value.Wrapped: RealmCollectionValue {
    /**
     Returns the minimum (lowest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter keyPath: The keyPath of a property whose minimum value is desired.
     */
    func min<T: MinMaxType>(of keyPath: KeyPath<Value.Wrapped, T>) -> T? {
        min(ofProperty: _name(for: keyPath))
    }

    /**
     Returns the maximum (highest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter keyPath: The keyPath of a property whose minimum value is desired.
     */
    func max<T: MinMaxType>(of keyPath: KeyPath<Value.Wrapped, T>) -> T? {
        max(ofProperty: _name(for: keyPath))
    }

    /**
    Returns the sum of the given property for objects in the collection, or `nil` if the collection is empty.

    - warning: Only names of properties of a type conforming to the `AddableType` protocol can be used.

    - parameter keyPath: The keyPath of a property conforming to `AddableType` to calculate sum on.
    */
    func sum<T: AddableType>(of keyPath: KeyPath<Value.Wrapped, T>) -> T {
        sum(ofProperty: _name(for: keyPath))
    }

    /**
     Returns the average value of a given property over all the objects in the collection, or `nil` if
     the collection is empty.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter keyPath: The keyPath of a property whose values should be summed.
     */
    func average<T: AddableType>(of keyPath: KeyPath<Value.Wrapped, T>) -> T? {
        average(ofProperty: _name(for: keyPath))
    }
}

// MARK: Sortable

/**
 Protocol for RealmKeyedCollections where the Value is of an Object type that
 enables sortable operations.
 */
public extension RealmKeyedCollection where Value: OptionalProtocol, Value.Wrapped: ObjectBase, Value.Wrapped: RealmCollectionValue {
    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a collection of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:   The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    func sorted<T: Comparable>(by keyPath: KeyPath<Value.Wrapped, T>, ascending: Bool) -> Results<Value> {
        sorted(byKeyPath: _name(for: keyPath), ascending: ascending)
    }
}

public extension RealmKeyedCollection where Value: MinMaxType {
    /**
     Returns the minimum (lowest) value of the collection, or `nil` if the collection is empty.
     */
    func min() -> Value? {
        return min(ofProperty: "self")
    }
    /**
     Returns the maximum (highest) value of the collection, or `nil` if the collection is empty.
     */
    func max() -> Value? {
        return max(ofProperty: "self")
    }
}

public extension RealmKeyedCollection where Value: OptionalProtocol, Value.Wrapped: MinMaxType {
    /**
     Returns the minimum (lowest) value of the collection, or `nil` if the collection is empty.
     */
    func min() -> Value.Wrapped? {
        return min(ofProperty: "self")
    }
    /**
     Returns the maximum (highest) value of the collection, or `nil` if the collection is empty.
     */
    func max() -> Value.Wrapped? {
        return max(ofProperty: "self")
    }
}

public extension RealmKeyedCollection where Value: AddableType {
    /**
     Returns the sum of the values in the collection, or `nil` if the collection is empty.
     */
    func sum() -> Value {
        return sum(ofProperty: "self")
    }
    /**
     Returns the average of all of the values in the collection.
     */
    func average<T: AddableType>() -> T? {
        return average(ofProperty: "self")
    }
}

public extension RealmKeyedCollection where Value: OptionalProtocol, Value.Wrapped: AddableType {
    /**
     Returns the sum of the values in the collection, or `nil` if the collection is empty.
     */
    func sum() -> Value.Wrapped {
        return sum(ofProperty: "self")
    }
    /**
     Returns the average of all of the values in the collection.
     */
    func average<T: AddableType>() -> T? {
        return average(ofProperty: "self")
    }
}

public extension RealmKeyedCollection where Value: Comparable {
    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on their values. For example, to sort a collection of `Date`s from
     neweset to oldest based, you might call `dates.sorted(ascending: true)`.

     - parameter ascending: The direction to sort in.
     */
    func sorted(ascending: Bool = true) -> Results<Value> {
        return sorted(byKeyPath: "self", ascending: ascending)
    }
}

public extension RealmKeyedCollection where Value: OptionalProtocol, Value.Wrapped: Comparable {
    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on their values. For example, to sort a collection of `Date`s from
     neweset to oldest based, you might call `dates.sorted(ascending: true)`.

     - parameter ascending: The direction to sort in.
     */
    func sorted(ascending: Bool = true) -> Results<Value> {
        return sorted(byKeyPath: "self", ascending: ascending)
    }
}
