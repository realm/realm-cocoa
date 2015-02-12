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

import XCTest
import RealmSwift

class RealmTests: TestCase {
    override func setUp() {
        super.setUp()
        realmWithTestPath().write {
            SwiftStringObject.createInRealm(self.realmWithTestPath(), withObject: ["1"])
            SwiftStringObject.createInRealm(self.realmWithTestPath(), withObject: ["2"])
            SwiftStringObject.createInRealm(self.realmWithTestPath(), withObject: ["3"])
        }

        Realm().write {
            SwiftIntObject.createInRealm(Realm(), withObject: [100])
            SwiftIntObject.createInRealm(Realm(), withObject: [200])
            SwiftIntObject.createInRealm(Realm(), withObject: [300])
        }
    }

    func testRealmDefaultRealmPath() {
        let defaultPath =  Realm().path
        XCTAssertEqual(Realm.defaultPath, defaultPath)

        let newPath = defaultPath.stringByAppendingPathExtension("new")!
        Realm.defaultPath = newPath
        XCTAssertEqual(Realm.defaultPath, newPath)

        // we have to clean up
        Realm.defaultPath = defaultPath
    }

    func testDefaultRealm() {
        XCTAssertNotNil(Realm())
        XCTAssertTrue(Realm() as AnyObject is Realm)
    }

    func testSetEncryptionKey() {
        setEncryptionKey(NSMutableData(length: 64), forRealmsAtPath: Realm.defaultPath)
        setEncryptionKey(nil, forRealmsAtPath: Realm.defaultPath)
        XCTAssert(true, "setting those keys should not throw")
    }

    func testPath() {
        let realm = Realm()
        XCTAssertEqual(Realm.defaultPath, realm.path)
    }

//    func testReadOnly() {
//        var path: String!
//        autoreleasepool {
//            let realm = self.realmWithTestPath()
//            path = realm.path
//            realm.write {
//                _ = SwiftStringObject.createInRealm(realm, withObject: ["a"])
//            }
//        }
//
//        let readOnlyRealm = Realm(path: path, readOnly: true, error: nil)!
//        XCTAssertEqual(true, readOnlyRealm.readOnly)
//        XCTAssertEqual(1, Results(SwiftStringObject.self, inRealm: readOnlyRealm).count)
//    }

    func testSchema() {
        let schema = Realm().schema
        XCTAssert(schema as AnyObject is Schema)
        XCTAssertEqual(1, schema.objectSchema.filter({ $0.className == "SwiftStringObject" }).count)
    }

    func testAutorefresh() {
        let realm = realmWithTestPath()
        XCTAssertTrue(realm.autorefresh, "Autorefresh should default to true")
        realm.autorefresh = false
        XCTAssertFalse(realm.autorefresh)
        realm.autorefresh = true
        XCTAssertTrue(realm.autorefresh)
    }

    func testWriteCopyToPath() {
        let realm = Realm()
        realm.write {
            realm.add(SwiftObject())
        }
        let path = Realm.defaultPath.stringByDeletingLastPathComponent.stringByAppendingPathComponent("copy.realm")
        XCTAssertNil(realm.writeCopyToPath(path))
        autoreleasepool {
            let copy = Realm(path: path)
            XCTAssertEqual(1, Results(type: SwiftObject.self, realm: copy).count)
        }
        NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
    }

    func testAddSingleObject() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        realm.write {
            let obj = SwiftObject()
            realm.add(obj)
            XCTAssertEqual(1, Results(type: SwiftObject.self).count)
        }
        XCTAssertEqual(1, Results(type: SwiftObject.self).count)
    }

    func testAddMultipleObjects() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        realm.write {
            let objs = [SwiftObject(), SwiftObject()]
            realm.add(objs)
            XCTAssertEqual(2, Results(type: SwiftObject.self).count)
        }
        XCTAssertEqual(2, Results(type: SwiftObject.self).count)
    }

    func testAddOrUpdateSingleObject() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftPrimaryStringObject.self).count)
        realm.write {
            let obj = SwiftPrimaryStringObject()
            realm.addOrUpdate(obj)
            XCTAssertEqual(1, Results(type: SwiftPrimaryStringObject.self).count)
        }
        XCTAssertEqual(1, Results(type: SwiftPrimaryStringObject.self).count)
    }

    func testAddOrUpdateMultipleObjects() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftPrimaryStringObject.self).count)
        realm.write {
            let objs = [SwiftPrimaryStringObject(), SwiftPrimaryStringObject()]
            realm.addOrUpdate(objs)
            XCTAssertEqual(1, Results(type: SwiftPrimaryStringObject.self).count)
        }
        XCTAssertEqual(1, Results(type: SwiftPrimaryStringObject.self).count)
    }

    func testDeleteSingleObject() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        realm.write {
            let obj = SwiftObject()
            realm.add(obj)
            XCTAssertEqual(1, Results(type: SwiftObject.self).count)
            realm.delete(obj)
            XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        }
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
    }

    func testDeleteListOfObjects() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftCompanyObject.self).count)
        realm.write {
            let obj = SwiftCompanyObject()
            obj.employees.append(SwiftEmployeeObject())
            realm.add(obj)
            XCTAssertEqual(1, Results(type: SwiftEmployeeObject.self).count)
            realm.delete(obj.employees)
            XCTAssertEqual(0, Results(type: SwiftEmployeeObject.self).count)
        }
        XCTAssertEqual(0, Results(type: SwiftEmployeeObject.self).count)
    }

    func testDeleteSequenceOfObjects() {
        let realm = Realm()
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        realm.write {
            let objs = [SwiftObject(), SwiftObject()]
            realm.add(objs)
            XCTAssertEqual(2, Results(type: SwiftObject.self).count)
            realm.delete(objs)
            XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        }
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
    }

    func testDeleteAll() {
        let realm = Realm()
        realm.write {
            realm.add(SwiftObject())
            XCTAssertEqual(1, Results(type: SwiftObject.self).count)
            realm.deleteAll()
            XCTAssertEqual(0, Results(type: SwiftObject.self).count)
        }
        XCTAssertEqual(0, Results(type: SwiftObject.self).count)
    }

    func testAddNotificationBlock() {
        let realm = Realm()
        var notificationCalled = false
        let token = realm.addNotificationBlock { (notification, realm) -> Void in
            XCTAssertEqual(realm.path, Realm.defaultPath)
            notificationCalled = true
        }
        XCTAssertFalse(notificationCalled)
        realm.write {}
        XCTAssertTrue(notificationCalled)
    }

    func testRemoveNotification() {
        let realm = Realm()
        var notificationCalled = false
        let token = realm.addNotificationBlock { (notification, realm) -> Void in
            XCTAssertEqual(realm.path, Realm.defaultPath)
            notificationCalled = true
        }
        realm.removeNotification(token)
        realm.write {}
        XCTAssertFalse(notificationCalled)
    }
}
