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

#if compiler(>=5.1)

import Foundation
import Realm
import Combine

/**
 Produces a Combine publisher for subscribing to changes to an object
 
 This publisher will produce the following:
 - a `[PropertyChange]` value whenever any object property changes
 - an `NSError` when an observation error occurs
 - a completion when the object is deleted
 */
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Object {
    func asPublisher() -> AnyPublisher<[PropertyChange], NSError> {
        let publisher = ObjectChangesPublisher(self)
        return publisher.eraseToAnyPublisher()
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate class ObjectChangesSubscription: Subscription {
    var token: NotificationToken?
    var demand: Subscribers.Demand = .unlimited

    init<S>(_ object: Object, subscriber: S) where S: Subscriber, NSError == S.Failure, [PropertyChange] == S.Input {

        token = object.observe {
            [weak self] in
            self?.dispatchObjectChange($0, to: subscriber)
        }
    }

    private func dispatchObjectChange<S>(_ objectChange: ObjectChange, to subscriber: S)  where S: Subscriber, NSError == S.Failure, [PropertyChange] == S.Input {
        switch objectChange {
        case .change(let propertyChanges):
            if self.demand != .none {
                self.demand = subscriber.receive(propertyChanges)
            }
        case .error(let error):
            subscriber.receive(completion: .failure(error))
        case .deleted:
            subscriber.receive(completion: .finished)
        }
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand = demand
    }

    func cancel() {
        token?.invalidate()
        token = nil
        demand = .none
    }

}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate struct ObjectChangesPublisher: Publisher {

    typealias Output = [PropertyChange]
    typealias Failure = NSError

    private let object: Object

    public init(_ object: Object) {
        self.object = object
    }
    func receive<S>(subscriber: S) where S: Subscriber, NSError == S.Failure, [PropertyChange] == S.Input {
        subscriber.receive(subscription: ObjectChangesSubscription(object, subscriber: subscriber))
    }

}

#endif
