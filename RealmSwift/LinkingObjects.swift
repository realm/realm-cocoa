////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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
 `LinkingObjects` is an auto-updating container type. It represents zero or more objects that are linked to its owning
 model object through a property relationship.

 `LinkingObjects` can be queried with the same predicates as `List<Element>` and `Results<Element>`.

 `LinkingObjects` always reflects the current state of the Realm on the current thread, including during write
 transactions on the current thread. The one exception to this is when using `for...in` enumeration, which will always
 enumerate over the linking objects that were present when the enumeration is begun, even if some of them are deleted or
 modified to no longer link to the target object during the enumeration.

 `LinkingObjects` can only be used as a property on `Object` models. Properties of this type must be declared as `let`
 and cannot be `dynamic`.
 */
@frozen public struct LinkingObjects<Element: ObjectBase> where Element: RealmCollectionValue {
    /// The type of the objects represented by the linking objects.
    public typealias ElementType = Element

    // MARK: Properties

    /// The Realm which manages the linking objects, or `nil` if the linking objects are unmanaged.
    public var realm: Realm? { return rlmResults.isAttached ? Realm(rlmResults.realm) : nil }

    /// Indicates if the linking objects are no longer valid.
    ///
    /// The linking objects become invalid if `invalidate()` is called on the containing `realm` instance.
    ///
    /// An invalidated linking objects can be accessed, but will always be empty.
    public var isInvalidated: Bool { return rlmResults.isInvalidated }

    /// The number of linking objects.
    public var count: Int { return Int(rlmResults.count) }

    // MARK: Initializers

    /**
     Creates an instance of a `LinkingObjects`. This initializer should only be called when declaring a property on a
     Realm model.

     - parameter type:         The type of the object owning the property the linking objects should refer to.
     - parameter propertyName: The property name of the property the linking objects should refer to.
     */
    public init(fromType _: Element.Type, property propertyName: String) {
        self.propertyName = propertyName
    }

    /// A human-readable description of the objects represented by the linking objects.
    public var description: String {
        if realm == nil {
            var this = self
            return withUnsafePointer(to: &this) {
                return "LinkingObjects<\(Element.className())> <\($0)> (\n\n)"
            }
        }
        return RLMDescriptionWithMaxDepth("LinkingObjects", rlmResults, RLMDescriptionMaxDepth)
    }

    // MARK: Index Retrieval

    /**
     Returns the index of an object in the linking objects, or `nil` if the object is not present.

     - parameter object: The object whose index is being queried.
     */
    public func index(of object: Element) -> Int? {
        return notFoundToNil(index: rlmResults.index(of: object))
    }

    /**
     Returns the index of the first object matching the given predicate, or `nil` if no objects match.

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
    public subscript(index: Int) -> Element {
        if let lastAccessedNames = lastAccessedNames {
            return Element._rlmKeyPathRecorder(with: lastAccessedNames)
        }
        throwForNegativeIndex(index)
        return unsafeBitCast(rlmResults[UInt(index)], to: Element.self)
    }

    /// Returns the first object in the linking objects, or `nil` if the linking objects are empty.
    public var first: Element? { return unsafeBitCast(rlmResults.firstObject(), to: Optional<Element>.self) }

    /// Returns the last object in the linking objects, or `nil` if the linking objects are empty.
    public var last: Element? { return unsafeBitCast(rlmResults.lastObject(), to: Optional<Element>.self) }

    // MARK: KVC

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` with `key` on each of the linking objects.

     - parameter key: The name of the property whose values are desired.
     */
    public func value(forKey key: String) -> Any? {
        return value(forKeyPath: key)
    }

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` with `keyPath` on each of the linking
     objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    public func value(forKeyPath keyPath: String) -> Any? {
        return rlmResults.value(forKeyPath: keyPath)
    }

    /**
     Invokes `setValue(_:forKey:)` on each of the linking objects using the specified `value` and `key`.

     - warning: This method may only be called during a write transaction.

     - parameter value: The value to set the property to.
     - parameter key:   The name of the property whose value should be set on each object.
     */
    public func setValue(_ value: Any?, forKey key: String) {
        return rlmResults.setValue(value, forKeyPath: key)
    }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the linking objects.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func filter(_ predicate: NSPredicate) -> Results<Element> {
        return Results(rlmResults.objects(with: predicate))
    }

    // MARK: Sorting

    /**
     Returns a `Results` containing all the linking objects, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a collection of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:  The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(byKeyPath keyPath: String, ascending: Bool = true) -> Results<Element> {
        return sorted(by: [SortDescriptor(keyPath: keyPath, ascending: ascending)])
    }

    /**
     Returns a `Results` containing all the linking objects, but sorted.

     - warning: Collections may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`

     - parameter sortDescriptors: A sequence of `SortDescriptor`s to sort by.
     */
    public func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element>
        where S.Iterator.Element == SortDescriptor {
            return Results(rlmResults.sortedResults(using: sortDescriptors.map { $0.rlmSortDescriptorValue }))
    }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the linking objects, or `nil` if the linking
     objects are empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmResults.min(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value of the given property among all the linking objects, or `nil` if the linking
     objects are empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return rlmResults.max(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the sum of the values of a given property over all the linking objects.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<T: AddableType>(ofProperty property: String) -> T {
        return dynamicBridgeCast(fromObjectiveC: rlmResults.sum(ofProperty: property))
    }

    /**
     Returns the average value of a given property over all the linking objects, or `nil` if the linking objects are
     empty.

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
    public func observe(keyPaths: [String]? = nil,
                        on queue: DispatchQueue? = nil,
                        _ block: @escaping (RealmCollectionChange<LinkingObjects>) -> Void) -> NotificationToken {
        return rlmResults.addNotificationBlock(wrapObserveBlock(block), keyPaths: keyPaths, queue: queue)
    }

    // MARK: Frozen Objects

    /// Returns if this collection is frozen.
    public var isFrozen: Bool { return self.rlmResults.isFrozen }

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
    public func freeze() -> LinkingObjects {
        return LinkingObjects(propertyName: propertyName, handle: handle?.freeze())
    }

    /**
     Returns a live version of this frozen collection.

     This method resolves a reference to a live copy of the same frozen collection.
     If called on a live collection, will return itself.
    */
    public func thaw() -> LinkingObjects<Element>? {
        return LinkingObjects(propertyName: propertyName, handle: handle?.thaw())
    }

    // MARK: Implementation

    internal init(propertyName: String, handle: RLMLinkingObjectsHandle?) {
        self.propertyName = propertyName
        self.handle = handle
    }
    internal init(objc: RLMResults<AnyObject>) {
        self.propertyName = ""
        self.handle = RLMLinkingObjectsHandle(linkingObjects: objc)
    }

    internal var rlmResults: RLMResults<AnyObject> {
        return handle?.results ?? RLMResults<AnyObject>.emptyDetached()
    }

    internal var propertyName: String
    internal var handle: RLMLinkingObjectsHandle?
    internal var lastAccessedNames: NSMutableArray?
}

extension LinkingObjects: RealmCollection {
    // MARK: Sequence Support

    /// Returns an iterator that yields successive elements in the linking objects.
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

    public func index(after: Int) -> Int {
      return after + 1
    }

    public func index(before: Int) -> Int {
      return before - 1
    }

    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe(_ keyPaths: [String]?,
                         _ queue: DispatchQueue?,
                         _ block: @escaping (RealmCollectionChange<AnyRealmCollection<Element>>) -> Void)
        -> NotificationToken {
        return rlmResults.addNotificationBlock(wrapObserveBlock(block), keyPaths: keyPaths, queue: queue)
    }
}

// MARK: AssistedObjectiveCBridgeable

extension LinkingObjects: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> LinkingObjects {
        guard let object = objectiveCValue as? RLMResults<Element> else { preconditionFailure() }
        return LinkingObjects<Element>(objc: object as! RLMResults<AnyObject>)
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: handle!.results, metadata: nil)
    }
}

// MARK: Key Path Strings

extension LinkingObjects: PropertyNameConvertible {
    var propertyInformation: (key: String, isLegacy: Bool)? {
        guard let handle = handle else {
            return nil
        }
        return (key: handle._propertyKey, isLegacy: handle._isLegacyProperty)
    }
}
