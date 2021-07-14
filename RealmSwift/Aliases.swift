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

// These types don't change when wrapping in Swift
// so we just typealias them to remove the 'RLM' prefix

// MARK: Aliases

/**
 `PropertyType` is an enum describing all property types supported in Realm models.

 For more information, see [Realm Models](https://realm.io/docs/swift/latest/#models).

 ### Primitive types

 * `Int`
 * `Bool`
 * `Float`
 * `Double`

 ### Object types

 * `String`
 * `Data`
 * `Date`
 * `Decimal128`
 * `ObjectId`

 ### Relationships: Array (in Swift, `List`) and `Object` types

 * `Object`
 * `Array`
*/
public typealias PropertyType = RLMPropertyType

/**
 An opaque token which is returned from methods which subscribe to changes to a Realm.

 - see: `Realm.observe(_:)`
 */
public typealias NotificationToken = RLMNotificationToken

/// :nodoc:
public typealias ObjectBase = RLMObjectBase
extension ObjectBase {
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
    // swiftlint:disable:next identifier_name
    internal func _observe<T: ObjectBase>(keyPaths: [String]? = nil,
                                          on queue: DispatchQueue? = nil,
                                          _ block: @escaping (ObjectChange<T>) -> Void) -> NotificationToken {
        return RLMObjectBaseAddNotificationBlock(self, keyPaths, queue) { object, names, oldValues, newValues, error in
            if let error = error {
                block(.error(error as NSError))
                return
            }
            guard let names = names, let newValues = newValues else {
                block(.deleted)
                return
            }

            block(.change(object as! T, (0..<newValues.count).map { i in
                PropertyChange(name: names[i], oldValue: oldValues?[i], newValue: newValues[i])
            }))
        }
    }
}
