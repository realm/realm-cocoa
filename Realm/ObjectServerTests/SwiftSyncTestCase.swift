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

public class SwiftTypesSyncObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var boolCol: Bool = true
    @objc public dynamic var intCol: Int = 1
    @objc public dynamic var doubleCol: Double = 1.1
    @objc public dynamic var stringCol: String = "string"
    @objc public dynamic var binaryCol: Data = "string".data(using: String.Encoding.utf8)!
    @objc public dynamic var dateCol: Date = Date(timeIntervalSince1970: -1)
    @objc public dynamic var longCol: Int64 = 1
    @objc public dynamic var decimalCol: Decimal128 = Decimal128(1)
    @objc public dynamic var uuidCol: UUID = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
    @objc public dynamic var objectIdCol: ObjectId = .generate()
    @objc public dynamic var objectCol: SwiftPerson?
    public var anyCol = RealmProperty<AnyRealmValue>()

    public convenience init(person: SwiftPerson) {
        self.init()
        self.anyCol.value = .int(1)
        self.objectCol = person
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftCollectionSyncObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    public let intList = List<Int>()
    public let boolList = List<Bool>()
    public let stringList = List<String>()
    public let dataList = List<Data>()
    public let dateList = List<Date>()
    public let doubleList = List<Double>()
    public let objectIdList = List<ObjectId>()
    public let decimalList = List<Decimal128>()
    public let uuidList = List<UUID>()
    public let anyList = List<AnyRealmValue>()
    public let objectList = List<SwiftPerson>()

    public let intSet = MutableSet<Int>()
    public let stringSet = MutableSet<String>()
    public let dataSet = MutableSet<Data>()
    public let dateSet = MutableSet<Date>()
    public let doubleSet = MutableSet<Double>()
    public let objectIdSet = MutableSet<ObjectId>()
    public let decimalSet = MutableSet<Decimal128>()
    public let uuidSet = MutableSet<UUID>()
    public let anySet = MutableSet<AnyRealmValue>()
    public let objectSet = MutableSet<SwiftPerson>()

    public let otherIntSet = MutableSet<Int>()
    public let otherStringSet = MutableSet<String>()
    public let otherDataSet = MutableSet<Data>()
    public let otherDateSet = MutableSet<Date>()
    public let otherDoubleSet = MutableSet<Double>()
    public let otherObjectIdSet = MutableSet<ObjectId>()
    public let otherDecimalSet = MutableSet<Decimal128>()
    public let otherUuidSet = MutableSet<UUID>()
    public let otherAnySet = MutableSet<AnyRealmValue>()
    public let otherObjectSet = MutableSet<SwiftPerson>()

    public let intMap = Map<String, Int>()
    public let stringMap = Map<String, String>()
    public let dataMap = Map<String, Data>()
    public let dateMap = Map<String, Date>()
    public let doubleMap = Map<String, Double>()
    public let objectIdMap = Map<String, ObjectId>()
    public let decimalMap = Map<String, Decimal128>()
    public let uuidMap = Map<String, UUID>()
    public let anyMap = Map<String, AnyRealmValue>()
    public let objectMap = Map<String, SwiftPerson>()

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftAnyRealmValueObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    public let anyCol = RealmProperty<AnyRealmValue>()
    public let otherAnyCol = RealmProperty<AnyRealmValue>()
    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftMissingObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var objectCol: SwiftPerson?
    public let anyCol = RealmProperty<AnyRealmValue>()
    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftUUIDPrimaryKeyObject: Object {
    public dynamic var _id: UUID? = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: UUID?, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftStringPrimaryKeyObject: Object {
    public dynamic var _id: String? = "1234567890ab1234567890ab"
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: String, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftIntPrimaryKeyObject: Object {
    public dynamic var _id: Int = 1234567890
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: Int, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
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
            configuration.objectTypes = [SwiftPerson.self,
                                         Person.self,
                                         Dog.self,
                                         HugeSyncObject.self,
                                         SwiftCollectionSyncObject.self,
                                         SwiftUUIDPrimaryKeyObject.self,
                                         SwiftStringPrimaryKeyObject.self,
                                         SwiftIntPrimaryKeyObject.self,
                                         SwiftTypesSyncObject.self]
        }
        let realm = try Realm(configuration: configuration)
        waitForDownloads(for: realm)
        return realm
    }

    public func immediatelyOpenRealm(partitionValue: String, user: User) throws -> Realm {
        var configuration = user.configuration(partitionValue: partitionValue)
        if configuration.objectTypes == nil {
            configuration.objectTypes = [SwiftPerson.self,
                                         Person.self,
                                         Dog.self,
                                         HugeSyncObject.self,
                                         SwiftTypesSyncObject.self]
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
