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

// MARK: MinMaxType

/**
 Types of properties which can be used with the minimum and maximum value APIs.

 - see: `min(ofProperty:)`, `max(ofProperty:)`
 */
public protocol MinMaxType {}
extension NSNumber: MinMaxType {}
extension Double: MinMaxType {}
extension Float: MinMaxType {}
extension Int: MinMaxType {}
extension Int8: MinMaxType {}
extension Int16: MinMaxType {}
extension Int32: MinMaxType {}
extension Int64: MinMaxType {}
extension Date: MinMaxType {}
extension NSDate: MinMaxType {}
extension Decimal128: MinMaxType {}
extension AnyRealmValue: MinMaxType {}

// MARK: AddableType

/**
 Types of properties which can be used with the sum and average value APIs.

 - see: `sum(ofProperty:)`, `average(ofProperty:)`
 */
public protocol AddableType {
    /// :nodoc:
    init()
}
extension NSNumber: AddableType {}
extension Double: AddableType {}
extension Float: AddableType {}
extension Int: AddableType {}
extension Int8: AddableType {}
extension Int16: AddableType {}
extension Int32: AddableType {}
extension Int64: AddableType {}
extension Decimal128: AddableType {}
extension AnyRealmValue: AddableType {}

/**
 `Results` is an auto-updating container type in Realm returned from object queries.

 `Results` can be queried with the same predicates as `List<Element>`, and you can
 chain queries to further filter query results.

 `Results` always reflect the current state of the Realm on the current thread, including during write transactions on
 the current thread. The one exception to this is when using `for...in` enumeration, which will always enumerate over
 the objects which matched the query when the enumeration is begun, even if some of them are deleted or modified to be
 excluded by the filter during the enumeration.

 `Results` are lazily evaluated the first time they are accessed; they only run queries when the result of the query is
 requested. This means that chaining several temporary `Results` to sort and filter your data does not perform any
 unnecessary work processing the intermediate state.

 Once the results have been evaluated or a notification block has been added, the results are eagerly kept up-to-date,
 with the work done to keep them up-to-date done on a background thread whenever possible.

 Results instances cannot be directly instantiated.
 */
@frozen public struct Results<Element: RealmCollectionValue>: Equatable {

    internal let rlmResults: RLMResults<AnyObject>

    /// A human-readable description of the objects represented by the results.
    public var description: String {
        return RLMDescriptionWithMaxDepth("Results", rlmResults, RLMDescriptionMaxDepth)
    }

    /// The type of the objects described by the results.
    public typealias ElementType = Element

    // MARK: Properties

    /// The Realm which manages this results. Note that this property will never return `nil`.
    public var realm: Realm? { return Realm(rlmResults.realm) }

    /**
     Indicates if the results are no longer valid.

     The results becomes invalid if `invalidate()` is called on the containing `realm`. An invalidated results can be
     accessed, but will always be empty.
     */
    public var isInvalidated: Bool { return rlmResults.isInvalidated }

    /// The number of objects in the results.
    public var count: Int { return Int(rlmResults.count) }

    // MARK: Initializers

    internal init(_ rlmResults: RLMResults<AnyObject>) {
        self.rlmResults = rlmResults
    }
    internal init(objc rlmResults: RLMResults<AnyObject>) {
        self.rlmResults = rlmResults
    }

    // MARK: Index Retrieval

    /**
     Returns the index of the given object in the results, or `nil` if the object is not present.
     */
    public func index(of object: Element) -> Int? {
        return notFoundToNil(index: rlmResults.index(of: object as AnyObject))
    }

    /**
     Returns the index of the first object matching the predicate, or `nil` if no objects match.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func index(matching predicate: NSPredicate) -> Int? {
        return notFoundToNil(index: rlmResults.indexOfObject(with: predicate))
    }

    // MARK: Object Retrieval

    /**
     Returns the object at the given `index`.

     - parameter index: The index.
     */
    public subscript(position: Int) -> Element {
        throwForNegativeIndex(position)
        return dynamicBridgeCast(fromObjectiveC: rlmResults.object(at: UInt(position)))
    }

    /// Returns the first object in the results, or `nil` if the results are empty.
    public var first: Element? { return rlmResults.firstObject().map(dynamicBridgeCast) }

    /// Returns the last object in the results, or `nil` if the results are empty.
    public var last: Element? { return rlmResults.lastObject().map(dynamicBridgeCast) }

    /**
     Returns an array containing the objects in the results at the indexes specified by a given index set.

     - warning Throws if an index supplied in the IndexSet is out of bounds.

     - parameter indexes: The indexes in the results to select objects from.
     */
    public func objects(at indexes: IndexSet) -> [Element] {
        guard let r = rlmResults.objects(at: indexes) else {
            throwRealmException("Indexes for Results are out of bounds")
        }
        return r.map(dynamicBridgeCast)
    }

    // MARK: KVC

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` with `key` on each of the results.

     - parameter key: The name of the property whose values are desired.
     */
    public func value(forKey key: String) -> Any? {
        return value(forKeyPath: key)
    }

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` with `keyPath` on each of the results.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    public func value(forKeyPath keyPath: String) -> Any? {
        return rlmResults.value(forKeyPath: keyPath)
    }

    /**
     Invokes `setValue(_:forKey:)` on each of the objects represented by the results using the specified `value` and
     `key`.

     - warning: This method may only be called during a write transaction.

     - parameter value: The object value.
     - parameter key:   The name of the property whose value should be set on each object.
     */
    public func setValue(_ value: Any?, forKey key: String) {
        return rlmResults.setValue(value, forKeyPath: key)
    }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the collection.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func filter(_ predicate: NSPredicate) -> Results<Element> {
        return Results<Element>(rlmResults.objects(with: predicate))
    }

    // MARK: Sorting

    /**
     Returns a `Results` containing the objects represented by the results, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a collection of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:   The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(byKeyPath keyPath: String, ascending: Bool = true) -> Results<Element> {
        return sorted(by: [SortDescriptor(keyPath: keyPath, ascending: ascending)])
    }

    /**
     Returns a `Results` containing the objects represented by the results, but sorted.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`

     - parameter sortDescriptors: A sequence of `SortDescriptor`s to sort by.
     */
    public func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element>
        where S.Iterator.Element == SortDescriptor {
            return Results<Element>(rlmResults.sortedResults(using: sortDescriptors.map { $0.rlmSortDescriptorValue }))
    }

    /**
     Returns a `Results` containing distinct objects based on the specified key paths

     - parameter keyPaths:  The key paths used produce distinct results
     */
    public func distinct<S: Sequence>(by keyPaths: S) -> Results<Element>
        where S.Iterator.Element == String {
            return Results<Element>(rlmResults.distinctResults(usingKeyPaths: Array(keyPaths)))
    }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the results, or `nil` if the results are empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmResults.min(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value of the given property among all the results, or `nil` if the results are empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmResults.max(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the sum of the values of a given property over all the results.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<T: AddableType>(ofProperty property: String) -> T {
        return dynamicBridgeCast(fromObjectiveC: rlmResults.sum(ofProperty: property))
    }

    /**
     Returns the average value of a given property over all the results, or `nil` if the results are empty.

     - warning: Only the name of a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose average value should be calculated.
     */
    public func average<T: AddableType>(ofProperty property: String) -> T? {
        return rlmResults.average(ofProperty: property).map(dynamicBridgeCast)
    }

    // MARK: Notifications

    /**
     Registers a block to be called each time the collection changes.

     The block will be asynchronously called with the initial results, and then called again after each write
     transaction which changes either any of the objects in the collection, or which objects are in the collection.

     The `change` parameter that is passed to the block reports, in the form of indices within the collection, which of
     the objects were added, removed, or modified during each write transaction. See the `RealmCollectionChange`
     documentation for more information on the change information supplied and an example of how to use it to update a
     `UITableView`.

     At the time when the block is called, the collection will be fully evaluated and up-to-date, and as long as you do
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
     let dogs = realm.objects(Dog.self)
     print("dogs.count: \(dogs?.count)") // => 0
     let token = dogs.observe { changes in
         switch changes {
         case .initial(let dogs):
             // Will print "dogs.count: 1"
             print("dogs.count: \(dogs.count)")
             break
         case .update:
             // Will not be hit in this example
             break
         case .error:
             break
         }
     }
     try! realm.write {
         let dog = Dog()
         dog.name = "Rex"
         person.dogs.append(dog)
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
    public func observe(on queue: DispatchQueue? = nil,
                        _ block: @escaping (RealmCollectionChange<Results>) -> Void) -> NotificationToken {
        return rlmResults.addNotificationBlock(wrapObserveBlock(block), queue: queue)
    }

    // MARK: Frozen Objects

    public var isFrozen: Bool {
        return rlmResults.isFrozen
    }

    public func freeze() -> Results {
        return Results(rlmResults.freeze())
    }

    public func thaw() -> Results? {
        return Results(rlmResults.thaw())
    }
}

extension Results: RealmCollection {
    // MARK: Sequence Support

    /// Returns a `RLMIterator` that yields successive elements in the results.
    public func makeIterator() -> RLMIterator<Element> {
        return RLMIterator(collection: rlmResults)
    }

    // MARK: Collection Support

    /// The position of the first element in a non-empty collection.
    /// Identical to endIndex in an empty collection.
    public var startIndex: Int { return 0 }

    /// The collection's "past the end" position.
    /// endIndex is not a valid argument to subscript, and is always reachable from startIndex by
    /// zero or more applications of successor().
    public var endIndex: Int { return count }

    public func index(after i: Int) -> Int { return i + 1 }
    public func index(before i: Int) -> Int { return i - 1 }

    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe(_ queue: DispatchQueue?,
                         _ block: @escaping (RealmCollectionChange<AnyRealmCollection<Element>>) -> Void)
        -> NotificationToken {
            return rlmResults.addNotificationBlock(wrapObserveBlock(block), queue: queue)
    }
}

// MARK: AssistedObjectiveCBridgeable

extension Results: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> Results {
        return Results(objectiveCValue as! RLMResults)
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: rlmResults, metadata: nil)
    }
}

// MARK: - Codable

extension Results: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in self {
            try container.encode(value)
        }
    }
}
