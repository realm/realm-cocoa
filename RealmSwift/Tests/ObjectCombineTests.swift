////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

import XCTest
import RealmSwift
import Foundation


@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class ObjectCombineTests: TestCase {

    func testAsPublisher() {
        let exp = expectation(description: "")

        let realm = try! Realm()
        var object: SwiftObject!
        try! realm.write {
            object = realm.create(SwiftObject.self, value: [:])
        }
        let objectRef = ThreadSafeReference(to: object)
        var objectChanges: [[PropertyChange]] = []
        let subscriber = object.asPublisher().sink {
            objectChanges.append($0)
        }
        queue.async {
            let realm = try! Realm()
            let object = realm.resolve(objectRef)!
            try! realm.write {
                object.stringCol = "abcd"
            }
            exp.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        realm.refresh()

        XCTAssertEqual(objectChanges.count, 1, "Value was not published")
        XCTAssertEqual(objectChanges[0].count, 1, "Value was not published")
        XCTAssertEqual(objectChanges[0][0].name, "stringCol", "Wrong property was reported")
        XCTAssertEqual(objectChanges[0][0].newValue as! String, "abcd", "Wrong value was reported")
        subscriber.cancel()
    }

    func testAsPublisherCompletion() {
        let exp = expectation(description: "")

        let realm = try! Realm()
        var object: SwiftObject!
        try! realm.write {
            object = realm.create(SwiftObject.self, value: [:])
        }
        let objectRef = ThreadSafeReference(to: object)

        var receivedCompletion: Bool = false
        var receivedValue: Bool = false
        let subscriber = object.asPublisher().sink(receiveCompletion: {_ in receivedCompletion = true },
                                                   receiveValue: {_ in receivedValue = true })
        queue.async {
            let realm = try! Realm()
            let object = realm.resolve(objectRef)!
            try! realm.write {
                realm.delete(object)
            }
            exp.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        realm.refresh()

        XCTAssertTrue(receivedCompletion)
        XCTAssertFalse(receivedValue)
        subscriber.cancel()
    }

    func testAsPublisherCancel() {
        let exp = expectation(description: "")

        let realm = try! Realm()
        var object: SwiftObject!
        try! realm.write {
            object = realm.create(SwiftObject.self, value: [:])
        }
        let objectRef = ThreadSafeReference(to: object)

        var valuePublished = false

        let subscriber = object.asPublisher().sink { _ in
            valuePublished = true
        }
        subscriber.cancel()
        queue.async {
            let realm = try! Realm()
            let object = realm.resolve(objectRef)!
            try! realm.write {
                object.stringCol = "abcd"
            }
            exp.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        realm.refresh()

        XCTAssertFalse(valuePublished, "Value was published after cancel.")
    }


}

#endif
