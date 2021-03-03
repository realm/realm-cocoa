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

#if os(macOS)

import XCTest
import RealmSwift

#if canImport(RealmTestSupport)
import RealmTestSupport
import RealmSyncTestSupport
#endif

public class SwiftHugeSyncObject: Object {
    @objc dynamic var _id = ObjectId.generate()
    @objc dynamic var data: Data?

    public override class func primaryKey() -> String? {
        return "_id"
    }

    public class func create() -> SwiftHugeSyncObject {
        let fakeDataSize = 1000000
        return SwiftHugeSyncObject(value: ["data": Data(repeating: 16, count: fakeDataSize)])
    }
}

public class SwiftPerson: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var firstName: String = ""
    @objc public dynamic var lastName: String = ""
    @objc public dynamic var age: Int = 30

    public convenience init(firstName: String, lastName: String) {
        self.init()
        self.firstName = firstName
        self.lastName = lastName
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public func randomString(_ length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}

open class SwiftSyncTestCase: RLMSyncTestCase {
    public func executeChild(file: StaticString = #file, line: UInt = #line) {
        XCTAssert(0 == runChildAndWait(), "Tests in child process failed", file: file, line: line)
    }

    public func basicCredentials(usernameSuffix: String = "", app: App? = nil) -> Credentials {
        let email = "\(randomString(10))\(usernameSuffix)"
        let password = "abcdef"
        let credentials = Credentials.emailPassword(email: email, password: password)
        let ex = expectation(description: "Should register in the user properly")
        (app ?? self.app).emailPasswordAuth.registerUser(email: email, password: password, completion: { error in
            XCTAssertNil(error)
            ex.fulfill()
        })
        waitForExpectations(timeout: 4, handler: nil)
        return credentials
    }

    public func openRealm(partitionValue: AnyBSON, user: User) throws -> Realm {
        let config = user.configuration(partitionValue: partitionValue)
        return try openRealm(configuration: config)
    }

    public func openRealm<T: BSON>(partitionValue: T,
                                   user: User,
                                   file: StaticString = #file,
                                   line: UInt = #line) throws -> Realm {
        let config = user.configuration(partitionValue: partitionValue)
        return try openRealm(configuration: config)
    }

    public func openRealm(configuration: Realm.Configuration) throws -> Realm {
        var configuration = configuration
        if configuration.objectTypes == nil {
            configuration.objectTypes = [SwiftPerson.self, SwiftHugeSyncObject.self]
        }
        let realm = try Realm(configuration: configuration)
        waitForDownloads(for: realm)
        return realm
    }

    public func immediatelyOpenRealm(partitionValue: String, user: User) throws -> Realm {
        var configuration = user.configuration(partitionValue: partitionValue)
        if configuration.objectTypes == nil {
            configuration.objectTypes = [SwiftPerson.self, SwiftHugeSyncObject.self]
        }
        return try Realm(configuration: configuration)
    }

    open func logInUser(for credentials: Credentials, app: App? = nil) throws -> User {
        var theUser: User!
        let ex = expectation(description: "Should log in the user properly")

        (app ?? self.app).login(credentials: credentials) { result in
            switch result {
            case .success(let user):
                theUser = user
                XCTAssertTrue(theUser.isLoggedIn)
            case .failure(let error):
                XCTFail("Should login user: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
        return theUser
    }

    public func waitForUploads(for realm: Realm) {
        waitForUploads(for: ObjectiveCSupport.convert(object: realm))
    }

    public func waitForDownloads(for realm: Realm) {
        waitForDownloads(for: ObjectiveCSupport.convert(object: realm))
    }

    public func checkCount<T: Object>(expected: Int,
                                      _ realm: Realm,
                                      _ type: T.Type,
                                      file: StaticString = #file,
                                      line: UInt = #line) {
        let actual = realm.objects(type).count
        XCTAssertEqual(actual, expected,
                       "Error: expected \(expected) items, but got \(actual) (process: \(isParent ? "parent" : "child"))",
            file: file,
            line: line)
    }

    var exceptionThrown = false

    public func assertThrows<T>(_ block: @autoclosure () -> T, named: String? = RLMExceptionName,
                                _ message: String? = nil, fileName: String = #file, lineNumber: UInt = #line) {
        exceptionThrown = true
        RLMAssertThrowsWithName(self, { _ = block() }, named, message, fileName, lineNumber)
    }

    public func assertThrows<T>(_ block: @autoclosure () -> T, reason: String,
                                _ message: String? = nil, fileName: String = #file, lineNumber: UInt = #line) {
        exceptionThrown = true
        RLMAssertThrowsWithReason(self, { _ = block() }, reason, message, fileName, lineNumber)
    }

    public func assertThrows<T>(_ block: @autoclosure () -> T, reasonMatching regexString: String,
                                _ message: String? = nil, fileName: String = #file, lineNumber: UInt = #line) {
        exceptionThrown = true
        RLMAssertThrowsWithReasonMatching(self, { _ = block() }, regexString, message, fileName, lineNumber)
    }

    public func assertSucceeds(message: String? = nil, fileName: StaticString = #file,
                               lineNumber: UInt = #line, block: () throws -> Void) {
        do {
            try block()
        } catch {
            XCTFail("Expected no error, but instead caught <\(error)>.",
                file: (fileName), line: lineNumber)
        }
    }
}

#endif // os(macOS)
