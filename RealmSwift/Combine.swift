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

#if canImport(Combine)
import Combine
import Realm.Private

// MARK: - Identifiable

/// A protocol which defines a default identity for Realm Objects
///
/// Declaring your Object subclass as conforming to this protocol will supply
/// a default implementation for `Identifiable`'s `id` which works for Realm
/// Objects:
///
///     // Automatically conforms to `Identifiable`
///     class MyObjectType: Object, ObjectKeyIdentifiable {
///         // ...
///     }
///
/// You can also manually conform to `Identifiable` if you wish, but note that
/// using the object's memory address does *not* work for managed objects.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol ObjectKeyIdentifiable: Identifiable, ObjectBase {
    /// The stable identity of the entity associated with `self`.
    var id: UInt64 { get }
}

/// :nodoc:
@available(*, deprecated, renamed: "ObjectKeyIdentifiable")
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public typealias ObjectKeyIdentifable = ObjectKeyIdentifiable

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension ObjectKeyIdentifiable {
    /// A stable identifier for this object. For managed Realm objects, this
    /// value will be the same for all object instances which refer to the same
    /// object (i.e. for which `Object.isSameObject(as:)` returns true).
    public var id: UInt64 {
        RLMObjectBaseGetCombineId(self)
    }
}

// MARK: - Combine

/// A type which can be passed to `valuePublisher()` or `changesetPublisher()`.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public protocol RealmSubscribable {
    // swiftlint:disable identifier_name
    /// :nodoc:
    func _observe<S>(on queue: DispatchQueue?, _ subscriber: S)
        -> NotificationToken where S: Subscriber, S.Input == Self, S.Failure == Error
    // swiftlint:enable identifier_name
    /// :nodoc:
    func _observe<S>(_ subscriber: S)
        -> NotificationToken where S: Subscriber, S.Input == Void, S.Failure == Never
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Publisher {
    /// Freezes all Realm objects and collections emitted by the upstream publisher
    ///
    /// Freezing a Realm object makes it no longer live-update when writes are
    /// made to the Realm and makes it safe to pass freely between threads
    /// without using `.threadSafeReference()`.
    ///
    /// ```
    /// // Get a publisher for a Results
    /// let cancellable = myResults.publisher
    ///    // Convert to frozen Results
    ///    .freeze()
    ///    // Unlike live objects, frozen objects can be sent to a concurrent queue
    ///    .receive(on: DispatchQueue.global())
    ///    .sink { frozenResults in
    ///        // Do something with the frozen Results
    ///    }
    /// ```
    ///
    /// - returns: A publisher that publishes frozen copies of the objects which the upstream publisher publishes.
    public func freeze<T>() -> Publishers.Map<Self, T> where Output: ThreadConfined, T == Output {
        return map { $0.freeze() }
    }

    /// Freezes all Realm object changesets emitted by the upstream publisher.
    ///
    /// Freezing a Realm object changeset makes the included object reference
    /// no longer live-update when writes are made to the Realm and makes it
    /// safe to pass freely between threads without using
    /// `.threadSafeReference()`. It also guarantees that the frozen object
    /// contained in the changset will always match the property changes, which
    /// is not always the case when using thread-safe references.
    ///
    /// ```
    /// // Get a changeset publisher for an object
    /// let cancellable = changesetPublisher(object)
    ///    // Convert to frozen changesets
    ///    .freeze()
    ///    // Unlike live objects, frozen objects can be sent to a concurrent queue
    ///    .receive(on: DispatchQueue.global())
    ///    .sink { changeset in
    ///        // Do something with the frozen changeset
    ///    }
    /// ```
    ///
    /// - returns: A publisher that publishes frozen copies of the changesets
    ///            which the upstream publisher publishes.
    public func freeze<T: Object>() -> Publishers.Map<Self, ObjectChange<T>> where Output == ObjectChange<T> {
        return map {
            if case .change(let object, let properties) = $0 {
                return .change(object.freeze(), properties)
            }
            return $0
        }
    }

    /// Freezes all Realm collection changesets from the upstream publisher.
    ///
    /// Freezing a Realm collection changeset makes the included collection
    /// reference no longer live-update when writes are made to the Realm and
    /// makes it safe to pass freely between threads without using
    /// `.threadSafeReference()`. It also guarantees that the frozen collection
    /// contained in the changset will always match the change information,
    /// which is not always the case when using thread-safe references.
    ///
    /// ```
    /// // Get a changeset publisher for a collection
    /// let cancellable = myList.changesetPublisher
    ///    // Convert to frozen changesets
    ///    .freeze()
    ///    // Unlike live objects, frozen objects can be sent to a concurrent queue
    ///    .receive(on: DispatchQueue.global())
    ///    .sink { changeset in
    ///        // Do something with the frozen changeset
    ///    }
    /// ```
    ///
    /// - returns: A publisher that publishes frozen copies of the changesets
    ///            which the upstream publisher publishes.
    public func freeze<T: RealmCollection>()
        -> Publishers.Map<Self, RealmCollectionChange<T>> where Output == RealmCollectionChange<T> {
            return map {
                switch $0 {
                case .initial(let collection):
                    return .initial(collection.freeze())
                case .update(let collection, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    return .update(collection.freeze(), deletions: deletions, insertions: insertions, modifications: modifications)
                case .error(let error):
                    return .error(error)
                }
            }
    }

    /// Freezes all Realm collection changesets from the upstream publisher.
    ///
    /// Freezing a Realm collection changeset makes the included collection
    /// reference no longer live-update when writes are made to the Realm and
    /// makes it safe to pass freely between threads without using
    /// `.threadSafeReference()`. It also guarantees that the frozen collection
    /// contained in the changset will always match the change information,
    /// which is not always the case when using thread-safe references.
    ///
    /// ```
    /// // Get a changeset publisher for a collection
    /// let cancellable = myMap.changesetPublisher
    ///    // Convert to frozen changesets
    ///    .freeze()
    ///    // Unlike live objects, frozen objects can be sent to a concurrent queue
    ///    .receive(on: DispatchQueue.global())
    ///    .sink { changeset in
    ///        // Do something with the frozen changeset
    ///    }
    /// ```
    ///
    /// - returns: A publisher that publishes frozen copies of the changesets
    ///            which the upstream publisher publishes.
    public func freeze<T: RealmKeyedCollection>()
        -> Publishers.Map<Self, RealmMapChange<T>> where Output == RealmMapChange<T> {
            return map {
                switch $0 {
                case .initial(let collection):
                    return .initial(collection.freeze())
                case .update(let collection, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    return .update(collection.freeze(), deletions: deletions, insertions: insertions, modifications: modifications)
                case .error(let error):
                    return .error(error)
                }
            }
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Publisher where Output: ThreadConfined {
    /// Enables passing thread-confined objects to a different dispatch queue.
    ///
    /// Each call to `receive(on:)` on a publisher which emits Realm
    /// thread-confined objects must be proceeded by a call to
    /// `.threadSafeReference()`.The returned publisher handles the required
    /// logic to pass the thread-confined object to the new queue. Only serial
    /// dispatch queues are supported and using other schedulers will result in
    /// a fatal error.
    ///
    /// For example, to subscribe on a background thread, do some work there,
    /// then pass the object to the main thread you can do:
    ///
    ///     let cancellable = publisher(myObject)
    ///         .subscribe(on: DispatchQueue(label: "background queue")
    ///         .print()
    ///         .threadSafeReference()
    ///         .receive(on: DispatchQueue.main)
    ///         .sink { object in
    ///             // Do things with the object on the main thread
    ///         }
    ///
    /// Calling this function on a publisher which emits frozen or unmanaged
    /// objects is unneccesary but is allowed.
    ///
    /// - returns: A publisher that supports `receive(on:)` for thread-confined objects.
    public func threadSafeReference() -> RealmPublishers.MakeThreadSafe<Self> {
        RealmPublishers.MakeThreadSafe(self)
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Publisher {
    /// Enables passing object changesets to a different dispatch queue.
    ///
    /// Each call to `receive(on:)` on a publisher which emits Realm
    /// thread-confined objects must be proceeded by a call to
    /// `.threadSafeReference()`. The returned publisher handles the required
    /// logic to pass the thread-confined object to the new queue. Only serial
    /// dispatch queues are supported and using other schedulers will result in
    /// a fatal error.
    ///
    /// For example, to subscribe on a background thread, do some work there,
    /// then pass the object changeset to the main thread you can do:
    ///
    ///     let cancellable = changesetPublisher(myObject)
    ///         .subscribe(on: DispatchQueue(label: "background queue")
    ///         .print()
    ///         .threadSafeReference()
    ///         .receive(on: DispatchQueue.main)
    ///         .sink { objectChange in
    ///             // Do things with the object on the main thread
    ///         }
    ///
    /// - returns: A publisher that supports `receive(on:)` for thread-confined objects.
    public func threadSafeReference<T: Object>()
        -> RealmPublishers.MakeThreadSafeObjectChangeset<Self, T> where Output == ObjectChange<T> {
        RealmPublishers.MakeThreadSafeObjectChangeset(self)
    }

    /// Enables passing Realm collection changesets to a different dispatch queue.
    ///
    /// Each call to `receive(on:)` on a publisher which emits Realm
    /// thread-confined objects must be proceeded by a call to
    /// `.threadSafeReference()`. The returned publisher handles the required
    /// logic to pass the thread-confined object to the new queue. Only serial
    /// dispatch queues are supported and using other schedulers will result in
    /// a fatal error.
    ///
    /// For example, to subscribe on a background thread, do some work there,
    /// then pass the collection changeset to the main thread you can do:
    ///
    ///     let cancellable = myCollection.changesetPublisher
    ///         .subscribe(on: DispatchQueue(label: "background queue")
    ///         .print()
    ///         .threadSafeReference()
    ///         .receive(on: DispatchQueue.main)
    ///         .sink { collectionChange in
    ///             // Do things with the collection on the main thread
    ///         }
    ///
    /// - returns: A publisher that supports `receive(on:)` for thread-confined objects.
    public func threadSafeReference<T: RealmCollection>()
        -> RealmPublishers.MakeThreadSafeCollectionChangeset<Self, T> where Output == RealmCollectionChange<T> {
        RealmPublishers.MakeThreadSafeCollectionChangeset(self)
    }

    /// Enables passing Realm collection changesets to a different dispatch queue.
    ///
    /// Each call to `receive(on:)` on a publisher which emits Realm
    /// thread-confined objects must be proceeded by a call to
    /// `.threadSafeReference()`. The returned publisher handles the required
    /// logic to pass the thread-confined object to the new queue. Only serial
    /// dispatch queues are supported and using other schedulers will result in
    /// a fatal error.
    ///
    /// For example, to subscribe on a background thread, do some work there,
    /// then pass the collection changeset to the main thread you can do:
    ///
    ///     let cancellable = myCollection.changesetPublisher
    ///         .subscribe(on: DispatchQueue(label: "background queue")
    ///         .print()
    ///         .threadSafeReference()
    ///         .receive(on: DispatchQueue.main)
    ///         .sink { collectionChange in
    ///             // Do things with the collection on the main thread
    ///         }
    ///
    /// - returns: A publisher that supports `receive(on:)` for thread-confined objects.
    public func threadSafeReference<T: RealmKeyedCollection>()
        -> RealmPublishers.MakeThreadSafeKeyedCollectionChangeset<Self, T> where Output == RealmMapChange<T> {
        RealmPublishers.MakeThreadSafeKeyedCollectionChangeset(self)
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension RealmCollection where Self: RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<Self> {
        RealmPublishers.WillChange(self)
    }

    /// :nodoc:
    @available(*, deprecated, renamed: "collectionPublisher")
    public var publisher: RealmPublishers.Value<Self> {
        RealmPublishers.Value(self)
    }

    /// A publisher that emits the collection each time the collection changes.
    public var collectionPublisher: RealmPublishers.Value<Self> {
        RealmPublishers.Value(self)
    }

    /// A publisher that emits a collection changeset each time the collection changes.
    public var changesetPublisher: RealmPublishers.CollectionChangeset<Self> {
        RealmPublishers.CollectionChangeset(self)
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension RealmKeyedCollection where Self: RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<Self> {
        RealmPublishers.WillChange(self)
    }

    /// :nodoc:
    @available(*, deprecated, renamed: "collectionPublisher")
    public var publisher: RealmPublishers.Value<Self> {
        RealmPublishers.Value(self)
    }

    /// A publisher that emits the collection each time the collection changes.
    public var collectionPublisher: RealmPublishers.Value<Self> {
        RealmPublishers.Value(self)
    }

    /// A publisher that emits a collection changeset each time the collection changes.
    public var changesetPublisher: RealmPublishers.MapChangeset<Self> {
        RealmPublishers.MapChangeset(self)
    }
}

/// Creates a publisher that emits the object each time the object changes.
///
/// - precondition: The object must be a managed object which has not been invalidated.
/// - parameter object: A managed object to observe.
/// - returns: A publisher that emits the object each time it changes.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public func valuePublisher<T: Object>(_ object: T) -> RealmPublishers.Value<T> {
    RealmPublishers.Value<T>(object)
}

/// Creates a publisher that emits the collection each time the collection changes.
///
/// - precondition: The collection must be a managed collection which has not been invalidated.
/// - parameter object: A managed collection to observe.
/// - returns: A publisher that emits the collection each time it changes.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public func valuePublisher<T: RealmCollection>(_ collection: T) -> RealmPublishers.Value<T> {
    RealmPublishers.Value<T>(collection)
}

/// Creates a publisher that emits an object changeset each time the object changes.
///
/// - precondition: The object must be a managed object which has not been invalidated.
/// - parameter object: A managed object to observe.
/// - returns: A publisher that emits an object changeset each time the object changes.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public func changesetPublisher<T: Object>(_ object: T) -> RealmPublishers.ObjectChangeset<T> {
    RealmPublishers.ObjectChangeset<T>(object)
}

/// Creates a publisher that emits a collection changeset each time the collection changes.
///
/// - precondition: The collection must be a managed collection which has not been invalidated.
/// - parameter object: A managed collection to observe.
/// - returns: A publisher that emits a collection changeset each time the collection changes.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public func changesetPublisher<T: RealmCollection>(_ collection: T) -> RealmPublishers.CollectionChangeset<T> {
    RealmPublishers.CollectionChangeset<T>(collection)
}

// MARK: - Realm

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Realm {
    /// A publisher that emits Void each time the object changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.RealmWillChange {
        return RealmPublishers.RealmWillChange(self)
    }
}

// MARK: - Object

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Object: ObservableObject {
    /// A publisher that emits Void each time the object changes.
    ///
    /// Despite the name, this actually emits *after* the object has changed.
    public var objectWillChange: RealmPublishers.WillChange<Object> {
        return RealmPublishers.WillChange(self)
    }
}
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension EmbeddedObject: ObservableObject {
    /// A publisher that emits Void each time the object changes.
    ///
    /// Despite the name, this actually emits *after* the embedded object has changed.
    public var objectWillChange: RealmPublishers.WillChange<EmbeddedObject> {
        return RealmPublishers.WillChange(self)
    }
}
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension ObjectBase: RealmSubscribable {
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe<S>(on queue: DispatchQueue?, _ subscriber: S) -> NotificationToken
        where S.Input: ObjectBase, S: Subscriber, S.Failure == Error {
        return _observe(on: queue) { (change: ObjectChange<S.Input>) in
            switch change {
            case .change(let object, _):
                _ = subscriber.receive(object)
            case .deleted:
                subscriber.receive(completion: .finished)
            case .error(let error):
                subscriber.receive(completion: .failure(error))
            }
        }
    }

    /// :nodoc:
    public func _observe<S: Subscriber>(_ subscriber: S) -> NotificationToken where S.Input == Void, S.Failure == Never {
        return _observe { _ in _ = subscriber.receive() }
    }
}

// MARK: - List

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension List: ObservableObject, RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<List> {
        RealmPublishers.WillChange(self)
    }
}

// MARK: - MutableSet

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension MutableSet: ObservableObject, RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<MutableSet> {
        RealmPublishers.WillChange(self)
    }
}

// MARK: - Map

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Map: ObservableObject, RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<Map> {
        RealmPublishers.WillChange(self)
    }
}

// MARK: - LinkingObjects

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension LinkingObjects: RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<LinkingObjects> {
        RealmPublishers.WillChange(self)
    }
}

// MARK: - Results

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Results: RealmSubscribable {
    /// A publisher that emits Void each time the collection changes.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public var objectWillChange: RealmPublishers.WillChange<Results> {
        RealmPublishers.WillChange(self)
    }
}

// MARK: RealmCollection

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension RealmCollection {
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe<S>(on queue: DispatchQueue? = nil, _ subscriber: S)
        -> NotificationToken where S: Subscriber, S.Input == Self, S.Failure == Error {
            // FIXME: we could skip some pointless work in converting the changeset to the Swift type here
            return observe(on: queue) { change in
                switch change {
                case .initial(let collection):
                    _ = subscriber.receive(collection)
                case .update(let collection, deletions: _, insertions: _, modifications: _):
                    _ = subscriber.receive(collection)
                case .error(let error):
                    subscriber.receive(completion: .failure(error))
                }
            }
    }

    /// :nodoc:
    public func _observe<S: Subscriber>(_ subscriber: S) -> NotificationToken where S.Input == Void, S.Failure == Never {
        return observe(on: nil) { _ in _ = subscriber.receive() }
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension AnyRealmCollection: RealmSubscribable {}

// MARK: RealmKeyedCollection

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension RealmKeyedCollection {
    /// :nodoc:
    // swiftlint:disable:next identifier_name
    public func _observe<S>(on queue: DispatchQueue? = nil, _ subscriber: S)
        -> NotificationToken where S: Subscriber, S.Input == Self, S.Failure == Error {
            // FIXME: we could skip some pointless work in converting the changeset to the Swift type here
            return observe(on: queue) { change in
                switch change {
                case .initial(let collection):
                    _ = subscriber.receive(collection)
                case .update(let collection, deletions: _, insertions: _, modifications: _):
                    _ = subscriber.receive(collection)
                case .error(let error):
                    subscriber.receive(completion: .failure(error))
                }
            }
    }

    /// :nodoc:
    public func _observe<S: Subscriber>(_ subscriber: S) -> NotificationToken where S.Input == Void, S.Failure == Never {
        return observe(on: nil) { _ in _ = subscriber.receive() }
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension SyncSession: ObservableObject {
    /// :nodoc:
    public var objectWillChange: NSObject.KeyValueObservingPublisher<RLMSyncSession, RLMSyncConnectionState> {
        self.publisher(for: \.connectionState)
    }
}

// MARK: Subscriptions

/// A subscription which wraps a Realm notification.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
@frozen public struct ObservationSubscription: Subscription {
    private var token: NotificationToken
    internal init(token: NotificationToken) {
        self.token = token
    }

    /// A unique identifier for identifying publisher streams.
    public var combineIdentifier: CombineIdentifier {
        return CombineIdentifier(token)
    }

    /// This function is not implemented.
    ///
    /// Realm publishers do not support backpressure and so this function does nothing.
    public func request(_ demand: Subscribers.Demand) {
    }

    /// Stop emitting values on this subscription.
    public func cancel() {
        token.invalidate()
    }
}

/// A subscription which wraps a Realm AsyncOpenTask.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
@frozen public struct AsyncOpenSubscription: Subscription {
    private let task: Realm.AsyncOpenTask

    internal init(task: Realm.AsyncOpenTask,
                  callbackQueue: DispatchQueue,
                  onProgressNotificationCallback: ((SyncSession.Progress) -> Void)?) {
        self.task = task
        if let onProgressNotificationCallback = onProgressNotificationCallback {
            self.task.addProgressNotification(queue: callbackQueue, block: onProgressNotificationCallback)
        }
    }

    /// A unique identifier for identifying publisher streams.
    public var combineIdentifier: CombineIdentifier {
        return CombineIdentifier(task.rlmTask)
    }

    /// This function is not implemented.
    ///
    /// Realm publishers do not support backpressure and so this function does nothing.
    public func request(_ demand: Subscribers.Demand) {
    }

    /// Stop emitting values on this subscription.
    public func cancel() {
        task.cancel()
    }
}

// MARK: Publishers

/// Combine publishers for Realm types.
///
/// You normally should not create any of these types directly, and should
/// instead use the extension methods which create them.
@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public enum RealmPublishers {
    static private func realm<S: Scheduler>(_ config: RLMRealmConfiguration, _ scheduler: S) -> Realm? {
        try? Realm(RLMRealm(configuration: config, queue: scheduler as? DispatchQueue))
    }

    /// A publisher which emits an asynchronously opened Realm.
    @frozen public struct AsyncOpenPublisher: Publisher {
        /// This publisher can fail if there is an error opening the Realm.
        public typealias Failure = Error
        /// This publisher emits an opened Realm.
        public typealias Output = Realm

        private let configuration: Realm.Configuration
        private let callbackQueue: DispatchQueue
        private let onProgressNotificationCallback: ((SyncSession.Progress) -> Void)?

        internal init(configuration: Realm.Configuration,
                      callbackQueue: DispatchQueue = .main,
                      onProgressNotificationCallback: ((SyncSession.Progress) -> Void)? = nil) {
            self.configuration = configuration
            self.callbackQueue = callbackQueue
            self.onProgressNotificationCallback = onProgressNotificationCallback
        }

        /// Triggers an event when there is a notification on the async open progress.
        ///
        /// This should be called directly after invoking the publisher.
        ///
        /// - Parameter onProgressNotificationCallback: Callback which will be invoked when there is an update on progress.
        /// - Returns: A publisher that emits an asynchronously opened Realm.
        public func onProgressNotification(_ onProgressNotificationCallback: @escaping ((SyncSession.Progress) -> Void)) -> Self {
            Self(configuration: configuration,
                 callbackQueue: callbackQueue,
                 onProgressNotificationCallback: onProgressNotificationCallback)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            subscriber.receive(subscription: AsyncOpenSubscription(task: Realm.AsyncOpenTask(rlmTask: RLMRealm.asyncOpen(with: configuration.rlmConfiguration, callbackQueue: callbackQueue, callback: { rlmRealm, error in
                if let realm = rlmRealm.flatMap(Realm.init) {
                    _ = subscriber.receive(realm)
                } else {
                    subscriber.receive(completion: .failure(error ?? Realm.Error.callFailed))
                }
            })), callbackQueue: callbackQueue, onProgressNotificationCallback: onProgressNotificationCallback))
        }

        /// Specifies the scheduler on which to perform the async open task.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> Self {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }

            return Self(configuration: configuration,
                        callbackQueue: queue,
                        onProgressNotificationCallback: onProgressNotificationCallback)
        }
    }

    /// A publisher which emits Void each time the Realm is refreshed.
    ///
    /// Despite the name, this actually emits *after* the Realm is refreshed.
    @frozen public struct RealmWillChange: Publisher {
        /// This publisher cannot fail.
        public typealias Failure = Never
        /// This publisher emits Void.
        public typealias Output = Void

        private let realm: Realm

        internal init(_ realm: Realm) {
            self.realm = realm
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `RealmWillChangeWithToken` Publisher.
        public func saveToken<T>(on object: T, for keyPath: WritableKeyPath<T, NotificationToken?>) -> RealmWillChangeWithToken<T> {
              return RealmWillChangeWithToken<T>(realm, object, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.realm.observe { _, _ in
                _ = subscriber.receive()
            }
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }
    }

    /// :nodoc:
    public class RealmWillChangeWithToken<T>: Publisher {
        /// This publisher cannot fail.
        public typealias Failure = Never
        /// This publisher emits Void.
        public typealias Output = Void

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private let realm: Realm
        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        internal init(_ realm: Realm,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            self.realm = realm
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.realm.observe { _, _ in
                _ = subscriber.receive()
            }
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }
    }
    /// A publisher which emits Void each time the object is mutated.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    @frozen public struct WillChange<Collection: RealmSubscribable>: Publisher where Collection: ThreadConfined {
        /// This publisher cannot fail.
        public typealias Failure = Never
        /// This publisher emits Void.
        public typealias Output = Void

        private let collection: Collection

        internal init(_ collection: Collection) {
            self.collection = collection
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `WillChangeWithToken` Publisher.
        public func saveToken<T>(on object: T, at keyPath: WritableKeyPath<T, NotificationToken?>) -> WillChangeWithToken<Collection, T> {
              return WillChangeWithToken<Collection, T>(collection, object, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token =  self.collection._observe(subscriber)
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }
    }

    /// A publisher which emits Void each time the object is mutated.
    ///
    /// Despite the name, this actually emits *after* the collection has changed.
    public class WillChangeWithToken<Collection: RealmSubscribable, T>: Publisher where Collection: ThreadConfined {
        /// This publisher cannot fail.
        public typealias Failure = Never
        /// This publisher emits Void.
        public typealias Output = Void

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private let object: Collection
        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        internal init(_ object: Collection,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            self.object = object
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token =  self.object._observe(subscriber)
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }
    }

    /// A publisher which emits an object or collection each time that object is mutated.
    @frozen public struct Value<Subscribable: RealmSubscribable>: Publisher where Subscribable: ThreadConfined {
        /// This publisher can only fail due to resource exhaustion when
        /// creating the worker thread used for change notifications.
        public typealias Failure = Error
        /// This publisher emits the object or collection which it is publishing.
        public typealias Output = Subscribable

        private let subscribable: Subscribable
        private let queue: DispatchQueue?
        internal init(_ subscribable: Subscribable, queue: DispatchQueue? = nil) {
            precondition(subscribable.realm != nil, "Only managed objects can be published")
            self.subscribable = subscribable
            self.queue = queue
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `ValueWithToken` Publisher.
        public func saveToken<T>(on object: T, at keyPath: WritableKeyPath<T, NotificationToken?>) -> ValueWithToken<Subscribable, T> {
              return ValueWithToken<Subscribable, T>(subscribable, queue, object, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            subscriber.receive(subscription: ObservationSubscription(token: self.subscribable._observe(on: queue, subscriber)))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> Value<Subscribable> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return Value(subscribable, queue: queue)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> RealmPublishers.Handover<Self, S> {
            return Handover(self, scheduler, self.subscribable.realm!)
        }
    }

    /// A publisher which emits an object or collection each time that object is mutated.
    public class ValueWithToken<Subscribable: RealmSubscribable, T>: Publisher where Subscribable: ThreadConfined {
        /// This publisher can only fail due to resource exhaustion when
        /// creating the worker thread used for change notifications.
        public typealias Failure = Error
        /// This publisher emits the object or collection which it is publishing.
        public typealias Output = Subscribable

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private let object: Subscribable
        private let queue: DispatchQueue?

        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        internal init(_ object: Subscribable,
                      _ queue: DispatchQueue? = nil,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            precondition(object.realm != nil, "Only managed objects can be published")
            self.object = object
            self.queue = queue
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }
        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            let token = self.object._observe(on: queue, subscriber)
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> ValueWithToken<Subscribable, T> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return ValueWithToken(object, queue, tokenParent, tokenKeyPath)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> Handover<ValueWithToken, S> {
            return Handover(self, scheduler, self.object.realm!)
        }
    }

    /// A helper publisher used to support `receive(on:)` on Realm publishers.
    @frozen public struct Handover<Upstream: Publisher, S: Scheduler>: Publisher where Upstream.Output: ThreadConfined {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let config: RLMRealmConfiguration
        private let upstream: Upstream
        private let scheduler: S

        internal init(_ upstream: Upstream, _ scheduler: S, _ realm: Realm) {
            self.config = realm.rlmRealm.configuration
            self.upstream = upstream
            self.scheduler = scheduler
        }

        /// :nodoc:
        public func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Sub.Failure == Failure, Output == Sub.Input {
            let scheduler = self.scheduler
            let config = self.config
            self.upstream
                .map { ThreadSafeReference(to: $0) }
                .receive(on: scheduler)
                .compactMap { realm(config, scheduler)?.resolve($0) }
                .receive(subscriber: subscriber)
        }
    }

    /// A publisher which makes `receive(on:)` work for streams of thread-confined objects
    ///
    /// Create using .threadSafeReference()
    @frozen public struct MakeThreadSafe<Upstream: Publisher>: Publisher where Upstream.Output: ThreadConfined {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        internal init(_ upstream: Upstream) {
            self.upstream = upstream
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            self.upstream.receive(subscriber: subscriber)
        }

        /// Specifies the scheduler on which to receive elements from the publisher.
        ///
        /// This publisher converts each value emitted by the upstream
        /// publisher to a `ThreadSafeReference`, passes it to the target
        /// scheduler, and then converts back to the original type.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandover<Upstream, S> {
            DeferredHandover(self.upstream, scheduler)
        }
    }

    /// A publisher which delivers thread-confined values to a serial dispatch queue.
    ///
    /// Create using `.threadSafeReference().receive(on: queue)` on a publisher
    /// that emits thread-confined objects.
    @frozen public struct DeferredHandover<Upstream: Publisher, S: Scheduler>: Publisher where Upstream.Output: ThreadConfined {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        private let scheduler: S
        internal init(_ upstream: Upstream, _ scheduler: S) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        private enum Handover {
            case object(_ object: Output)
            case tsr(_ tsr: ThreadSafeReference<Output>, config: RLMRealmConfiguration)
        }

        /// :nodoc:
        public func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Sub.Failure == Failure, Output == Sub.Input {
            let scheduler = self.scheduler
            self.upstream
                .map { (obj: Output) -> Handover in
                    guard let realm = obj.realm, !realm.isFrozen else { return .object(obj) }
                    return .tsr(ThreadSafeReference(to: obj), config: realm.rlmRealm.configuration)
            }
            .receive(on: scheduler)
            .compactMap { (handover: Handover) -> Output? in
                switch handover {
                case .object(let obj):
                    return obj
                case .tsr(let tsr, let config):
                    return realm(config, scheduler)?.resolve(tsr)
                }
            }
            .receive(subscriber: subscriber)
        }
    }

    /// A publisher which emits ObjectChange<T> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `objectChangeset()` function.
    @frozen public struct ObjectChangeset<O: Object>: Publisher {
        /// This publisher emits a ObjectChange<T> indicating which object and
        /// which properties of that object have changed each time a Realm is
        /// refreshed after a write transaction which modifies the observed
        /// object.
        public typealias Output = ObjectChange<O>
        /// This publisher reports error via the `.error` case of ObjectChange.
        public typealias Failure = Never

        private let object: O
        private let queue: DispatchQueue?
        internal init(_ object: O, queue: DispatchQueue? = nil) {
            precondition(object.realm != nil, "Only managed objects can be published")
            precondition(!object.isInvalidated, "Object is invalidated or deleted")
            self.object = object
            self.queue = queue
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `ObjectChangesetWithToken` Publisher.
        public func saveToken<T>(on tokenParent: T, at keyPath: WritableKeyPath<T, NotificationToken?>) -> ObjectChangesetWithToken<O, T> {
              return ObjectChangesetWithToken<O, T>(object, queue, tokenParent, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.object.observe(on: self.queue) { change in
                switch change {
                case .change(let o, let properties):
                    _ = subscriber.receive(.change(o as! O, properties))
                case .error(let error):
                    _ = subscriber.receive(.error(error))
                case .deleted:
                    subscriber.receive(completion: .finished)
                }
            }
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> ObjectChangeset<O> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return ObjectChangeset(object, queue: queue)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverObjectChangeset<Self, O, S> {
            DeferredHandoverObjectChangeset(self, scheduler)
        }
    }

    /// A publisher which emits ObjectChange<T> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `objectChangeset()` function.
    public class ObjectChangesetWithToken<O: Object, T>: Publisher {
        /// This publisher emits a ObjectChange<T> indicating which object and
        /// which properties of that object have changed each time a Realm is
        /// refreshed after a write transaction which modifies the observed
        /// object.
        public typealias Output = ObjectChange<O>
        /// This publisher reports error via the `.error` case of ObjectChange.
        public typealias Failure = Never

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        private let object: O
        private let queue: DispatchQueue?
        internal init(_ object: O,
                      _ queue: DispatchQueue? = nil,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            precondition(object.realm != nil, "Only managed objects can be published")
            precondition(!object.isInvalidated, "Object is invalidated or deleted")
            self.object = object
            self.queue = queue
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.object.observe(on: self.queue) { change in
                switch change {
                case .change(let o, let properties):
                    _ = subscriber.receive(.change(o as! O, properties))
                case .error(let error):
                    _ = subscriber.receive(.error(error))
                case .deleted:
                    subscriber.receive(completion: .finished)
                }
            }
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> ObjectChangesetWithToken<O, T> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return ObjectChangesetWithToken(object, queue, tokenParent, tokenKeyPath)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverObjectChangeset<ObjectChangesetWithToken, T, S> {
            DeferredHandoverObjectChangeset(self, scheduler)
        }
    }

    /// A helper publisher created by calling `.threadSafeReference()` on a publisher which emits thread-confined values.
    @frozen public struct MakeThreadSafeObjectChangeset<Upstream: Publisher, T: Object>: Publisher where Upstream.Output == ObjectChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        internal init(_ upstream: Upstream) {
            self.upstream = upstream
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            self.upstream.receive(subscriber: subscriber)
        }

        /// Specifies the scheduler to deliver object changesets to.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverObjectChangeset<Upstream, T, S> {
            DeferredHandoverObjectChangeset(self.upstream, scheduler)
        }
    }

    /// A publisher which delivers thread-confined object changesets to a serial dispatch queue.
    ///
    /// Create using `.threadSafeReference().receive(on: queue)` on a publisher
    /// that emits `ObjectChange`.
    @frozen public struct DeferredHandoverObjectChangeset<Upstream: Publisher, T: Object, S: Scheduler>: Publisher where Upstream.Output == ObjectChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        private let scheduler: S

        internal init(_ upstream: Upstream, _ scheduler: S) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        private enum Handover {
            case passthrough(_ change: ObjectChange<T>)
            case tsr(_ tsr: ThreadSafeReference<T>, _ properties: [PropertyChange], config: RLMRealmConfiguration)
        }

        /// :nodoc:
        public func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Sub.Failure == Failure, Output == Sub.Input {
            let scheduler = self.scheduler
            self.upstream
                .map { (change: Output) -> Handover in
                    guard case .change(let obj, let properties) = change else { return .passthrough(change) }
                    guard let realm = obj.realm, !realm.isFrozen else { return .passthrough(change) }
                    return .tsr(ThreadSafeReference(to: obj), properties, config: realm.rlmRealm.configuration)
                }
                .receive(on: scheduler)
                .compactMap { (handover: Handover) -> Output? in
                    switch handover {
                    case .passthrough(let change):
                        return change
                    case .tsr(let tsr, let properties, let config):
                        if let resolved = realm(config, scheduler)?.resolve(tsr) {
                            return .change(resolved, properties)
                        }
                        return nil
                    }
                }
                .receive(subscriber: subscriber)
        }
    }

    /// A publisher which emits RealmCollectionChange<T> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `changesetPublisher` property on RealmCollection.
    @frozen public struct CollectionChangeset<Collection: RealmCollection>: Publisher {
        public typealias Output = RealmCollectionChange<Collection>
        /// This publisher reports error via the `.error` case of RealmCollectionChange.
        public typealias Failure = Never

        private let collection: Collection
        private let queue: DispatchQueue?
        internal init(_ collection: Collection, queue: DispatchQueue? = nil) {
            precondition(collection.realm != nil, "Only managed collections can be published")
            self.collection = collection
            self.queue = queue
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `CollectionChangesetWithToken` Publisher.
        public func saveToken<T>(on object: T, at keyPath: WritableKeyPath<T, NotificationToken?>) -> CollectionChangesetWithToken<Collection, T> {
              return CollectionChangesetWithToken<Collection, T>(collection, queue, object, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.collection.observe(on: self.queue) { change in
                _ = subscriber.receive(change)
            }
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> CollectionChangeset<Collection> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return CollectionChangeset(collection, queue: queue)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverCollectionChangeset<Self, Collection, S> {
            DeferredHandoverCollectionChangeset(self, scheduler)
        }
    }

    /// A publisher which emits RealmMapChange<Key, Value> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `changesetPublisher` property on RealmCollection.
    @frozen public struct MapChangeset<Collection: RealmKeyedCollection>: Publisher {
        public typealias Output = RealmMapChange<Collection>
        /// This publisher reports error via the `.error` case of RealmMapChange.
        public typealias Failure = Never

        private let collection: Collection
        private let queue: DispatchQueue?
        internal init(_ collection: Collection, queue: DispatchQueue? = nil) {
            precondition(collection.realm != nil, "Only managed collections can be published")
            self.collection = collection
            self.queue = queue
        }

        /// Captures the `NotificationToken` produced by observing a Realm Collection.
        ///
        /// This allows you to do notification skipping when performing a `Realm.write(withoutNotifying:)`. You should use this call if you
        /// require to write to the Realm database and ignore this specific observation chain.
        /// The `NotificationToken` will be saved on the specified `KeyPath`from the observation block set up in `receive(subscriber:)`.
        ///
        /// - Parameters:
        ///   - object: The object which the `NotificationToken` is written to.
        ///   - keyPath: The KeyPath which the `NotificationToken` is written to.
        /// - Returns: A `CollectionChangesetWithToken` Publisher.
        public func saveToken<T>(on object: T, at keyPath: WritableKeyPath<T, NotificationToken?>) -> MapChangesetWithToken<Collection, T> {
              return MapChangesetWithToken<Collection, T>(collection, queue, object, keyPath)
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.collection.observe(on: self.queue) { change in
                _ = subscriber.receive(change)
            }
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> MapChangeset<Collection> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return MapChangeset(collection, queue: queue)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverKeyedCollectionChangeset<Self, Collection, S> {
            DeferredHandoverKeyedCollectionChangeset(self, scheduler)
        }
    }

    /// A publisher which emits RealmCollectionChange<T> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `changesetPublisher` property on RealmCollection.
    public class CollectionChangesetWithToken<Collection: RealmCollection, T>: Publisher {
        public typealias Output = RealmCollectionChange<Collection>
        /// This publisher reports error via the `.error` case of RealmCollectionChange.
        public typealias Failure = Never

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        private let collection: Collection
        private let queue: DispatchQueue?
        internal init(_ collection: Collection,
                      _ queue: DispatchQueue? = nil,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            precondition(collection.realm != nil, "Only managed collections can be published")
            self.collection = collection
            self.queue = queue
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.collection.observe(on: self.queue) { change in
                _ = subscriber.receive(change)
            }
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> CollectionChangesetWithToken<Collection, T> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return CollectionChangesetWithToken(collection, queue, tokenParent, tokenKeyPath)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverCollectionChangeset<CollectionChangesetWithToken, Collection, S> {
            DeferredHandoverCollectionChangeset(self, scheduler)
        }
    }

    /// A publisher which emits RealmMapChange<T> each time the observed object is modified
    ///
    /// `receive(on:)` and `subscribe(on:)` can be called directly on this
    /// publisher, and calling `.threadSafeReference()` is only required if
    /// there is an intermediate transform. If `subscribe(on:)` is used, it
    /// should always be the first operation in the pipeline.
    ///
    /// Create this publisher using the `changesetPublisher` property on RealmCollection.
    public class MapChangesetWithToken<Collection: RealmKeyedCollection, T>: Publisher {
        public typealias Output = RealmMapChange<Collection>
        /// This publisher reports error via the `.error` case of RealmCollectionChange.
        public typealias Failure = Never

        internal typealias TokenParent = T
        internal typealias TokenKeyPath = WritableKeyPath<T, NotificationToken?>

        private var tokenParent: TokenParent
        private var tokenKeyPath: TokenKeyPath

        private let collection: Collection
        private let queue: DispatchQueue?
        internal init(_ collection: Collection,
                      _ queue: DispatchQueue? = nil,
                      _ tokenParent: TokenParent,
                      _ tokenKeyPath: TokenKeyPath) {
            precondition(collection.realm != nil, "Only managed collections can be published")
            self.collection = collection
            self.queue = queue
            self.tokenParent = tokenParent
            self.tokenKeyPath = tokenKeyPath
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, Output == S.Input {
            let token = self.collection.observe(on: self.queue) { change in
                _ = subscriber.receive(change)
            }
            tokenParent[keyPath: tokenKeyPath] = token
            subscriber.receive(subscription: ObservationSubscription(token: token))
        }

        /// Specifies the scheduler on which to perform subscribe, cancel, and request operations.
        ///
        /// For Realm Publishers, this determines which queue the underlying
        /// change notifications are sent to. If `receive(on:)` is not used
        /// subsequently, it also will determine which queue elements received
        /// from the publisher are evaluated on. Currently only serial dispatch
        /// queues are supported, and the `options:` parameter is not
        /// supported.
        ///
        /// - parameter scheduler: The serial dispatch queue to perform the subscription on.
        /// - returns: A publisher which subscribes on the given scheduler.
        public func subscribe<S: Scheduler>(on scheduler: S) -> MapChangesetWithToken<Collection, T> {
            guard let queue = scheduler as? DispatchQueue else {
                fatalError("Cannot subscribe on scheduler \(scheduler): only serial dispatch queues are currently implemented.")
            }
            return MapChangesetWithToken(collection, queue, tokenParent, tokenKeyPath)
        }

        /// Specifies the scheduler on which to perform downstream operations.
        ///
        /// This differs from `subscribe(on:)` in how it is integrated with the
        /// autorefresh cycle. When using `subscribe(on:)`, the subscription is
        /// performed on the target scheduler and the publisher will emit the
        /// collection during the refresh. When using `receive(on:)`, the
        /// collection is then converted to a `ThreadSafeReference` and
        /// delivered to the target scheduler with no integration into the
        /// autorefresh cycle, meaning it may arrive some time after the
        /// refresh occurs.
        ///
        /// When in doubt, you probably want `subscribe(on:)`
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverKeyedCollectionChangeset<MapChangesetWithToken, Collection, S> {
            DeferredHandoverKeyedCollectionChangeset(self, scheduler)
        }
    }

    /// A helper publisher created by calling `.threadSafeReference()` on a
    /// publisher which emits `RealmCollectionChange`.
    @frozen public struct MakeThreadSafeCollectionChangeset<Upstream: Publisher, T: RealmCollection>: Publisher where Upstream.Output == RealmCollectionChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        internal init(_ upstream: Upstream) {
            self.upstream = upstream
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            self.upstream.receive(subscriber: subscriber)
        }

        /// Specifies the scheduler on which to receive elements from the publisher.
        ///
        /// This publisher converts each value emitted by the upstream
        /// publisher to a `ThreadSafeReference`, passes it to the target
        /// scheduler, and then converts back to the original type.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverCollectionChangeset<Upstream, T, S> {
            DeferredHandoverCollectionChangeset(self.upstream, scheduler)
        }
    }

    /// A helper publisher created by calling `.threadSafeReference()` on a
    /// publisher which emits `RealmMapChange`.
    @frozen public struct MakeThreadSafeKeyedCollectionChangeset<Upstream: Publisher, T: RealmKeyedCollection>: Publisher where Upstream.Output == RealmMapChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        internal init(_ upstream: Upstream) {
            self.upstream = upstream
        }

        /// :nodoc:
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, Output == S.Input {
            self.upstream.receive(subscriber: subscriber)
        }

        /// Specifies the scheduler on which to receive elements from the publisher.
        ///
        /// This publisher converts each value emitted by the upstream
        /// publisher to a `ThreadSafeReference`, passes it to the target
        /// scheduler, and then converts back to the original type.
        ///
        /// - parameter scheduler: The serial dispatch queue to receive values on.
        /// - returns: A publisher which delivers values to the given scheduler.
        public func receive<S: Scheduler>(on scheduler: S) -> DeferredHandoverKeyedCollectionChangeset<Upstream, T, S> {
            DeferredHandoverKeyedCollectionChangeset(self.upstream, scheduler)
        }
    }

    /// A publisher which delivers thread-confined collection changesets to a
    /// serial dispatch queue.
    ///
    /// Create using `.threadSafeReference().receive(on: queue)` on a publisher
    /// that emits `RealmCollectionChange`.
    @frozen public struct DeferredHandoverCollectionChangeset<Upstream: Publisher, T: RealmCollection, S: Scheduler>: Publisher where Upstream.Output == RealmCollectionChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        private let scheduler: S
        internal init(_ upstream: Upstream, _ scheduler: S) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        private enum Handover {
            case passthrough(_ change: RealmCollectionChange<T>)
            case initial(_ tsr: ThreadSafeReference<T>, config: RLMRealmConfiguration)
            case update(_ tsr: ThreadSafeReference<T>, deletions: [Int], insertions: [Int], modifications: [Int], config: RLMRealmConfiguration)
        }

        /// :nodoc:
        public func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Sub.Failure == Failure, Output == Sub.Input {
            let scheduler = self.scheduler
            self.upstream
                .map { (change: Output) -> Handover in
                    switch change {
                    case .initial(let collection):
                        guard let realm = collection.realm, !realm.isFrozen else { return .passthrough(change) }
                        return .initial(ThreadSafeReference(to: collection), config: realm.rlmRealm.configuration)
                    case .update(let collection, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                        guard let realm = collection.realm, !realm.isFrozen else { return .passthrough(change) }
                        return .update(ThreadSafeReference(to: collection), deletions: deletions, insertions: insertions, modifications: modifications, config: realm.rlmRealm.configuration)
                    case .error:
                        return .passthrough(change)
                    }
                }
                .receive(on: scheduler)
                .compactMap { (handover: Handover) -> Output? in
                    switch handover {
                    case .passthrough(let change):
                        return change
                    case .initial(let tsr, config: let config):
                        if let resolved = realm(config, scheduler)?.resolve(tsr) {
                            return .initial(resolved)
                        }
                        return nil
                    case .update(let tsr, deletions: let deletions, insertions: let insertions, modifications: let modifications, config: let config):
                        if let resolved = realm(config, scheduler)?.resolve(tsr) {
                            return .update(resolved, deletions: deletions, insertions: insertions, modifications: modifications)
                        }
                        return nil
                    }
                }
                .receive(subscriber: subscriber)
        }
    }

    /// A publisher which delivers thread-confined `Map` changesets to a
    /// serial dispatch queue.
    ///
    /// Create using `.threadSafeReference().receive(on: queue)` on a publisher
    /// that emits `RealmMapChange`.
    @frozen public struct DeferredHandoverKeyedCollectionChangeset<Upstream: Publisher, T: RealmKeyedCollection, S: Scheduler>: Publisher where Upstream.Output == RealmMapChange<T> {
        /// :nodoc:
        public typealias Failure = Upstream.Failure
        /// :nodoc:
        public typealias Output = Upstream.Output

        private let upstream: Upstream
        private let scheduler: S
        internal init(_ upstream: Upstream, _ scheduler: S) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        private enum Handover {
            case passthrough(_ change: RealmMapChange<T>)
            case initial(_ tsr: ThreadSafeReference<T>, config: RLMRealmConfiguration)
            case update(_ tsr: ThreadSafeReference<T>, deletions: [T.Key], insertions: [T.Key], modifications: [T.Key], config: RLMRealmConfiguration)
        }

        /// :nodoc:
        public func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Sub.Failure == Failure, Output == Sub.Input {
            let scheduler = self.scheduler
            self.upstream
                .map { (change: Output) -> Handover in
                    switch change {
                    case .initial(let collection):
                        guard let realm = collection.realm, !realm.isFrozen else { return .passthrough(change) }
                        return .initial(ThreadSafeReference(to: collection), config: realm.rlmRealm.configuration)
                    case .update(let collection, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                        guard let realm = collection.realm, !realm.isFrozen else { return .passthrough(change) }
                        return .update(ThreadSafeReference(to: collection), deletions: deletions, insertions: insertions, modifications: modifications, config: realm.rlmRealm.configuration)
                    case .error:
                        return .passthrough(change)
                    }
                }
                .receive(on: scheduler)
                .compactMap { (handover: Handover) -> Output? in
                    switch handover {
                    case .passthrough(let change):
                        return change
                    case .initial(let tsr, config: let config):
                        if let resolved = realm(config, scheduler)?.resolve(tsr) {
                            return .initial(resolved)
                        }
                        return nil
                    case .update(let tsr, deletions: let deletions, insertions: let insertions, modifications: let modifications, config: let config):
                        if let resolved = realm(config, scheduler)?.resolve(tsr) {
                            return .update(resolved, deletions: deletions, insertions: insertions, modifications: modifications)
                        }
                        return nil
                    }
                }
                .receive(subscriber: subscriber)
        }
    }
}
#endif // canImport(Combine)
