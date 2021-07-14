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

/**
 An iterator for a `RealmCollection` instance.
 */
@frozen public struct RLMIterator<Element: RealmCollectionValue>: IteratorProtocol {
    private var generatorBase: NSFastEnumerationIterator

    init(collection: RLMCollection) {
        generatorBase = NSFastEnumerationIterator(collection)
    }

    /// Advance to the next element and return it, or `nil` if no next element exists.
    public mutating func next() -> Element? {
        guard let next = generatorBase.next() else { return nil }
        if let value = next as? Element {
            return value
        }
        if next is NSNull {
            return Element._nilValue()
        }
        return dynamicBridgeCast(fromObjectiveC: next) as Element
    }
}

/// :nodoc:
public protocol _RealmMapValue {
    /// The key of this element.
    associatedtype Key: _MapKey
    /// The value of this element.
    associatedtype Value: RealmCollectionValue
}

/**
 An iterator for a `RealmKeyedCollection` instance.
 */
@frozen public struct RLMMapIterator<Element: _RealmMapValue>: IteratorProtocol {

    private var generatorBase: NSFastEnumerationIterator
    private var collection: RLMDictionary<AnyObject, AnyObject>

    init(collection: RLMDictionary<AnyObject, AnyObject>) {
        self.collection = collection
        generatorBase = NSFastEnumerationIterator(collection)
    }

    /// Advance to the next element and return it, or `nil` if no next element exists.
    public mutating func next() -> Element? {
        let next = generatorBase.next()
        if let next = next as? Element.Key {
            let key: Element.Key = next
            let val: Element.Value = dynamicBridgeCast(fromObjectiveC: collection[key as AnyObject]!)
            return SingleMapEntry(key: key, value: val) as? Element
        }
        return nil
    }
}

/**
 An iterator for `Map<Key, Value>` which produces `(key: Key, value: Value)` pairs for each entry in the map.
 */
@frozen public struct RLMKeyValueIterator<Key: _MapKey, Value: RealmCollectionValue>: IteratorProtocol {
    private var generatorBase: NSFastEnumerationIterator
    private var collection: RLMDictionary<AnyObject, AnyObject>
    public typealias Element = (key: Key, value: Value)

    init(collection: RLMDictionary<AnyObject, AnyObject>) {
        self.collection = collection
        generatorBase = NSFastEnumerationIterator(collection)
    }

    /// Advance to the next element and return it, or `nil` if no next element exists.
    public mutating func next() -> Element? {
        let next = generatorBase.next()
        if let key = next as? Key,
           let value = collection[key as AnyObject].map(dynamicBridgeCast) as? Value {
            return (key: key, value: value)
        }
        return nil
    }
}

/**
 A `RealmCollectionChange` value encapsulates information about changes to collections
 that are reported by Realm notifications.

 The change information is available in two formats: a simple array of row
 indices in the collection for each type of change, and an array of index paths
 in a requested section suitable for passing directly to `UITableView`'s batch
 update methods.

 The arrays of indices in the `.update` case follow `UITableView`'s batching
 conventions, and can be passed as-is to a table view's batch update functions after being converted to index paths.
 For example, for a simple one-section table view, you can do the following:

 ```swift
 self.notificationToken = results.observe { changes in
     switch changes {
     case .initial:
         // Results are now populated and can be accessed without blocking the UI
         self.tableView.reloadData()
         break
     case .update(_, let deletions, let insertions, let modifications):
         // Query results have changed, so apply them to the TableView
         self.tableView.beginUpdates()
         self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) },
            with: .automatic)
         self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) },
            with: .automatic)
         self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) },
            with: .automatic)
         self.tableView.endUpdates()
         break
     case .error(let err):
         // An error occurred while opening the Realm file on the background worker thread
         fatalError("\(err)")
         break
     }
 }
 ```
 */
@frozen public enum RealmCollectionChange<CollectionType> {
    /**
     `.initial` indicates that the initial run of the query has completed (if
     applicable), and the collection can now be used without performing any
     blocking work.
     */
    case initial(CollectionType)

    /**
     `.update` indicates that a write transaction has been committed which
     either changed which objects are in the collection, and/or modified one
     or more of the objects in the collection.

     All three of the change arrays are always sorted in ascending order.

     - parameter deletions:     The indices in the previous version of the collection which were removed from this one.
     - parameter insertions:    The indices in the new collection which were added in this version.
     - parameter modifications: The indices of the objects in the new collection which were modified in this version.
     */
    case update(CollectionType, deletions: [Int], insertions: [Int], modifications: [Int])

    /**
     If an error occurs, notification blocks are called one time with a `.error`
     result and an `NSError` containing details about the error. This can only
     currently happen if opening the Realm on a background thread to calcuate
     the change set fails. The callback will never be called again after it is
     invoked with a .error value.
     */
    case error(Error)

    static func fromObjc(value: CollectionType?, change: RLMCollectionChange?, error: Error?) -> RealmCollectionChange {
        if let error = error {
            return .error(error)
        }
        if let change = change {
            return .update(value!,
                deletions: forceCast(change.deletions, to: [Int].self),
                insertions: forceCast(change.insertions, to: [Int].self),
                modifications: forceCast(change.modifications, to: [Int].self))
        }
        return .initial(value!)
    }
}

private func forceCast<A, U>(_ from: A, to type: U.Type) -> U {
    return from as! U
}

/// A type which can be stored in a Realm List, MutableSet, or Results.
///
/// Declaring additional types as conforming to this protocol will not make them
/// actually work. Most of the logic for how to store values in Realm is not
/// implemented in Swift and there is currently no extension mechanism for
/// supporting more types.
public protocol RealmCollectionValue: Hashable, _RealmSchemaDiscoverable {
    /// :nodoc:
    // Iterating over collections requires mapping NSNull to nil, but we can't
    // just do `nil as T` because of non-nullable collections
    static func _nilValue() -> Self
    /// :nodoc:
    // If we are in key path tracing mode, instantiate an empty object and forward
    // the lastAccessedNames array.
    static func _rlmKeyPathRecorder(with lastAccessedNames: NSMutableArray) -> Self
    /// :nodoc:
    // Get the zero/empty/nil value for this type. Used to supply a default
    // when the user does not declare one in their model. When `forceDefaultInitialization`
    // is true we *must* return a non-nil, default instance of `Self`. The latter is
    // used in conjunction with key path string tracing.
    static func _rlmDefaultValue(_ forceDefaultInitialization: Bool) -> Self
}

extension RealmCollectionValue {
    /// :nodoc:
    public static func _nilValue() -> Self {
        fatalError("unexpected NSNull for non-Optional type")
    }
    /// :nodoc:
    public static func _rlmKeyPathRecorder(with lastAccessedNames: NSMutableArray) -> Self {
        let value = Self._rlmDefaultValue(true)
        if let value = value as? ObjectBase {
            value.lastAccessedNames = lastAccessedNames
            value.prepareForRecording()
        }
        return value
    }
}

extension Int: RealmCollectionValue {}
extension Int8: RealmCollectionValue {}
extension Int16: RealmCollectionValue {}
extension Int32: RealmCollectionValue {}
extension Int64: RealmCollectionValue {}
extension Float: RealmCollectionValue {}
extension Double: RealmCollectionValue {}
extension Bool: RealmCollectionValue {}
extension String: RealmCollectionValue {}
extension Date: RealmCollectionValue {}
extension Data: RealmCollectionValue {}
extension Decimal128: RealmCollectionValue {}
extension ObjectId: RealmCollectionValue {}
extension UUID: RealmCollectionValue {}

extension AnyRealmValue: RealmCollectionValue {
    /// :nodoc:
    public static func _nilValue() -> AnyRealmValue {
        return .none
    }
}

extension Optional: RealmCollectionValue where Wrapped: RealmCollectionValue,
                                               Wrapped: _DefaultConstructible {
    /// :nodoc:
    public static func _rlmDefaultValue(_ forceDefaultInitialization: Bool) -> Optional<Wrapped> {
        if forceDefaultInitialization {
            return Wrapped()
        }
        return .none
    }

    /// :nodoc:
    public static func _nilValue() -> Optional {
        return nil
    }
}

/// :nodoc:
public protocol RealmCollectionBase: RandomAccessCollection, LazyCollectionProtocol, CustomStringConvertible, ThreadConfined where Element: RealmCollectionValue {
    // This typealias was needed with Swift 3.1. It no longer is, but remains
    // just in case someone was depending on it
    typealias ElementType = Element
}

/**
 A homogenous collection of `Object`s which can be retrieved, filtered, sorted, and operated upon.
*/
public protocol RealmCollection: RealmCollectionBase {
    // Must also conform to `AssistedObjectiveCBridgeable`

    // MARK: Properties

    /// The Realm which manages the collection, or `nil` for unmanaged collections.
    var realm: Realm? { get }

    /**
     Indicates if the collection can no longer be accessed.

     The collection can no longer be accessed if `invalidate()` is called on the `Realm` that manages the collection.
     */
    var isInvalidated: Bool { get }

    /// The number of objects in the collection.
    var count: Int { get }

    /// A human-readable description of the objects contained in the collection.
    var description: String { get }


    // MARK: Index Retrieval

    /**
     Returns the index of an object in the collection, or `nil` if the object is not present.

     - parameter object: An object.
     */
    func index(of object: Element) -> Int?

    /**
     Returns the index of the first object matching the predicate, or `nil` if no objects match.

     - parameter predicate: The predicate to use to filter the objects.
     */
    func index(matching predicate: NSPredicate) -> Int?

    /**
     Returns the index of the first object matching the predicate, or `nil` if no objects match.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    func index(matching predicateFormat: String, _ args: Any...) -> Int?


    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the collection.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    func filter(_ predicateFormat: String, _ args: Any...) -> Results<Element>

    /**
     Returns a `Results` containing all objects matching the given predicate in the collection.

     - parameter predicate: The predicate to use to filter the objects.
     */
    func filter(_ predicate: NSPredicate) -> Results<Element>


    // MARK: Sorting

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
    func sorted(byKeyPath keyPath: String, ascending: Bool) -> Results<Element>

    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`

     - parameter sortDescriptors: A sequence of `SortDescriptor`s to sort by.
     */
    func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element> where S.Iterator.Element == SortDescriptor

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    func min<T: MinMaxType>(ofProperty property: String) -> T?

    /**
     Returns the maximum (highest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    func max<T: MinMaxType>(ofProperty property: String) -> T?

    /**
    Returns the sum of the given property for objects in the collection, or `nil` if the collection is empty.

    - warning: Only names of properties of a type conforming to the `AddableType` protocol can be used.

    - parameter property: The name of a property conforming to `AddableType` to calculate sum on.
    */
    func sum<T: AddableType>(ofProperty property: String) -> T

    /**
     Returns the average value of a given property over all the objects in the collection, or `nil` if
     the collection is empty.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    func average<T: AddableType>(ofProperty property: String) -> T?


    // MARK: Key-Value Coding

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` with `key` on each of the collection's
     objects.

     - parameter key: The name of the property whose values are desired.
     */
    func value(forKey key: String) -> Any?

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` with `keyPath` on each of the
     collection's objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    func value(forKeyPath keyPath: String) -> Any?

    /**
     Invokes `setValue(_:forKey:)` on each of the collection's objects using the specified `value` and `key`.

     - warning: This method may only be called during a write transaction.

     - parameter value: The object value.
     - parameter key:   The name of the property whose value should be set on each object.
     */
    func setValue(_ value: Any?, forKey key: String)

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
    func observe(keyPaths: [String]?,
                 on queue: DispatchQueue?,
                 _ block: @escaping (RealmCollectionChange<Self>) -> Void) -> NotificationToken

    /// :nodoc:
    // swiftlint:disable:next identifier_name
    func _observe(_ keyPaths: [String]?, _ queue: DispatchQueue?, _ block: @escaping (RealmCollectionChange<AnyRealmCollection<Element>>) -> Void) -> NotificationToken

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

public extension RealmCollection {
    /**
     Returns the index of the first object matching the given predicate, or `nil` if no objects match.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    func index(matching predicateFormat: String, _ args: Any...) -> Int? {
        return index(matching: NSPredicate(format: predicateFormat, argumentArray: unwrapOptionals(in: args)))
    }

    /**
     Returns a `Results` containing all objects matching the given predicate in the collection.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    func filter(_ predicateFormat: String, _ args: Any...) -> Results<Element> {
        return filter(NSPredicate(format: predicateFormat, argumentArray: unwrapOptionals(in: args)))
    }
}


/// :nodoc:
public protocol OptionalProtocol {
    associatedtype Wrapped
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    func _rlmInferWrappedType() -> Wrapped
}

extension Optional: OptionalProtocol {
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _rlmInferWrappedType() -> Wrapped { return self! }
}


public extension RealmCollection where Element: MinMaxType {
    /**
     Returns the minimum (lowest) value of the collection, or `nil` if the collection is empty.
     */
    func min() -> Element? {
        return min(ofProperty: "self")
    }
    /**
     Returns the maximum (highest) value of the collection, or `nil` if the collection is empty.
     */
    func max() -> Element? {
        return max(ofProperty: "self")
    }
}

public extension RealmCollection where Element: OptionalProtocol, Element.Wrapped: MinMaxType {
    /**
     Returns the minimum (lowest) value of the collection, or `nil` if the collection is empty.
     */
    func min() -> Element.Wrapped? {
        return min(ofProperty: "self")
    }
    /**
     Returns the maximum (highest) value of the collection, or `nil` if the collection is empty.
     */
    func max() -> Element.Wrapped? {
        return max(ofProperty: "self")
    }
}

public extension RealmCollection where Element: AddableType {
    /**
     Returns the sum of the values in the collection, or `nil` if the collection is empty.
     */
    func sum() -> Element {
        return sum(ofProperty: "self")
    }
    /**
     Returns the average of all of the values in the collection.
     */
    func average<T: AddableType>() -> T? {
        return average(ofProperty: "self")
    }
}

public extension RealmCollection where Element: OptionalProtocol, Element.Wrapped: AddableType {
    /**
     Returns the sum of the values in the collection, or `nil` if the collection is empty.
     */
    func sum() -> Element.Wrapped {
        return sum(ofProperty: "self")
    }
    /**
     Returns the average of all of the values in the collection.
     */
    func average<T: AddableType>() -> T? {
        return average(ofProperty: "self")
    }
}

public extension RealmCollection where Element: Comparable {
    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on their values. For example, to sort a collection of `Date`s from
     neweset to oldest based, you might call `dates.sorted(ascending: true)`.

     - parameter ascending: The direction to sort in.
     */
    func sorted(ascending: Bool = true) -> Results<Element> {
        return sorted(byKeyPath: "self", ascending: ascending)
    }
}

public extension RealmCollection where Element: OptionalProtocol, Element.Wrapped: Comparable {
    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on their values. For example, to sort a collection of `Date`s from
     neweset to oldest based, you might call `dates.sorted(ascending: true)`.

     - parameter ascending: The direction to sort in.
     */
    func sorted(ascending: Bool = true) -> Results<Element> {
        return sorted(byKeyPath: "self", ascending: ascending)
    }
}

private class _AnyRealmCollectionBase<T: RealmCollectionValue>: AssistedObjectiveCBridgeable {
    typealias Wrapper = AnyRealmCollection<Element>
    typealias Element = T
    var realm: Realm? { fatalError() }
    var isInvalidated: Bool { fatalError() }
    var count: Int { fatalError() }
    var description: String { fatalError() }
    func index(of object: Element) -> Int? { fatalError() }
    func index(matching predicate: NSPredicate) -> Int? { fatalError() }
    func filter(_ predicate: NSPredicate) -> Results<Element> { fatalError() }
    func sorted(byKeyPath keyPath: String, ascending: Bool) -> Results<Element> { fatalError() }
    func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element> where S.Iterator.Element == SortDescriptor {
        fatalError()
    }
    func min<T: MinMaxType>(ofProperty property: String) -> T? { fatalError() }
    func max<T: MinMaxType>(ofProperty property: String) -> T? { fatalError() }
    func sum<T: AddableType>(ofProperty property: String) -> T { fatalError() }
    func average<T: AddableType>(ofProperty property: String) -> T? { fatalError() }
    subscript(position: Int) -> Element { fatalError() }
    func makeIterator() -> RLMIterator<T> { fatalError() }
    var startIndex: Int { fatalError() }
    var endIndex: Int { fatalError() }
    func value(forKey key: String) -> Any? { fatalError() }
    func value(forKeyPath keyPath: String) -> Any? { fatalError() }
    func setValue(_ value: Any?, forKey key: String) { fatalError() }
    // swiftlint:disable:next identifier_name
    func _observe(_ keyPaths: [String]?, _ queue: DispatchQueue?, _ block: @escaping (RealmCollectionChange<Wrapper>) -> Void)
        -> NotificationToken { fatalError() }
    class func bridging(from objectiveCValue: Any, with metadata: Any?) -> Self { fatalError() }
    var bridged: (objectiveCValue: Any, metadata: Any?) { fatalError() }
    func asNSFastEnumerator() -> Any { fatalError() }
    var isFrozen: Bool { fatalError() }
    func freeze() -> AnyRealmCollection<T> { fatalError() }
    func thaw() -> AnyRealmCollection<T> { fatalError() }
}

private final class _AnyRealmCollection<C: RealmCollection>: _AnyRealmCollectionBase<C.Element> {
    let base: C
    init(base: C) {
        self.base = base
    }

    // MARK: Properties

    override var realm: Realm? { return base.realm }
    override var isInvalidated: Bool { return base.isInvalidated }
    override var count: Int { return base.count }
    override var description: String { return base.description }


    // MARK: Index Retrieval

    override func index(of object: C.Element) -> Int? { return base.index(of: object) }

    override func index(matching predicate: NSPredicate) -> Int? { return base.index(matching: predicate) }

    // MARK: Filtering

    override func filter(_ predicate: NSPredicate) -> Results<C.Element> { return base.filter(predicate) }

    // MARK: Sorting

    override func sorted(byKeyPath keyPath: String, ascending: Bool) -> Results<C.Element> {
        return base.sorted(byKeyPath: keyPath, ascending: ascending)
    }

    override func sorted<S: Sequence>
        (by sortDescriptors: S) -> Results<C.Element> where S.Iterator.Element == SortDescriptor {
        return base.sorted(by: sortDescriptors)
    }


    // MARK: Aggregate Operations

    override func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return base.min(ofProperty: property)
    }

    override func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return base.max(ofProperty: property)
    }

    override func sum<T: AddableType>(ofProperty property: String) -> T {
        return base.sum(ofProperty: property)
    }

    override func average<T: AddableType>(ofProperty property: String) -> T? {
        return base.average(ofProperty: property)
    }


    // MARK: Sequence Support

    override subscript(position: Int) -> C.Element {
        return base[position as! C.Index]
    }

    override func makeIterator() -> RLMIterator<Element> {
        // FIXME: it should be possible to avoid this force-casting
        return base.makeIterator() as! RLMIterator<Element>
    }

    override func asNSFastEnumerator() -> Any {
        return (base as! UntypedCollection).asNSFastEnumerator()
    }

    // MARK: Collection Support

    override var startIndex: Int {
        // FIXME: it should be possible to avoid this force-casting
        return base.startIndex as! Int
    }

    override var endIndex: Int {
        // FIXME: it should be possible to avoid this force-casting
        return base.endIndex as! Int
    }


    // MARK: Key-Value Coding

    override func value(forKey key: String) -> Any? { return base.value(forKey: key) }

    override func value(forKeyPath keyPath: String) -> Any? { return base.value(forKeyPath: keyPath) }

    override func setValue(_ value: Any?, forKey key: String) { base.setValue(value, forKey: key) }

    // MARK: Notifications

    /// :nodoc:
    override func _observe(_ keyPaths: [String]?, _ queue: DispatchQueue?, _ block: @escaping (RealmCollectionChange<Wrapper>) -> Void)
        -> NotificationToken { return base._observe(keyPaths, queue, block) }

    // MARK: AssistedObjectiveCBridgeable

    override class func bridging(from objectiveCValue: Any, with metadata: Any?) -> _AnyRealmCollection {
        return _AnyRealmCollection(
            base: (C.self as! AssistedObjectiveCBridgeable.Type).bridging(from: objectiveCValue, with: metadata) as! C)
    }

    override var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (base as! AssistedObjectiveCBridgeable).bridged
    }

    override var isFrozen: Bool {
        return base.isFrozen
    }

    override func freeze() -> AnyRealmCollection<Element> {
        return AnyRealmCollection(base.freeze())
    }

    override func thaw() -> AnyRealmCollection<Element> {
        return AnyRealmCollection(base.thaw()!)
    }
}

/**
 A type-erased `RealmCollection`.

 Instances of `RealmCollection` forward operations to an opaque underlying collection having the same `Element` type.
 */
public struct AnyRealmCollection<Element: RealmCollectionValue>: RealmCollection, UntypedCollection {

    /// The type of the objects contained within the collection.
    public typealias ElementType = Element

    public func index(after i: Int) -> Int { return i + 1 }
    public func index(before i: Int) -> Int { return i - 1 }

    /// The type of the objects contained in the collection.
    fileprivate let base: _AnyRealmCollectionBase<Element>

    fileprivate init(base: _AnyRealmCollectionBase<Element>) {
        self.base = base
    }

    /// Creates an `AnyRealmCollection` wrapping `base`.
    public init<C: RealmCollection>(_ base: C) where C.Element == Element {
        self.base = _AnyRealmCollection(base: base)
    }

    // MARK: Properties

    /// The Realm which manages the collection, or `nil` if the collection is unmanaged.
    public var realm: Realm? { return base.realm }

    /**
     Indicates if the collection can no longer be accessed.

     The collection can no longer be accessed if `invalidate()` is called on the containing `realm`.
     */
    public var isInvalidated: Bool { return base.isInvalidated }

    /// The number of objects in the collection.
    public var count: Int { return base.count }

    /// A human-readable description of the objects contained in the collection.
    public var description: String { return base.description }


    // MARK: Index Retrieval

    /**
     Returns the index of the given object, or `nil` if the object is not in the collection.

     - parameter object: An object.
     */
    public func index(of object: Element) -> Int? { return base.index(of: object) }

    /**
     Returns the index of the first object matching the given predicate, or `nil` if no objects match.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func index(matching predicate: NSPredicate) -> Int? { return base.index(matching: predicate) }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the collection.

     - parameter predicate: The predicate with which to filter the objects.

     - returns: A `Results` containing objects that match the given predicate.
     */
    public func filter(_ predicate: NSPredicate) -> Results<Element> { return base.filter(predicate) }


    // MARK: Sorting

    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a collection of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning:  Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                 floating point, integer, and string types.

     - parameter keyPath:  The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(byKeyPath keyPath: String, ascending: Bool) -> Results<Element> {
        return base.sorted(byKeyPath: keyPath, ascending: ascending)
    }

    /**
     Returns a `Results` containing the objects in the collection, but sorted.

     - warning:  Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                 floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`

     - parameter sortDescriptors: A sequence of `SortDescriptor`s to sort by.
     */
    public func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element>
        where S.Iterator.Element == SortDescriptor {
        return base.sorted(by: sortDescriptors)
    }


    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return base.min(ofProperty: property)
    }

    /**
     Returns the maximum (highest) value of the given property among all the objects in the collection, or `nil` if the
     collection is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return base.max(ofProperty: property)
    }

    /**
     Returns the sum of the values of a given property over all the objects in the collection.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<T: AddableType>(ofProperty property: String) -> T { return base.sum(ofProperty: property) }

    /**
     Returns the average value of a given property over all the objects in the collection, or `nil` if the collection is
     empty.

     - warning: Only the name of a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose average value should be calculated.
     */
    public func average<T: AddableType>(ofProperty property: String) -> T? { return base.average(ofProperty: property) }


    // MARK: Sequence Support

    /**
     Returns the object at the given `index`.

     - parameter index: The index.
     */
    public subscript(position: Int) -> Element { return base[position] }

    /// Returns a `RLMIterator` that yields successive elements in the collection.
    public func makeIterator() -> RLMIterator<Element> { return base.makeIterator() }

    internal func asNSFastEnumerator() -> Any { return base.asNSFastEnumerator() }

    // MARK: Collection Support

    /// The position of the first element in a non-empty collection.
    /// Identical to endIndex in an empty collection.
    public var startIndex: Int { return base.startIndex }

    /// The collection's "past the end" position.
    /// endIndex is not a valid argument to subscript, and is always reachable from startIndex by
    /// zero or more applications of successor().
    public var endIndex: Int { return base.endIndex }


    // MARK: Key-Value Coding

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` with `key` on each of the collection's
     objects.

     - parameter key: The name of the property whose values are desired.
     */
    public func value(forKey key: String) -> Any? { return base.value(forKey: key) }

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` with `keyPath` on each of the
     collection's objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    public func value(forKeyPath keyPath: String) -> Any? { return base.value(forKeyPath: keyPath) }

    /**
     Invokes `setValue(_:forKey:)` on each of the collection's objects using the specified `value` and `key`.

     - warning: This method may only be called during a write transaction.

     - parameter value: The value to set the property to.
     - parameter key:   The name of the property whose value should be set on each object.
     */
    public func setValue(_ value: Any?, forKey key: String) { base.setValue(value, forKey: key) }

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

     Notifications are delivered via the standard run loop, and so can't be delivered while the run loop is blocked by
     other activity. When notifications can't be delivered instantly, multiple notifications may be coalesced into a
     single notification. This can include the notification with the initial collection.

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

     If no key paths are given, the block will be executed on any insertion,
     modification, or deletion for all collection type properties and nested linked
     properties. If a key path or key paths are provided,
     then the block will be called for changes which occur on those key paths,
     or links to those key paths. For example, if:
     ```swift
     class Dog: Object {
         @objc dynamic var name: String = ""
         @objc dynamic var adopted: Bool = false
         let toys = List<Toy>()
     }
     // ...
     let dogs = realm.objects(Dog.self)

     let token = dogs.observe(keyPaths: ["name"]) { changes in
         switch changes {
         case .initial(let dogs):
            // ...
             break
         case .update:
            // This case is hit:
            // - only after the token is intialized
            // - when an element of the collections' name
            // property is modified
            // - when an element is inserted or deleted.
            // This block is not triggered:
            // - when any of the elements "age" values is modified
             break
         case .error:
             break
         }
     }
     ```
     - If the above example observed the `["toys"]` key path, then any insertion,
     deletion, or modification to the `toys` list for any element in the collection would trigger the block.
     Any insertion or deletion to the `Dog` type collection being observed would also trigger a notification.
     - If the observed key path were `["toys.size"]`, then any insertion or
     deletion to the `toys` list on any of the collection elements would trigger the block. Changes to the `size` value
     on any `Toy` that is linked to a `Dog` in this collection will trigger the block. Changes to the `toyBrand` value
     on any `Toy` that is linked to a `Dog` in this collection would not trigger the block.
     Any insertion or deletion to the `Dog` type collection being observed would also trigger a notification.

     - note: Multiple notification tokens on the same object which filter for
     separate key paths *do not* filter exclusively. If one key path
     change is satisified for one notification token, then all notification
     token blocks for that object will execute.

     If no queue is given, notifications are delivered via the standard run
     loop, and so can't be delivered while the run loop is blocked by other
     activity. If a queue is given, notifications are delivered to that queue
     instead. When notifications can't be delivered instantly, multiple
     notifications may be coalesced into a single notification.

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `invalidate()` on the token.
     - warning: This method cannot be called during a write transaction, or when the containing Realm is read-only.
     - parameter keyPaths: The element type properties which trigger the block to
     be called when they are modified. If `nil`, notifications will be delivered for
     any property change on the collection elements. See comments above for more detail on linked properties.
     - parameter queue: The serial dispatch queue to receive notification on. If
     `nil`, notifications are delivered to the current thread.
     - parameter block: The block to be called whenever a change occurs.
     - returns: A token which must be held for as long as you want updates to be delivered.
     */
    public func observe(keyPaths: [String]? = nil, on queue: DispatchQueue? = nil,
                        _ block: @escaping (RealmCollectionChange<AnyRealmCollection>) -> Void)
        -> NotificationToken { return base._observe(keyPaths, queue, block) }

    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe(_ keyPaths: [String]?, _ queue: DispatchQueue?, _ block: @escaping (RealmCollectionChange<AnyRealmCollection>) -> Void)
        -> NotificationToken { return base._observe(keyPaths, queue, block) }

    // MARK: Frozen Objects

    /// Returns if this collection is frozen.
    public var isFrozen: Bool { return base.isFrozen }

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
    public func freeze() -> AnyRealmCollection { return base.freeze() }

    /**
     Returns a live version of this frozen collection.

     This method resolves a reference to a live copy of the same frozen collection.
     If called on a live collection, will return itself.
    */
    public func thaw() -> AnyRealmCollection? { return base.thaw() }
}

// MARK: AssistedObjectiveCBridgeable

private struct AnyRealmCollectionBridgingMetadata<T: RealmCollectionValue> {
    var baseMetadata: Any?
    var baseType: _AnyRealmCollectionBase<T>.Type
}

extension AnyRealmCollection: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> AnyRealmCollection {
        guard let metadata = metadata as? AnyRealmCollectionBridgingMetadata<Element> else { preconditionFailure() }
        return AnyRealmCollection(base: metadata.baseType.bridging(from: objectiveCValue, with: metadata.baseMetadata))
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (
            objectiveCValue: base.bridged.objectiveCValue,
            metadata: AnyRealmCollectionBridgingMetadata(baseMetadata: base.bridged.metadata, baseType: type(of: base))
        )
    }
}

// MARK: Collection observation helpers

internal protocol ObservableCollection {
    associatedtype BackingObjcCollection
    func isSameObjcCollection(_ objc: BackingObjcCollection) -> Bool
    init(objc: BackingObjcCollection)
}

extension ObservableCollection where Self: RealmCollection {
    // We want to pass the same object instance to the change callback each time.
    // If the callback is being called on the source thread the instance should
    // be `self`, but if it's on a different thread it needs to be a new Swift
    // wrapper for the obj-c type, which we'll construct the first time the
    // callback is called.
    internal typealias ObjcCollectionChange = (BackingObjcCollection?, RLMCollectionChange?, Error?) -> Void
    internal func wrapObserveBlock(_ block: @escaping (RealmCollectionChange<AnyRealmCollection<Element>>) -> Void) -> ObjcCollectionChange {
        var anyCollection: AnyRealmCollection<Element>?
        return { collection, change, error in
            if anyCollection == nil, let collection = collection {
                anyCollection = AnyRealmCollection(self.isSameObjcCollection(collection) ? self : Self(objc: collection))
            }
            block(RealmCollectionChange.fromObjc(value: anyCollection, change: change, error: error))
        }
    }

    internal func wrapObserveBlock(_ block: @escaping (RealmCollectionChange<Self>) -> Void) -> ObjcCollectionChange {
        var col: Self?
        return { collection, change, error in
            if col == nil, let collection = collection {
                col = self.isSameObjcCollection(collection) ? self : Self(objc: collection)
            }
            block(RealmCollectionChange.fromObjc(value: col, change: change, error: error))
        }
    }
}

extension ObservableCollection where Self: RealmKeyedCollection {
    // We want to pass the same object instance to the change callback each time.
    // If the callback is being called on the source thread the instance should
    // be `self`, but if it's on a different thread it needs to be a new Swift
    // wrapper for the obj-c type, which we'll construct the first time the
    // callback is called.
    internal typealias ObjcChange = (RLMDictionary<AnyObject, AnyObject>?, RLMDictionaryChange?, Error?) -> Void

    internal func wrapDictionaryObserveBlock(_ block: @escaping (RealmMapChange<Self>) -> Void) -> ObjcChange {
        var col: Self?
        return { collection, change, error in
            if col == nil, let collection = collection as? Self.BackingObjcCollection {
                col = self.isSameObjcCollection(collection) ? self : Self(objc: collection)
            }
            block(RealmMapChange.fromObjc(value: col, change: change, error: error))
        }
    }
}

extension List: ObservableCollection {
    internal typealias BackingObjcCollection = RLMArray<AnyObject>
    internal func isSameObjcCollection(_ rlmArray: BackingObjcCollection) -> Bool {
        return _rlmCollection === rlmArray
    }
}

extension MutableSet: ObservableCollection {
    internal typealias BackingObjcCollection = RLMSet<AnyObject>
    internal func isSameObjcCollection(_ rlmSet: BackingObjcCollection) -> Bool {
        return _rlmCollection === rlmSet
    }
}

extension Map: ObservableCollection {
    internal typealias BackingObjcCollection = RLMDictionary<AnyObject, AnyObject>
    internal func isSameObjcCollection(_ rlmDictionary: BackingObjcCollection) -> Bool {
        return _rlmCollection === rlmDictionary
    }
}

extension Results: ObservableCollection {
    internal typealias BackingObjcCollection = RLMResults<AnyObject>
    internal func isSameObjcCollection(_ objc: RLMResults<AnyObject>) -> Bool {
        return objc === rlmResults
    }
}

extension LinkingObjects: ObservableCollection {
    internal typealias BackingObjcCollection = RLMResults<AnyObject>
    internal func isSameObjcCollection(_ objc: RLMResults<AnyObject>) -> Bool {
        return objc === rlmResults
    }
}

// MARK: Key Path Strings

/// Tag protocol which allows a collection to produce its property name
internal protocol PropertyNameConvertible {
    /// A mutable array referenced from the enclosing parent that contains the last accessed property names.
    var lastAccessedNames: NSMutableArray? { get set }
    /// `key` is the property name for this collection.
    /// `isLegacy` will be true if the property is declared with old property syntax.
    var propertyInformation: (key: String, isLegacy: Bool)? { get }
}
