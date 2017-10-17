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
import Foundation

private var dynamicDefaultSeed = 0
private func nextDynamicDefaultSeed() -> Int {
    dynamicDefaultSeed += 1
    return dynamicDefaultSeed
}
class DynamicDefaultObject: Object {
    @objc dynamic var intCol = nextDynamicDefaultSeed()
    @objc dynamic var floatCol = Float(nextDynamicDefaultSeed())
    @objc dynamic var doubleCol = Double(nextDynamicDefaultSeed())
    @objc dynamic var dateCol = Date(timeIntervalSinceReferenceDate: TimeInterval(nextDynamicDefaultSeed()))
    @objc dynamic var stringCol = UUID().uuidString
    @objc dynamic var binaryCol = UUID().uuidString.data(using: .utf8)

    override static func primaryKey() -> String? {
        return "intCol"
    }
}

class ObjectTests: TestCase {

    // init() Tests are in ObjectCreationTests.swift

    // init(value:) tests are in ObjectCreationTests.swift

    func testRealm() {
        let standalone = SwiftStringObject()
        XCTAssertNil(standalone.realm)

        let realm = try! Realm()
        var persisted: SwiftStringObject!
        try! realm.write {
            persisted = realm.create(SwiftStringObject.self, value: [:])
            XCTAssertNotNil(persisted.realm)
            XCTAssertEqual(realm, persisted.realm!)
        }
        XCTAssertNotNil(persisted.realm)
        XCTAssertEqual(realm, persisted.realm!)

        dispatchSyncNewThread {
            autoreleasepool {
                XCTAssertNotEqual(try! Realm(), persisted.realm!)
            }
        }
    }

    func testObjectSchema() {
        let object = SwiftObject()
        let schema = object.objectSchema
        XCTAssert(schema as AnyObject is ObjectSchema)
        XCTAssert(schema.properties as AnyObject is [Property])
        XCTAssertEqual(schema.className, "SwiftObject")
        XCTAssertEqual(schema.properties.map { $0.name },
            ["boolCol", "intCol", "floatCol", "doubleCol", "stringCol", "binaryCol", "dateCol", "objectCol",
             "realmIntCol", "arrayCol"]
        )
    }

    func testObjectSchemaForObjectWithConvenienceInitializer() {
        let object = SwiftConvenienceInitializerObject(stringCol: "abc")
        let schema = object.objectSchema
        XCTAssert(schema as AnyObject is ObjectSchema)
        XCTAssert(schema.properties as AnyObject is [Property])
        XCTAssertEqual(schema.className, "SwiftConvenienceInitializerObject")
        XCTAssertEqual(schema.properties.map { $0.name }, ["stringCol"])
    }

    func testSharedSchemaUnmanaged() {
        let object = SwiftObject()
        XCTAssertEqual(type(of: object).sharedSchema(), SwiftObject.sharedSchema())
    }

    func testSharedSchemaManaged() {
        let object = SwiftObject()
        XCTAssertEqual(type(of: object).sharedSchema(), SwiftObject.sharedSchema())
    }

    func testInvalidated() {
        let object = SwiftObject()
        XCTAssertFalse(object.isInvalidated)

        let realm = try! Realm()
        try! realm.write {
            realm.add(object)
            XCTAssertFalse(object.isInvalidated)
        }

        try! realm.write {
            realm.deleteAll()
            XCTAssertTrue(object.isInvalidated)
        }
        XCTAssertTrue(object.isInvalidated)
    }

    func testDescription() {
        let object = SwiftObject()
        // swiftlint:disable line_length
        let expected = "SwiftObject \\{\n\tboolCol = 0;\n\tintCol = 123;\n\tfloatCol = 1\\.23;\n\tdoubleCol = 12\\.3;\n\tstringCol = a;\n\tbinaryCol = <61 — 1 total bytes>;\n\tdateCol = 1970-01-01 00:00:01 \\+0000;\n\tobjectCol = SwiftBoolObject \\{\n\t\tboolCol = 0;\n\t\\};\n\trealmIntCol = RLMInteger \\(value: 0\\);\n\tarrayCol = List<SwiftBoolObject> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\\}"
        assertMatches(object.description, expected)

        let recursiveObject = SwiftRecursiveObject()
        recursiveObject.objects.append(recursiveObject)
        assertMatches(recursiveObject.description, "SwiftRecursiveObject \\{\n\tobjects = List<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\tobjects = List<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\t\t\tobjects = <Maximum depth exceeded>;\n\t\t\t\t\\}\n\t\t\t\\);\n\t\t\\}\n\t\\);\n\\}")
        // swiftlint:enable line_length
    }

    func testSchemaHasPrimaryKey() {
        XCTAssertNil(Object.primaryKey(), "primary key should default to nil")
        XCTAssertNil(SwiftStringObject.primaryKey())
        XCTAssertNil(SwiftStringObject().objectSchema.primaryKeyProperty)
        XCTAssertEqual(SwiftPrimaryStringObject.primaryKey()!, "stringCol")
        XCTAssertEqual(SwiftPrimaryStringObject().objectSchema.primaryKeyProperty!.name, "stringCol")
    }

    func testCannotUpdatePrimaryKey() {
        let realm = self.realmWithTestPath()
        let primaryKeyReason = "Primary key can't be changed .*after an object is inserted."

        let intObj = SwiftPrimaryIntObject()
        intObj.intCol = 1
        intObj.intCol = 0; // can change primary key unattached
        XCTAssertEqual(0, intObj.intCol)

        let optionalIntObj = SwiftPrimaryOptionalIntObject()
        optionalIntObj.intCol.value = 1
        optionalIntObj.intCol.value = 0; // can change primary key unattached
        XCTAssertEqual(0, optionalIntObj.intCol.value)

        let stringObj = SwiftPrimaryStringObject()
        stringObj.stringCol = "a"
        stringObj.stringCol = "b" // can change primary key unattached
        XCTAssertEqual("b", stringObj.stringCol)

        try! realm.write {
            realm.add(intObj)
            assertThrows(intObj.intCol = 2, reasonMatching: primaryKeyReason)
            assertThrows(intObj["intCol"] = 2, reasonMatching: primaryKeyReason)
            assertThrows(intObj.setValue(2, forKey: "intCol"), reasonMatching: primaryKeyReason)

            realm.add(optionalIntObj)
            assertThrows(optionalIntObj.intCol.value = 2, reasonMatching: primaryKeyReason)
            assertThrows(optionalIntObj["intCol"] = 2, reasonMatching: primaryKeyReason)
            assertThrows(optionalIntObj.setValue(2, forKey: "intCol"), reasonMatching: primaryKeyReason)

            realm.add(stringObj)
            assertThrows(stringObj.stringCol = "c", reasonMatching: primaryKeyReason)
            assertThrows(stringObj["stringCol"] = "c", reasonMatching: primaryKeyReason)
            assertThrows(stringObj.setValue("c", forKey: "stringCol"), reasonMatching: primaryKeyReason)
        }
    }

    func testIgnoredProperties() {
        XCTAssertEqual(Object.ignoredProperties(), [], "ignored properties should default to []")
        XCTAssertEqual(SwiftIgnoredPropertiesObject.ignoredProperties().count, 2)
        XCTAssertNil(SwiftIgnoredPropertiesObject().objectSchema["runtimeProperty"])
    }

    func testIndexedProperties() {
        XCTAssertEqual(Object.indexedProperties(), [], "indexed properties should default to []")
        XCTAssertEqual(SwiftIndexedPropertiesObject.indexedProperties().count, 8)

        let objectSchema = SwiftIndexedPropertiesObject().objectSchema
        XCTAssertTrue(objectSchema["stringCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["intCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["int8Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int16Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int32Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int64Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["boolCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["dateCol"]!.isIndexed)

        XCTAssertFalse(objectSchema["floatCol"]!.isIndexed)
        XCTAssertFalse(objectSchema["doubleCol"]!.isIndexed)
        XCTAssertFalse(objectSchema["dataCol"]!.isIndexed)
    }

    func testIndexedOptionalProperties() {
        XCTAssertEqual(Object.indexedProperties(), [], "indexed properties should default to []")
        XCTAssertEqual(SwiftIndexedOptionalPropertiesObject.indexedProperties().count, 8)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalStringCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDateCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalBoolCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalIntCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt8Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt16Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt32Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt64Col"]!.isIndexed)

        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDataCol"]!.isIndexed)
        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalFloatCol"]!.isIndexed)
        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDoubleCol"]!.isIndexed)
    }

    func testDynamicDefaultPropertyValues() {
        func assertDifferentPropertyValues(_ obj1: DynamicDefaultObject, _ obj2: DynamicDefaultObject) {
            XCTAssertNotEqual(obj1.intCol, obj2.intCol)
            XCTAssertNotEqual(obj1.floatCol, obj2.floatCol)
            XCTAssertNotEqual(obj1.doubleCol, obj2.doubleCol)
            XCTAssertNotEqual(obj1.dateCol.timeIntervalSinceReferenceDate, obj2.dateCol.timeIntervalSinceReferenceDate,
                              accuracy: 0.01)
            XCTAssertNotEqual(obj1.stringCol, obj2.stringCol)
            XCTAssertNotEqual(obj1.binaryCol, obj2.binaryCol)
        }
        assertDifferentPropertyValues(DynamicDefaultObject(), DynamicDefaultObject())
        let realm = try! Realm()
        try! realm.write {
            assertDifferentPropertyValues(realm.create(DynamicDefaultObject.self),
                                          realm.create(DynamicDefaultObject.self))
        }
    }

    func testValueForKey() {
        let test: (SwiftObject) -> Void = { object in
            XCTAssertEqual(object.value(forKey: "boolCol") as! Bool!, false)
            XCTAssertEqual(object.value(forKey: "intCol") as! Int!, 123)
            XCTAssertEqual(object.value(forKey: "floatCol") as! Float!, 1.23 as Float)
            XCTAssertEqual(object.value(forKey: "doubleCol") as! Double!, 12.3)
            XCTAssertEqual(object.value(forKey: "stringCol") as! String!, "a")

            let expected = object.value(forKey: "binaryCol") as! Data
            let actual = "a".data(using: String.Encoding.utf8)!
            XCTAssertTrue(expected == actual)

            XCTAssertEqual(object.value(forKey: "dateCol") as! Date!, Date(timeIntervalSince1970: 1))
            XCTAssertEqual((object.value(forKey: "objectCol")! as! SwiftBoolObject).boolCol, false)
            XCTAssert(object.value(forKey: "arrayCol")! is List<SwiftBoolObject>)
        }

        test(SwiftObject())
        try! Realm().write {
            let persistedObject = try! Realm().create(SwiftObject.self, value: [:])
            test(persistedObject)
        }
    }

    func testSettingUnmanagedObjectValuesWithSwiftDictionary() {
        let json: [String: Any] = ["name": "foo", "array": [["stringCol": "bar"]], "intArray": [["intCol": 50]]]
        let object = SwiftArrayPropertyObject()
        json.keys.forEach { key in
            object.setValue(json[key], forKey: key)
        }
        XCTAssertEqual(object.name, "foo")
        XCTAssertEqual(object.array[0].stringCol, "bar")
        XCTAssertEqual(object.intArray[0].intCol, 50)
    }

    func testSettingUnmanagedObjectValuesWithBadSwiftDictionary() {
        let json: [String: Any] = ["name": "foo", "array": [["stringCol": NSObject()]], "intArray": [["intCol": 50]]]
        let object = SwiftArrayPropertyObject()
        assertThrows({ json.keys.forEach { key in object.setValue(json[key], forKey: key) } }())
    }

    func setAndTestAllTypes(_ setter: (SwiftObject, Any?, String) -> Void,
                            getter: (SwiftObject, String) -> (Any?), object: SwiftObject) {
        setter(object, true, "boolCol")
        XCTAssertEqual(getter(object, "boolCol") as! Bool!, true)

        setter(object, 321, "intCol")
        XCTAssertEqual(getter(object, "intCol") as! Int!, 321)

        setter(object, NSNumber(value: 32.1 as Float), "floatCol")
        XCTAssertEqual(getter(object, "floatCol") as! Float!, 32.1 as Float)

        setter(object, 3.21, "doubleCol")
        XCTAssertEqual(getter(object, "doubleCol") as! Double!, 3.21)

        setter(object, "z", "stringCol")
        XCTAssertEqual(getter(object, "stringCol") as! String!, "z")

        setter(object, "z".data(using: String.Encoding.utf8)! as Data, "binaryCol")
        let gotData = getter(object, "binaryCol") as! Data
        XCTAssertTrue(gotData == "z".data(using: String.Encoding.utf8)!)

        setter(object, Date(timeIntervalSince1970: 333), "dateCol")
        XCTAssertEqual(getter(object, "dateCol") as! Date!, Date(timeIntervalSince1970: 333))

        let boolObject = SwiftBoolObject(value: [true])
        setter(object, boolObject, "objectCol")
        assertEqual(getter(object, "objectCol") as? SwiftBoolObject, boolObject)
        XCTAssertEqual((getter(object, "objectCol") as! SwiftBoolObject).boolCol, true)

        let list = List<SwiftBoolObject>()
        list.append(boolObject)
        setter(object, list, "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).count, 1)
        assertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).first!, boolObject)

        list.removeAll()
        setter(object, list, "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).count, 0)

        setter(object, [boolObject], "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).count, 1)
        assertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).first!, boolObject)

        setter(object, nil, "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).count, 0)

        setter(object, [boolObject], "arrayCol")
        setter(object, NSNull(), "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<SwiftBoolObject>).count, 0)
    }

    func dynamicSetAndTestAllTypes(_ setter: (DynamicObject, Any?, String) -> Void,
                                   getter: (DynamicObject, String) -> (Any?), object: DynamicObject,
                                   boolObject: DynamicObject) {
        setter(object, true, "boolCol")
        XCTAssertEqual((getter(object, "boolCol") as! Bool), true)

        setter(object, 321, "intCol")
        XCTAssertEqual((getter(object, "intCol") as! Int), 321)

        setter(object, NSNumber(value: 32.1 as Float), "floatCol")
        XCTAssertEqual((getter(object, "floatCol") as! Float), 32.1 as Float)

        setter(object, 3.21, "doubleCol")
        XCTAssertEqual((getter(object, "doubleCol") as! Double), 3.21)

        setter(object, "z", "stringCol")
        XCTAssertEqual((getter(object, "stringCol") as! String), "z")

        setter(object, "z".data(using: String.Encoding.utf8)! as Data, "binaryCol")
        let gotData = getter(object, "binaryCol") as! Data
        XCTAssertTrue(gotData == "z".data(using: String.Encoding.utf8)!)

        setter(object, Date(timeIntervalSince1970: 333), "dateCol")
        XCTAssertEqual((getter(object, "dateCol") as! Date), Date(timeIntervalSince1970: 333))

        setter(object, boolObject, "objectCol")
        assertEqual((getter(object, "objectCol") as! DynamicObject), boolObject)
        XCTAssertEqual(((getter(object, "objectCol") as! DynamicObject)["boolCol"] as! Bool), true)

        setter(object, [boolObject], "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<DynamicObject>).count, 1)
        assertEqual((getter(object, "arrayCol") as! List<DynamicObject>).first!, boolObject)

        let list = getter(object, "arrayCol") as! List<DynamicObject>
        list.removeAll()
        setter(object, list, "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<DynamicObject>).count, 0)

        setter(object, [boolObject], "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<DynamicObject>).count, 1)
        assertEqual((getter(object, "arrayCol") as! List<DynamicObject>).first!, boolObject)

        setter(object, nil, "arrayCol")
        XCTAssertEqual((getter(object, "arrayCol") as! List<DynamicObject>).count, 0)
    }

    // Yields a read-write migration `SwiftObject` to the given block
    private func withMigrationObject(block: @escaping ((MigrationObject, Migration) -> Void)) {
        autoreleasepool {
            let realm = self.realmWithTestPath()
            try! realm.write {
                _ = realm.create(SwiftObject.self)
            }
        }
        autoreleasepool {
            var enumerated = false
            let configuration = Realm.Configuration(schemaVersion: 1, migrationBlock: { migration, _ in
                migration.enumerateObjects(ofType: SwiftObject.className()) { _, newObject in
                    if let newObject = newObject {
                        block(newObject, migration)
                        enumerated = true
                    }
                }
            })
            self.realmWithTestPath(configuration: configuration)
            XCTAssert(enumerated)
        }
    }

    func testSetValueForKey() {
        let setter: (Object, Any?, String) -> Void = { object, value, key in
            object.setValue(value, forKey: key)
            return
        }
        let getter: (Object, String) -> (Any?) = { object, key in
            object.value(forKey: key)
        }

        withMigrationObject { migrationObject, migration in
            let boolObject = migration.create("SwiftBoolObject", value: [true])
            self.dynamicSetAndTestAllTypes(setter, getter: getter, object: migrationObject, boolObject: boolObject)
        }

        setAndTestAllTypes(setter, getter: getter, object: SwiftObject())
        try! Realm().write {
            let persistedObject = try! Realm().create(SwiftObject.self, value: [:])
            self.setAndTestAllTypes(setter, getter: getter, object: persistedObject)
        }
    }

    func testSubscript() {
        let setter: (Object, Any?, String) -> Void = { object, value, key in
            object[key] = value
            return
        }
        let getter: (Object, String) -> (Any?) = { object, key in
            object[key]
        }

        withMigrationObject { migrationObject, migration in
            let boolObject = migration.create("SwiftBoolObject", value: [true])
            self.dynamicSetAndTestAllTypes(setter, getter: getter, object: migrationObject, boolObject: boolObject)
        }

        setAndTestAllTypes(setter, getter: getter, object: SwiftObject())
        try! Realm().write {
            let persistedObject = try! Realm().create(SwiftObject.self, value: [:])
            self.setAndTestAllTypes(setter, getter: getter, object: persistedObject)
        }
    }

    func testDynamicList() {
        let realm = try! Realm()
        let arrayObject = SwiftArrayPropertyObject()
        let str1 = SwiftStringObject()
        let str2 = SwiftStringObject()
        arrayObject.array.append(objectsIn: [str1, str2])
        try! realm.write {
            realm.add(arrayObject)
        }
        let dynamicArray = arrayObject.dynamicList("array")
        XCTAssertEqual(dynamicArray.count, 2)
        assertEqual(dynamicArray[0], str1)
        assertEqual(dynamicArray[1], str2)
        XCTAssertEqual(arrayObject.dynamicList("intArray").count, 0)
        assertThrows(arrayObject.dynamicList("noSuchList"))
    }

    func testObjectiveCTypeProperties() {
        let realm = try! Realm()
        var object: SwiftObjectiveCTypesObject!
        let now = NSDate()
        let data = "fizzbuzz".data(using: .utf8)! as Data as NSData
        try! realm.write {
            object = SwiftObjectiveCTypesObject()
            realm.add(object)
            object.stringCol = "Hello world!"
            object.dateCol = now
            object.dataCol = data
            object.numCol = 42
        }
        XCTAssertEqual("Hello world!", object.stringCol)
        XCTAssertEqual(now, object.dateCol)
        XCTAssertEqual(data, object.dataCol)
        XCTAssertEqual(42, object.numCol)
    }

    func testDeleteObservedObject() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftIntObject.self, value: [0])
        try! realm.commitWrite()

        let exp = expectation(description: "")
        let token = object.observe { change in
            if case .deleted = change {
            } else {
                XCTFail("expected .deleted, got \(change)")
            }
            exp.fulfill()
        }

        realm.beginWrite()
        realm.delete(object)
        try! realm.commitWrite()

        waitForExpectations(timeout: 2)
        token.invalidate()
    }

    func expectChange<T: Equatable, U: Equatable>(_ name: String, _ old: T?, _ new: U?) -> ((ObjectChange) -> Void) {
        // FIXME: Tests using this occasionally fail.
        let exp = expectation(description: "")
        return { change in
            if case .change(let properties) = change {
                XCTAssertEqual(properties.count, 1)
                if let prop = properties.first {
                    XCTAssertEqual(prop.name, name)
                    XCTAssertEqual(prop.oldValue as? T, old)
                    XCTAssertEqual(prop.newValue as? U, new)
                }
            } else {
                XCTFail("expected .change, got \(change)")
            }
            exp.fulfill()
        }
    }

    func testModifyObservedObjectLocally() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftIntObject.self, value: [1])
        try! realm.commitWrite()

        let token = object.observe(expectChange("intCol", Int?.none, 2))
        try! realm.write {
            object.intCol = 2
        }

        waitForExpectations(timeout: 2)
        token.invalidate()
    }

    func testModifyObservedObjectRemotely() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftIntObject.self, value: [1])
        try! realm.commitWrite()

        let token = object.observe(expectChange("intCol", 1, 2))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftIntObject.self).first!.intCol = 2
            }
        }

        waitForExpectations(timeout: 2)
        token.invalidate()
    }

    func testListPropertyNotifications() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftRecursiveObject.self, value: [[]])
        try! realm.commitWrite()

        let token = object.observe(expectChange("objects", Int?.none, Int?.none))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                let obj = realm.objects(SwiftRecursiveObject.self).first!
                obj.objects.append(obj)
            }
        }

        waitForExpectations(timeout: 2)
        token.invalidate()
    }

    func testOptionalPropertyNotifications() {
        let realm = try! Realm()
        let object = SwiftOptionalDefaultValuesObject()
        try! realm.write {
            realm.add(object)
        }

        var token = object.observe(expectChange("optIntCol", 1, 2))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 2
            }
        }
        waitForExpectations(timeout: 2)
        token.invalidate()

        token = object.observe(expectChange("optIntCol", 2, Int?.none))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = nil
            }
        }
        waitForExpectations(timeout: 2)
        token.invalidate()

        token = object.observe(expectChange("optIntCol", Int?.none, 3))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 3
            }
        }
        waitForExpectations(timeout: 2)
        token.invalidate()
    }

    func testEqualityForObjectTypeWithPrimaryKey() {
        let realm = try! Realm()
        let pk = "123456"

        let testObject = SwiftPrimaryStringObject()
        testObject.stringCol = pk
        testObject.intCol = 12345

        let unmanaged = SwiftPrimaryStringObject()
        unmanaged.stringCol = pk
        unmanaged.intCol = 12345

        let otherObject = SwiftPrimaryStringObject()
        otherObject.stringCol = "not" + pk
        otherObject.intCol = 12345

        try! realm.write {
            realm.add([testObject, otherObject])
        }

        // Should not match an object that's not equal.
        XCTAssertNotEqual(testObject, otherObject)

        // Should not match an object whose fields are equal if it's not the same row in the database.
        XCTAssertNotEqual(testObject, unmanaged)

        // Should match an object that represents the same row.
        let retrievedObject = realm.object(ofType: SwiftPrimaryStringObject.self, forPrimaryKey: pk)!
        XCTAssertEqual(testObject, retrievedObject)
        XCTAssertEqual(testObject.hash, retrievedObject.hash)
        XCTAssertTrue(testObject.isSameObject(as: retrievedObject))
    }

    func testEqualityForObjectTypeWithoutPrimaryKey() {
        let realm = try! Realm()
        let pk = "123456"
        XCTAssertNil(SwiftStringObject.primaryKey())

        let testObject = SwiftStringObject()
        testObject.stringCol = pk

        let alias = testObject

        try! realm.write {
            realm.add(testObject)
        }

        XCTAssertEqual(testObject, alias)

        // Should not match an object even if it represents the same row.
        let retrievedObject = realm.objects(SwiftStringObject.self).first!
        XCTAssertNotEqual(testObject, retrievedObject)

        // Should be able to use `isSameObject(as:)` to check if same row in the database.
        XCTAssertTrue(testObject.isSameObject(as: retrievedObject))
    }
}

class RealmIntegerTests: TestCase {

    func testBasicFunctionality() {
        let realm = try! Realm()

        let obj = SwiftRealmIntObject()
        XCTAssertEqual(obj.realmInt.value, 0)

        // Set the value of an unmanaged RealmInteger
        obj.realmInt.value = 100
        XCTAssertEqual(obj.realmInt.value, 100)

        // Add an object with an int property to a Realm
        try! realm.write {
            realm.add(obj)
        }
        XCTAssertEqual(obj.realmInt.value, 100)

        // Increment the int
        try! realm.write {
            obj.realmInt.incrementValue(by: 8901)
        }
        XCTAssertEqual(obj.realmInt.value, 9001)

        // Set the int
        try! realm.write {
            obj.realmInt.value = 123
        }
        XCTAssertEqual(obj.realmInt.value, 123)

        // Assign to the int
        try! realm.write {
            obj.realmInt = RealmInteger(value: 100)
        }
        XCTAssertEqual(obj.realmInt.value, 100)
    }

    func testBasicOptionalFunctionality() {
        let realm = try! Realm()

        let obj = SwiftNullableRealmIntObject()
        XCTAssertEqual(obj.nullableRealmInt?.value, 0)

        // Set the value of an unmanaged RealmInteger
        obj.nullableRealmInt?.value = 100
        XCTAssertEqual(obj.nullableRealmInt?.value, 100)

        // Add an object with an int property to a Realm
        try! realm.write {
            realm.add(obj)
        }
        XCTAssertEqual(obj.nullableRealmInt?.value, 100)

        // Increment the int
        try! realm.write {
            obj.nullableRealmInt!.incrementValue(by: 8901)
        }
        XCTAssertEqual(obj.nullableRealmInt?.value, 9001)

        // Set the int to nil
        try! realm.write {
            obj.nullableRealmInt!.value = nil
        }
        XCTAssertNil(obj.nullableRealmInt?.value)

        // Set the int to a real value
        try! realm.write {
            obj.nullableRealmInt!.value = 123
        }
        XCTAssertEqual(obj.nullableRealmInt?.value, 123)

        // Assign to the int
        try! realm.write {
            obj.nullableRealmInt = RealmInteger(value: 102)
        }
        XCTAssertEqual(obj.nullableRealmInt?.value, 102)

        // Assign nil to the int
        try! realm.write {
            obj.nullableRealmInt = nil
        }
        XCTAssertNil(obj.nullableRealmInt?.value)

        // Assign a non-nil value to a nil'ed out int
        try! realm.write {
            obj.nullableRealmInt = RealmInteger(value: 104)
        }
        XCTAssertEqual(obj.nullableRealmInt?.value, 104)
    }
}
