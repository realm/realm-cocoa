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

/// :nodoc:
/// Internal class. Do not use directly. Used for reflection and initialization
public class LinkingObjectsBase: NSObject, NSFastEnumeration {
    internal let objectClassName: String
    internal let propertyName: String

    private var cachedRLMResults: RLMResults<RLMObject>?
    private var object: RLMWeakObjectHandle?
    private var property: RLMProperty?

    internal func attachTo(object: RLMObjectBase, property: RLMProperty) {
        self.object = RLMWeakObjectHandle(object: object)
        self.property = property
        self.cachedRLMResults = nil
    }

    internal var rlmResults: RLMResults<RLMObject> {
        if cachedRLMResults == nil {
            if let object = self.object, property = self.property {
                cachedRLMResults = RLMDynamicGet(object.object, property)! as? RLMResults
                self.object = nil
                self.property = nil
            } else {
                cachedRLMResults = RLMResults.emptyDetached()
            }
        }
        return cachedRLMResults!
    }

    init(fromClassName objectClassName: String, property propertyName: String) {
        self.objectClassName = objectClassName
        self.propertyName = propertyName
    }

    // MARK: Fast Enumeration
    public func countByEnumerating(with state: UnsafeMutablePointer<NSFastEnumerationState>,
                                   objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
                                   count len: Int) -> Int {
        return Int(rlmResults.countByEnumerating(with: state,
                                                 objects: buffer,
                                                 count: UInt(len)))
    }
}

/**
 `LinkingObjects` is an auto-updating container type. It represents zero or more objects that are linked to its owning
 model object through a property relationship.

 For example, a `Dog` model may have an `owner` property of type `Person`. A `Person` can then define and configure a
 linking objects property, `let dogs : LinkingObjects<Dog>`, which automatically contains all the dogs owned by that
 person.

 A `LinkingObjects` instance is a Realm collection, and supports all the collection operations. For example, it can be
 queried with the same predicates as `List<T>` and `Results<T>`.

 `LinkingObjects` always reflects the current state of the Realm on the current thread, including during write
 transactions on the current thread. The one exception to this is when using `for...in` enumeration, which will always
 enumerate over the linking objects that were present when the enumeration is begun, even if some of them are deleted or
 modified to no longer link to the target object during the enumeration.

 `LinkingObjects` can only be used as a property on `Object` models. Properties of this type must be declared as `let`
 and cannot be `dynamic`.
 */
public final class LinkingObjects<T: Object>: LinkingObjectsBase {
    /// The element type contained in this collection.
    public typealias Element = T

    // MARK: Properties

    /// The Realm which manages these linking objects, or `nil` if the linking objects are unmanaged.
    public var realm: Realm? { return rlmResults.isAttached ? Realm(rlmResults.realm) : nil }

    /// Indicates if the linking objects collection is no longer valid.
    ///
    /// The linking objects collection becomes invalid if `invalidate()` is called on the containing `realm`.
    ///
    /// An invalidated linking objects can be accessed, but will always be empty.
    public var isInvalidated: Bool { return rlmResults.isInvalidated }

    /// The number of linking objects.
    public var count: Int { return Int(rlmResults.count) }

    // MARK: Initializers

    /**
     Creates an instance of a `LinkingObjects`. This initializer should only be called when declaring a property on a
     Realm model.

     - parameter type:         The type of the object owning the property this `LinkingObjects` should refer to.
     - parameter propertyName: The property name of the property this `LinkingObjects` should refer to.
     */
    public init(fromType type: T.Type, property propertyName: String) {
        let className = (T.self as Object.Type).className()
        super.init(fromClassName: className, property: propertyName)
    }

    /// Returns a description of the linking objects.
    public override var description: String {
        let type = "LinkingObjects<\(rlmResults.objectClassName)>"
        return gsub(pattern: "RLMResults <0x[a-z0-9]+>", template: type, string: rlmResults.description) ?? type
    }

    // MARK: Index Retrieval

    /**
     Returns the index of an object in the linking objects, or `nil` if the object is not present.

     - parameter object: The object whose index is being queried.
     */
    public func index(of object: T) -> Int? {
        return notFoundToNil(index: rlmResults.index(of: unsafeBitCast(object, to: RLMObject.self)))
    }

    /**
     Returns the index of the first object matching the given predicate, or `nil` if no objects match.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func indexOfObject(for predicate: Predicate) -> Int? {
        return notFoundToNil(index: rlmResults.indexOfObject(with: predicate))
    }

    /**
     Returns the index of the first object matching the given predicate, or `nil` if no objects match.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    public func indexOfObject(for predicateFormat: String, _ args: AnyObject...) -> Int? {
        return notFoundToNil(index: rlmResults.indexOfObject(with: Predicate(format: predicateFormat,
                                                                             argumentArray: args)))
    }

    // MARK: Object Retrieval

    /**
     Returns the object at the given index.

     - parameter index: The index.
     */
    public subscript(index: Int) -> T {
        get {
            throwForNegativeIndex(index)
            return unsafeBitCast(rlmResults[UInt(index)], to: T.self)
        }
    }

    /// Returns the first object in the linking objects, or `nil` if the linking objects are empty.
    public var first: T? { return unsafeBitCast(rlmResults.firstObject(), to: Optional<T>.self) }

    /// Returns the last object in the linking objects, or `nil` if the linking objects are empty.
    public var last: T? { return unsafeBitCast(rlmResults.lastObject(), to: Optional<T>.self) }

    // MARK: KVC

    /**
     Returns an `Array` containing the results of invoking `value(forKey:)` with `key` on each of the linking objects.

     - parameter key: The name of the property whose values are desired.
     */
    public override func value(forKey key: String) -> AnyObject? {
        return value(forKeyPath: key)
    }

    /**
     Returns an `Array` containing the results of invoking `value(forKeyPath:)` with `keyPath` on each of the linking
     objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    public override func value(forKeyPath keyPath: String) -> AnyObject? {
        return rlmResults.value(forKeyPath: keyPath)
    }

    /**
     Invokes `setValue(_:forKey:)` on each of the linking objects using the specified `value` and `key`.

     - warning: This method may only be called during a write transaction.

     - parameter value: The value to set the property to.
     - parameter key:   The name of the property whose value should be set on each object.
     */
    public override func setValue(_ value: AnyObject?, forKey key: String) {
        return rlmResults.setValue(value, forKeyPath: key)
    }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the linking objects.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
     */
    public func filter(using predicateFormat: String, _ args: AnyObject...) -> Results<T> {
        return Results<T>(rlmResults.objects(with: Predicate(format: predicateFormat, argumentArray: args)))
    }

    /**
     Returns a `Results` containing all objects matching the given predicate in the linking objects.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func filter(using predicate: Predicate) -> Results<T> {
        return Results<T>(rlmResults.objects(with: predicate))
    }

    // MARK: Sorting

    /**
     Returns a `Results` containing all the linking objects, but sorted.

     Objects are sorted based on the values of the given property. For example, to sort a collection of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(onProperty: "age", ascending: true)`.

     - warning: Collections may only be sorted by properties of boolean, `NSDate`, single and double-precision floating
                point, integer, and string types.

     - parameter property:  The name of the property to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(onProperty property: String, ascending: Bool = true) -> Results<T> {
        return sorted(with: [SortDescriptor(property: property, ascending: ascending)])
    }

    /**
     Returns a `Results` containing all the linking objects, but sorted.

     - warning: Collections may only be sorted by properties of boolean, `NSDate`, single and double-precision floating
                point, integer, and string types.

     - see: `sorted(onProperty:ascending:)`

     - parameter sortDescriptors: A sequence of `SortDescriptor`s to sort by.
     */
    public func sorted<S: Sequence where S.Iterator.Element == SortDescriptor>(with sortDescriptors: S) -> Results<T> {
        return Results<T>(rlmResults.sortedResults(using: sortDescriptors.map { $0.rlmSortDescriptorValue }))
    }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the linking objects, or `nil` if the linking
     objects are empty.

     - warning: Only a property whose type conforms to the `RealmMinMaxable` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func minimumValue<U: RealmMinMaxable>(ofProperty property: String) -> U? {
        return rlmResults.min(ofProperty: property) as! U?
    }

    /**
     Returns the maximum (highest) value of the given property among all the linking objects, or `nil` if the linking
     objects are empty.

     - warning: Only a property whose type conforms to the `RealmMinMaxable` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func maximumValue<U: RealmMinMaxable>(ofProperty property: String) -> U? {
        return rlmResults.max(ofProperty: property) as! U?
    }

    /**
     Returns the sum of the values of a given property over all the linking objects.

     - warning: Only a property whose type conforms to the `RealmAddable` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<U: RealmAddable>(ofProperty property: String) -> U {
        return rlmResults.sum(ofProperty: property) as AnyObject as! U
    }

    /**
     Returns the average value of a given property over all the linking objects, or `nil` if the linking objects are
     empty.

     - warning: Only the name of a property whose type conforms to the `RealmAddable` protocol can be specified.

     - parameter property: The name of a property whose average value should be calculated.
     */
    public func average<U: RealmAddable>(ofProperty property: String) -> U? {
        return rlmResults.average(ofProperty: property) as! U?
    }

    // MARK: Notifications

    /**
     Registers a block to be called each time the linking objects change.

     The block will be asynchronously called with the initial linking objects, and then called again after each write
     transaction which changes either any of the objects in the collection, or which objects are in the collection.

     The `change` parameter that is passed to the block reports, in the form of indices within the collection, which of
     the objects were added, removed, or modified during each write transaction. See the `RealmCollectionChange`
     documentation for more information on the change information supplied and an example of how to use it to update a
     `UITableView`.

     At the time when the block is called, the linking objects will be fully evaluated and up-to-date, and as long as
     you do not perform a write transaction on the same thread or explicitly call `refresh()` on the Realm, accessing
     the linking objects will never perform blocking work.

     Notifications are delivered via the standard run loop, and so can't be delivered while the run loop is blocked by
     other activity. When notifications can't be delivered instantly, multiple notifications may be coalesced into a
     single notification. This can include the notification with the initial set of objects. For example, the following
     code performs a write transaction immediately after adding the notification block, so there is no opportunity for
     the initial notification to be delivered first. As a result, the initial notification will reflect the state of the
     Realm after the write transaction.

     ```swift
     let dog = realm.objects(Dog.self).first!
     let owners = dog.owners
     print("owners.count: \(owners.count)") // => 0
     let token = owners.addNotificationBlock { changes in
         switch changes {
             case .initial(let owners):
                 // Will print "owners.count: 1"
                 print("owners.count: \(owners.count)")
                 break
             case .update:
                 // Will not be hit in this example
                 break
             case .error:
                 break
         }
     }
     try! realm.write {
         realm.add(Person.self, value: ["name": "Mark", dogs: [dog]])
     }
     // end of runloop execution context
     ```

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `stop()` on the token.

     - warning: This method cannot be called during a write transaction, or when the containing Realm is read-only.

     - parameter block: The block to be called whenever a change occurs.
     - returns: A token which must be retained for as long as you want updates to be delivered.
     */
    @warn_unused_result(message:"You must hold on to the NotificationToken returned from addNotificationBlock")
    public func addNotificationBlock(block: ((RealmCollectionChange<LinkingObjects>) -> Void)) -> NotificationToken {
        return rlmResults.addNotificationBlock { results, change, error in
            block(RealmCollectionChange.fromObjc(value: self, change: change, error: error))
        }
    }
}

extension LinkingObjects : RealmCollection {
    // MARK: Sequence Support

    public func makeIterator() -> RLMIterator<T> {
        return RLMIterator(collection: rlmResults)
    }

    // MARK: Collection Support

    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }
    public func index(after: Int) -> Int { return after + 1 }
    public func index(before: Int) -> Int { return before - 1 }

    /// :nodoc:
    public func _addNotificationBlock(block: (RealmCollectionChange<AnyRealmCollection<T>>) -> Void) ->
        NotificationToken {
            let anyCollection = AnyRealmCollection(self)
            return rlmResults.addNotificationBlock { _, change, error in
                block(RealmCollectionChange.fromObjc(value: anyCollection, change: change, error: error))
            }
    }
}

// MARK: Unavailable

extension LinkingObjects {
    @available(*, unavailable, renamed:"isInvalidated")
    public var invalidated : Bool { fatalError() }

    @available(*, unavailable, renamed:"indexOfObject(for:)")
    public func index(of predicate: Predicate) -> Int? { fatalError() }

    @available(*, unavailable, renamed:"indexOfObject(for:_:)")
    public func index(of predicateFormat: String, _ args: AnyObject...) -> Int? { fatalError() }

    @available(*, unavailable, renamed:"filter(using:)")
    public func filter(_ predicate: Predicate) -> Results<T> { fatalError() }

    @available(*, unavailable, renamed:"filter(using:_:)")
    public func filter(_ predicateFormat: String, _ args: AnyObject...) -> Results<T> { fatalError() }

    @available(*, unavailable, renamed:"sorted(onProperty:ascending:)")
    public func sorted(_ property: String, ascending: Bool = true) -> Results<T> { fatalError() }

    @available(*, unavailable, renamed:"sorted(with:)")
    public func sorted<S: Sequence where S.Iterator.Element == SortDescriptor>(_ sortDescriptors: S) -> Results<T> {
        fatalError()
    }

    @available(*, unavailable, renamed:"minimumValue(ofProperty:)")
    public func min<U: RealmMinMaxable>(_ property: String) -> U? { fatalError() }

    @available(*, unavailable, renamed:"maximumValue(ofProperty:)")
    public func max<U: RealmMinMaxable>(_ property: String) -> U? { fatalError() }

    @available(*, unavailable, renamed:"sum(ofProperty:)")
    public func sum<U: RealmAddable>(_ property: String) -> U { fatalError() }

    @available(*, unavailable, renamed:"average(ofProperty:)")
    public func average<U: RealmAddable>(_ property: String) -> U? { fatalError() }
}
