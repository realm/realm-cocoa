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

import Foundation
import Realm
import Realm.Private

/**
 `MutableSet` is the container type in Realm used to define to-many relationships with distinct values as objects.

 Like Swift's `Set`, `MutableSet` is a generic type that is parameterized on the type it stores. This can be either an `Object`
 subclass or one of the following types: `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `Float`, `Double`,
 `String`, `Data`, `Date`, `Decimal128`, and `ObjectId` (and their optional versions)

 Unlike Swift's native collections, `MutableSet`s are reference types, and are only immutable if the Realm that manages them
 is opened as read-only.

 MutableSet's can be filtered and sorted with the same predicates as `Results<Element>`.

 Properties of `MutableSet` type defined on `Object` subclasses must be declared as `let` and cannot be `dynamic`.
 */
public final class MutableSet<Element: RealmCollectionValue>: RLMSwiftCollectionBase {

    // MARK: Properties

    /// The Realm which manages the set, or `nil` if the set is unmanaged.
    public var realm: Realm? {
        return rlmSet.realm.map { Realm($0) }
    }

    /// Indicates if the set can no longer be accessed.
    public var isInvalidated: Bool { return rlmSet.isInvalidated }

    internal var rlmSet: RLMSet<AnyObject> {
        _rlmCollection as! RLMSet
    }

    // MARK: Initializers

    /// Creates a `MutableSet` that holds Realm model objects of type `Element`.
    public override init() {
        super.init()
    }

    internal init(objc rlmSet: RLMSet<AnyObject>) {
        super.init(collection: rlmSet)
    }

    // MARK: Count

    /// Returns the number of objects in this MutableSet.
    public var count: Int { return Int(rlmSet.count) }

    // MARK: KVC

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` using `key` on each of the collection's
     objects.
     */
    @nonobjc public func value(forKey key: String) -> [AnyObject] {
        return (rlmSet.value(forKeyPath: key)! as! NSSet).allObjects as [AnyObject]
    }

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` using `keyPath` on each of the
     collection's objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    @nonobjc public func value(forKeyPath keyPath: String) -> [AnyObject] {
        return (rlmSet.value(forKeyPath: keyPath)! as! NSSet).allObjects as [AnyObject]
    }

    /**
     Invokes `setValue(_:forKey:)` on each of the collection's objects using the specified `value` and `key`.

     - warning: This method can only be called during a write transaction.

     - parameter value: The object value.
     - parameter key:   The name of the property whose value should be set on each object.
    */
    public override func setValue(_ value: Any?, forKey key: String) {
        return rlmSet.setValue(value, forKeyPath: key)
    }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the set.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func filter(_ predicate: NSPredicate) -> Results<Element> {
        return Results<Element>(rlmSet.objects(with: predicate))
    }

    /**
     Returns a Boolean value indicating whether the Set contains the
     given object.

     - parameter object: The element to find in the MutableSet.
     */
    public func contains(_ object: Element) -> Bool {
        return rlmSet.contains(dynamicBridgeCast(fromSwift: object) as AnyObject)
    }

    /**
     Returns a Boolean value that indicates whether this set is a subset
     of the given set.

     - Parameter object: Another MutableSet to compare.
     */
    public func isSubset(of possibleSuperset: MutableSet<Element>) -> Bool {
        return rlmSet.isSubset(of: possibleSuperset.rlmSet)
    }

    /**
     Returns a Boolean value that indicates whether this set intersects
     with another given set.

     - Parameter object: Another MutableSet to compare.
     */
    public func intersects(_ otherSet: MutableSet<Element>) -> Bool {
        return rlmSet.intersects(otherSet.rlmSet)
    }

    // MARK: Sorting

    /**
     Returns a `Results` containing the objects in the set, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a set of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: MutableSets may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:  The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(byKeyPath keyPath: String, ascending: Bool = true) -> Results<Element> {
        return sorted(by: [SortDescriptor(keyPath: keyPath, ascending: ascending)])
    }

    /**
     Returns a `Results` containing the objects in the set, but sorted.

     - warning: MutableSets may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`
    */
    public func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element>
        where S.Iterator.Element == SortDescriptor {
            return Results<Element>(rlmSet.sortedResults(using: sortDescriptors.map { $0.rlmSortDescriptorValue }))
    }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the objects in the set, or `nil` if the set is
     empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmSet.min(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value of the given property among all the objects in the set, or `nil` if the set
     is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose maximum value is desired.
     */
    public func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmSet.max(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the sum of the values of a given property over all the objects in the set.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<T: AddableType>(ofProperty property: String) -> T {
        return dynamicBridgeCast(fromObjectiveC: rlmSet.sum(ofProperty: property))
    }

    /**
     Returns the average value of a given property over all the objects in the set, or `nil` if the set is empty.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose average value should be calculated.
     */
    public func average<T: AddableType>(ofProperty property: String) -> T? {
        return rlmSet.average(ofProperty: property).map(dynamicBridgeCast)
    }

    // MARK: Mutation

    /**
     Inserts an object to the set if not already present.

     - warning: This method may only be called during a write transaction.

     - parameter object: An object.
     */
    public func insert(_ object: Element) {
        rlmSet.add(dynamicBridgeCast(fromSwift: object) as AnyObject)
    }

    /**
     Inserts the given sequence of objects into the set if not already present.

     - warning: This method may only be called during a write transaction.
    */
    public func insert<S: Sequence>(objectsIn objects: S) where S.Iterator.Element == Element {
        for obj in objects {
            rlmSet.add(dynamicBridgeCast(fromSwift: obj) as AnyObject)
        }
    }

    /**
     Removes an object in the set if present. The object is not removed from the Realm that manages it.

     - warning: This method may only be called during a write transaction.

     - parameter object: The object to remove.
     */
    public func remove(_ object: Element) {
        rlmSet.remove(dynamicBridgeCast(fromSwift: object) as AnyObject)
    }

    /**
     Removes all objects from the set. The objects are not removed from the Realm that manages them.

     - warning: This method may only be called during a write transaction.
     */
    public func removeAll() {
        rlmSet.removeAllObjects()
    }

    /**
     Mutates the set in place with the elements that are common to both this set and the given sequence.

     - warning: This method may only be called during a write transaction.

     - parameter other: Another set.
     */
    public func formIntersection(_ other: MutableSet<Element>) {
        rlmSet.intersect(other.rlmSet)
    }

    /**
     Mutates the set in place and removes the elements of the given set from this set.

     - warning: This method may only be called during a write transaction.

     - parameter other: Another set.
     */
    public func subtract(_ other: MutableSet<Element>) {
        rlmSet.minus(other.rlmSet)
    }

    /**
     Inserts the elements of the given sequence into the set.

     - warning: This method may only be called during a write transaction.

     - parameter other: Another set.
     */
    public func formUnion(_ other: MutableSet<Element>) {
        rlmSet.union(other.rlmSet)
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
     let results = realm.objects(Dog.self)
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
         person.dogs.insert(dog)
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
                        _ block: @escaping (RealmCollectionChange<MutableSet>) -> Void) -> NotificationToken {
        return rlmSet.addNotificationBlock(wrapObserveBlock(block), queue: queue)
    }

    // MARK: Frozen Objects

    public var isFrozen: Bool {
        return rlmSet.isFrozen
    }

    public func freeze() -> MutableSet {
        return MutableSet(objc: rlmSet.freeze())
    }

    public func thaw() -> MutableSet? {
        return MutableSet(objc: rlmSet.thaw())
    }

    // swiftlint:disable:next identifier_name
    @objc class func _unmanagedCollection() -> RLMSet<AnyObject> {
        if let type = Element.self as? ObjectBase.Type {
            return RLMSet(objectClassName: type.className())
        }
        return RLMSet(objectType: Element._rlmType, optional: Element._rlmOptional)
    }

    /// :nodoc:
    @objc public override class func _backingCollectionType() -> AnyClass {
        return RLMManagedSet.self
    }

    // Printable requires a description property defined in Swift (and not obj-c),
    // and it has to be defined as override, which can't be done in a
    // generic class.
    /// Returns a human-readable description of the objects contained in the MutableSet.
    @objc public override var description: String {
        return descriptionWithMaxDepth(RLMDescriptionMaxDepth)
    }

    @objc private func descriptionWithMaxDepth(_ depth: UInt) -> String {
        return RLMDescriptionWithMaxDepth("MutableSet", rlmSet, depth)
    }
}

extension MutableSet where Element: MinMaxType {
    /**
     Returns the minimum (lowest) value in the set, or `nil` if the set is empty.
     */
    public func min() -> Element? {
        return rlmSet.min(ofProperty: "self").map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value in the set, or `nil` if the set is empty.
     */
    public func max() -> Element? {
        return rlmSet.max(ofProperty: "self").map(dynamicBridgeCast)
    }
}

extension MutableSet where Element: AddableType {
    /**
     Returns the sum of the values in the set.
     */
    public func sum() -> Element {
        return sum(ofProperty: "self")
    }

    /**
     Returns the average of the values in the set, or `nil` if the set is empty.
     */
    public func average<T: AddableType>() -> T? {
        return average(ofProperty: "self")
    }
}

extension MutableSet: RealmCollection {
    /// The type of the objects stored within the set.
    public typealias ElementType = Element

    // MARK: Sequence Support

    /// Returns a `RLMIterator` that yields successive elements in the `MutableSet`.
    public func makeIterator() -> RLMIterator<Element> {
        return RLMIterator(collection: rlmSet)
    }

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
            return rlmSet.addNotificationBlock(wrapObserveBlock(block), queue: queue)
    }

    // MARK: Object Retrieval

    /**
     - warning: Ordering is not guaranteed on a MutableSet. Subscripting is implemented for
                convenience should not be relied on.
     */
    public subscript(position: Int) -> Element {
        throwForNegativeIndex(position)
        return dynamicBridgeCast(fromObjectiveC: rlmSet.object(at: UInt(position)))
    }

    /// :nodoc:
    public func index(of object: Element) -> Int? {
        fatalError("index(of:) is not available on MutableSet")
    }

    /// :nodoc:
    public func index(matching predicate: NSPredicate) -> Int? {
        fatalError("index(matching:) is not available on MutableSet")
    }

    /// :nodoc:
    public func objects(at indexes: IndexSet) -> [Element] {
        fatalError("objects(at indexes:) is not available on MutableSet")
    }

    /**
     - warning: Ordering is not guaranteed on a MutableSet. `first` is implemented for
                convenience should not be relied on.
     */
    public var first: Element? {
        guard count > 0 else {
            return nil
        }
        return self[0]
    }
}

// MARK: - Codable

extension MutableSet: Decodable where Element: Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init()
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            insert(try container.decode(Element.self))
        }
    }
}

extension MutableSet: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in self {
            try container.encode(value)
        }
    }
}

// MARK: - AssistedObjectiveCBridgeable

extension MutableSet: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> MutableSet {
        guard let objectiveCValue = objectiveCValue as? RLMSet<AnyObject> else { preconditionFailure() }
        return MutableSet(objc: objectiveCValue)
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: rlmSet, metadata: nil)
    }
}
