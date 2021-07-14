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
import Realm
import RealmSwift
import Foundation

private var dynamicDefaultSeed = 0
private func nextDynamicDefaultSeed() -> Int {
    dynamicDefaultSeed += 1
    return dynamicDefaultSeed
}
class SwiftDynamicDefaultObject: Object {
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

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
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
                       ["boolCol", "intCol", "int8Col", "int16Col", "int32Col", "int64Col", "intEnumCol", "floatCol", "doubleCol",
                        "stringCol", "binaryCol", "dateCol", "decimalCol",
                        "objectIdCol", "objectCol", "uuidCol", "anyCol", "arrayCol", "setCol", "mapCol"]
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

    func testBaseClassesDoNotHaveSharedSchema() {
        XCTAssertNil(ObjectBase.sharedSchema())
        XCTAssertNil(Object.sharedSchema())
        XCTAssertNil(EmbeddedObject.sharedSchema())
        XCTAssertNil(RLMObject.sharedSchema())
        XCTAssertNil(RLMEmbeddedObject.sharedSchema())
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

    func testInvalidatedWithCustomObjectClasses() {
        var config = Realm.Configuration.defaultConfiguration
        config.objectTypes = [SwiftObject.self, SwiftBoolObject.self]
        let realm = try! Realm(configuration: config)

        let object = SwiftObject()
        XCTAssertFalse(object.isInvalidated)

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
        assertMatches(object.description, "SwiftObject \\{\n\tboolCol = 0;\n\tintCol = 123;\n\tint8Col = 123;\n\tint16Col = 123;\n\tint32Col = 123;\n\tint64Col = 123;\n\tintEnumCol = 1;\n\tfloatCol = 1\\.23;\n\tdoubleCol = 12\\.3;\n\tstringCol = a;\n\tbinaryCol = <.*61.*>;\n\tdateCol = 1970-01-01 00:00:01 \\+0000;\n\tdecimalCol = 1.23E6;\n\tobjectIdCol = 1234567890ab1234567890ab;\n\tobjectCol = SwiftBoolObject \\{\n\t\tboolCol = 0;\n\t\\};\n\tuuidCol = 137DECC8-B300-4954-A233-F89909F4FD89;\n\tanyCol = \\(null\\);\n\tarrayCol = List<SwiftBoolObject> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\tsetCol = MutableSet<SwiftBoolObject> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\tmapCol = Map<string, SwiftBoolObject> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\\}")

        let recursiveObject = SwiftRecursiveObject()
        recursiveObject.objects.append(recursiveObject)
        recursiveObject.objectSet.insert(recursiveObject)
        assertMatches(recursiveObject.description, "SwiftRecursiveObject \\{\n\tobjects = List<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\tobjects = List<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\t\t\tobjects = <Maximum depth exceeded>;\n\t\t\t\t\tobjectSet = <Maximum depth exceeded>;\n\t\t\t\t\\}\n\t\t\t\\);\n\t\t\tobjectSet = MutableSet<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\t\t\tobjects = <Maximum depth exceeded>;\n\t\t\t\t\tobjectSet = <Maximum depth exceeded>;\n\t\t\t\t\\}\n\t\t\t\\);\n\t\t\\}\n\t\\);\n\tobjectSet = MutableSet<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\tobjects = List<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\t\t\tobjects = <Maximum depth exceeded>;\n\t\t\t\t\tobjectSet = <Maximum depth exceeded>;\n\t\t\t\t\\}\n\t\t\t\\);\n\t\t\tobjectSet = MutableSet<SwiftRecursiveObject> <0x[0-9a-f]+> \\(\n\t\t\t\t\\[0\\] SwiftRecursiveObject \\{\n\t\t\t\t\tobjects = <Maximum depth exceeded>;\n\t\t\t\t\tobjectSet = <Maximum depth exceeded>;\n\t\t\t\t\\}\n\t\t\t\\);\n\t\t\\}\n\t\\);\n\\}")

        let renamedObject = LinkToSwiftRenamedProperties1()
        renamedObject.linkA = SwiftRenamedProperties1()
        assertMatches(renamedObject.description, "LinkToSwiftRenamedProperties1 \\{\n\tlinkA = SwiftRenamedProperties1 \\{\n\t\tpropA = 0;\n\t\tpropB = ;\n\t\\};\n\tlinkB = \\(null\\);\n\tarray1 = List<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\tset1 = MutableSet<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\\}")
        assertMatches(renamedObject.linkA!.linking1.description, "LinkingObjects<LinkToSwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\n\\)")

        let realm = try! Realm()
        try! realm.write { realm.add(renamedObject) }
        assertMatches(renamedObject.description, "LinkToSwiftRenamedProperties1 \\{\n\tlinkA = SwiftRenamedProperties1 \\{\n\t\tpropA = 0;\n\t\tpropB = ;\n\t\\};\n\tlinkB = \\(null\\);\n\tarray1 = List<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\tset1 = MutableSet<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\n\t\\);\n\\}")
        assertMatches(renamedObject.linkA!.linking1.description, "LinkingObjects<LinkToSwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\\[0\\] LinkToSwiftRenamedProperties1 \\{\n\t\tlinkA = SwiftRenamedProperties1 \\{\n\t\t\tpropA = 0;\n\t\t\tpropB = ;\n\t\t\\};\n\t\tlinkB = \\(null\\);\n\t\tarray1 = List<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\t\n\t\t\\);\n\t\tset1 = MutableSet<SwiftRenamedProperties1> <0x[0-9a-f]+> \\(\n\t\t\n\t\t\\);\n\t\\}\n\\)")
        // swiftlint:enable line_length
    }

    func testSchemaHasPrimaryKey() {
        XCTAssertNil(Object.primaryKey(), "primary key should default to nil")
        XCTAssertNil(SwiftStringObject.primaryKey())
        XCTAssertNil(SwiftStringObject().objectSchema.primaryKeyProperty)
        XCTAssertEqual(SwiftPrimaryStringObject.primaryKey()!, "stringCol")
        XCTAssertEqual(SwiftPrimaryStringObject().objectSchema.primaryKeyProperty!.name, "stringCol")
        XCTAssertEqual(SwiftPrimaryUUIDObject().objectSchema.primaryKeyProperty!.name, "uuidCol")
        XCTAssertEqual(SwiftPrimaryObjectIdObject().objectSchema.primaryKeyProperty!.name, "objectIdCol")
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

        let uuidObj = SwiftPrimaryUUIDObject()
        uuidObj.uuidCol = UUID(uuidString: "8a12daba-8b23-11eb-8dcd-0242ac130003")!
        uuidObj.uuidCol = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
        XCTAssertEqual(UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!, uuidObj.uuidCol)

        let objectIdObj = SwiftPrimaryObjectIdObject()
        objectIdObj.objectIdCol = ObjectId("1234567890ab1234567890aa")
        objectIdObj.objectIdCol = ObjectId("1234567890ab1234567890ab")
        XCTAssertEqual(ObjectId("1234567890ab1234567890ab"), objectIdObj.objectIdCol)

        try! realm.write {
            realm.add(intObj)
            assertThrows(intObj.intCol = 2, reasonMatching: primaryKeyReason)
            assertThrows(intObj["intCol"] = 2, reasonMatching: primaryKeyReason)
            assertThrows(intObj.setValue(2, forKey: "intCol"), reasonMatching: primaryKeyReason)

            realm.add(optionalIntObj)
            assertThrows(optionalIntObj.intCol.value = 2, reasonMatching: "Cannot modify primary key")
            assertThrows(optionalIntObj["intCol"] = 2, reasonMatching: primaryKeyReason)
            assertThrows(optionalIntObj.setValue(2, forKey: "intCol"), reasonMatching: "Cannot modify primary key")

            realm.add(stringObj)
            assertThrows(stringObj.stringCol = "c", reasonMatching: primaryKeyReason)
            assertThrows(stringObj["stringCol"] = "c", reasonMatching: primaryKeyReason)
            assertThrows(stringObj.setValue("c", forKey: "stringCol"), reasonMatching: primaryKeyReason)

            realm.add(uuidObj)
            assertThrows(uuidObj.uuidCol = UUID(uuidString: "4ee1fa48-8b23-11eb-8dcd-0242ac130003")!, reasonMatching: primaryKeyReason)
            assertThrows(uuidObj["uuidCol"] = UUID(uuidString: "4ee1fa48-8b23-11eb-8dcd-0242ac130003")!, reasonMatching: primaryKeyReason)
            assertThrows(uuidObj.setValue(UUID(uuidString: "4ee1fa48-8b23-11eb-8dcd-0242ac130003")!, forKey: "uuidCol"), reasonMatching: primaryKeyReason)

            realm.add(objectIdObj)
            assertThrows(objectIdObj.objectIdCol = ObjectId("1234567890ab1234567890ac"), reasonMatching: primaryKeyReason)
            assertThrows(objectIdObj["objectIdCol"] = ObjectId("1234567890ab1234567890ac"), reasonMatching: primaryKeyReason)
            assertThrows(objectIdObj.setValue(ObjectId("1234567890ab1234567890ac"), forKey: "objectIdCol"), reasonMatching: primaryKeyReason)
        }
    }

    func testIgnoredProperties() {
        XCTAssertEqual(Object.ignoredProperties(), [], "ignored properties should default to []")
        XCTAssertEqual(SwiftIgnoredPropertiesObject.ignoredProperties().count, 2)
        XCTAssertNil(SwiftIgnoredPropertiesObject().objectSchema["runtimeProperty"])
    }

    func testIndexedProperties() {
        XCTAssertEqual(Object.indexedProperties(), [], "indexed properties should default to []")
        XCTAssertEqual(SwiftIndexedPropertiesObject.indexedProperties().count, 10)

        let objectSchema = SwiftIndexedPropertiesObject().objectSchema
        XCTAssertTrue(objectSchema["stringCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["intCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["int8Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int16Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int32Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["int64Col"]!.isIndexed)
        XCTAssertTrue(objectSchema["boolCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["dateCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["uuidCol"]!.isIndexed)
        XCTAssertTrue(objectSchema["anyCol"]!.isIndexed)

        XCTAssertFalse(objectSchema["floatCol"]!.isIndexed)
        XCTAssertFalse(objectSchema["doubleCol"]!.isIndexed)
        XCTAssertFalse(objectSchema["dataCol"]!.isIndexed)
    }

    func testIndexedOptionalProperties() {
        XCTAssertEqual(Object.indexedProperties(), [], "indexed properties should default to []")
        XCTAssertEqual(SwiftIndexedOptionalPropertiesObject.indexedProperties().count, 9)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalStringCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDateCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalBoolCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalIntCol"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt8Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt16Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt32Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalInt64Col"]!.isIndexed)
        XCTAssertTrue(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalUUIDCol"]!.isIndexed)

        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDataCol"]!.isIndexed)
        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalFloatCol"]!.isIndexed)
        XCTAssertFalse(SwiftIndexedOptionalPropertiesObject().objectSchema["optionalDoubleCol"]!.isIndexed)
    }

    func testDynamicDefaultPropertyValues() {
        func assertDifferentPropertyValues(_ obj1: SwiftDynamicDefaultObject, _ obj2: SwiftDynamicDefaultObject) {
            XCTAssertNotEqual(obj1.intCol, obj2.intCol)
            XCTAssertNotEqual(obj1.floatCol, obj2.floatCol)
            XCTAssertNotEqual(obj1.doubleCol, obj2.doubleCol)
            XCTAssertNotEqual(obj1.dateCol.timeIntervalSinceReferenceDate, obj2.dateCol.timeIntervalSinceReferenceDate,
                              accuracy: 0.01)
            XCTAssertNotEqual(obj1.stringCol, obj2.stringCol)
            XCTAssertNotEqual(obj1.binaryCol, obj2.binaryCol)
        }
        assertDifferentPropertyValues(SwiftDynamicDefaultObject(), SwiftDynamicDefaultObject())
        let realm = try! Realm()
        try! realm.write {
            assertDifferentPropertyValues(realm.create(SwiftDynamicDefaultObject.self),
                                          realm.create(SwiftDynamicDefaultObject.self))
        }
    }

    func testValueForKey() {
        let test: (SwiftObject) -> Void = { object in
            XCTAssertEqual(object.value(forKey: "boolCol") as! Bool?, false)
            XCTAssertEqual(object.value(forKey: "intCol") as! Int?, 123)
            XCTAssertEqual(object.value(forKey: "int8Col") as! Int8?, 123)
            XCTAssertEqual(object.value(forKey: "int16Col") as! Int16?, 123)
            XCTAssertEqual(object.value(forKey: "int32Col") as! Int32?, 123)
            XCTAssertEqual(object.value(forKey: "int64Col") as! Int64?, 123)
            XCTAssertEqual(object.value(forKey: "floatCol") as! Float?, 1.23 as Float)
            XCTAssertEqual(object.value(forKey: "doubleCol") as! Double?, 12.3)
            XCTAssertEqual(object.value(forKey: "stringCol") as! String?, "a")
            XCTAssertEqual(object.value(forKey: "uuidCol") as! UUID?, UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!)
            XCTAssertNil(object.value(forKey: "anyCol"))

            let expected = object.value(forKey: "binaryCol") as! Data
            let actual = "a".data(using: String.Encoding.utf8)!
            XCTAssertEqual(expected, actual)

            XCTAssertEqual(object.value(forKey: "dateCol") as! Date?, Date(timeIntervalSince1970: 1))
            XCTAssertEqual((object.value(forKey: "objectCol")! as! SwiftBoolObject).boolCol, false)
            XCTAssert(object.value(forKey: "arrayCol")! is List<SwiftBoolObject>)
            XCTAssert(object.value(forKey: "setCol")! is MutableSet<SwiftBoolObject>)
        }

        test(SwiftObject())
        let realm = try! Realm()
        try! realm.write {
            test(realm.create(SwiftObject.self, value: [:]))
            let addedObj = SwiftObject()
            realm.add(addedObj)
            test(addedObj)
        }
    }

    func testValueForKeyOptionals() {
        let test: (SwiftOptionalObject) -> Void = { object in
            XCTAssertNil(object.value(forKey: "optNSStringCol"))
            XCTAssertNil(object.value(forKey: "optStringCol"))
            XCTAssertNil(object.value(forKey: "optBinaryCol"))
            XCTAssertNil(object.value(forKey: "optDateCol"))
            XCTAssertNil(object.value(forKey: "optIntCol"))
            XCTAssertNil(object.value(forKey: "optInt8Col"))
            XCTAssertNil(object.value(forKey: "optInt16Col"))
            XCTAssertNil(object.value(forKey: "optInt32Col"))
            XCTAssertNil(object.value(forKey: "optInt64Col"))
            XCTAssertNil(object.value(forKey: "optFloatCol"))
            XCTAssertNil(object.value(forKey: "optDoubleCol"))
            XCTAssertNil(object.value(forKey: "optBoolCol"))
            XCTAssertNil(object.value(forKey: "optEnumCol"))
            XCTAssertNil(object.value(forKey: "optUuidCol"))
        }

        test(SwiftOptionalObject())
        let realm = try! Realm()
        try! realm.write {
            test(realm.create(SwiftOptionalObject.self, value: [:]))
            let addedObj = SwiftOptionalObject()
            realm.add(addedObj)
            test(addedObj)
        }
    }

    func testValueForKeyList() {
        let test: (SwiftListObject) -> Void = { object in
            XCTAssertNil((object.value(forKey: "int") as! List<Int>).first)
            XCTAssertNil((object.value(forKey: "int8") as! List<Int8>).first)
            XCTAssertNil((object.value(forKey: "int16") as! List<Int16>).first)
            XCTAssertNil((object.value(forKey: "int32") as! List<Int32>).first)
            XCTAssertNil((object.value(forKey: "int64") as! List<Int64>).first)
            XCTAssertNil((object.value(forKey: "float") as! List<Float>).first)
            XCTAssertNil((object.value(forKey: "double") as! List<Double>).first)
            XCTAssertNil((object.value(forKey: "string") as! List<String>).first)
            XCTAssertNil((object.value(forKey: "data") as! List<Data>).first)
            XCTAssertNil((object.value(forKey: "date") as! List<Date>).first)
            XCTAssertNil((object.value(forKey: "decimal") as! List<Decimal128>).first)
            XCTAssertNil((object.value(forKey: "objectId") as! List<ObjectId>).first)
            XCTAssertNil((object.value(forKey: "uuid") as! List<UUID>).first)
            XCTAssertNil((object.value(forKey: "any") as! List<AnyRealmValue>).first)

            // The `as Any?` casts below are only to silence the warning about it
            // happening implicitly and are not functionally required
            XCTAssertNil((object.value(forKey: "intOpt") as! List<Int?>).first as Any?)
            XCTAssertNil((object.value(forKey: "int8Opt") as! List<Int8?>).first as Any?)
            XCTAssertNil((object.value(forKey: "int16Opt") as! List<Int16?>).first as Any?)
            XCTAssertNil((object.value(forKey: "int32Opt") as! List<Int32?>).first as Any?)
            XCTAssertNil((object.value(forKey: "int64Opt") as! List<Int64?>).first as Any?)
            XCTAssertNil((object.value(forKey: "floatOpt") as! List<Float?>).first as Any?)
            XCTAssertNil((object.value(forKey: "doubleOpt") as! List<Double?>).first as Any?)
            XCTAssertNil((object.value(forKey: "stringOpt") as! List<String?>).first as Any?)
            XCTAssertNil((object.value(forKey: "dataOpt") as! List<Data?>).first as Any?)
            XCTAssertNil((object.value(forKey: "dateOpt") as! List<Date?>).first as Any?)
            XCTAssertNil((object.value(forKey: "decimalOpt") as! List<Decimal128?>).first as Any?)
            XCTAssertNil((object.value(forKey: "objectIdOpt") as! List<ObjectId?>).first as Any?)
            XCTAssertNil((object.value(forKey: "uuidOpt") as! List<UUID?>).first as Any?)
        }

        test(SwiftListObject())
        let realm = try! Realm()
        try! realm.write {
            test(realm.create(SwiftListObject.self, value: [:]))
            let addedObj = SwiftListObject()
            realm.add(addedObj)
            test(addedObj)
        }
    }

    func testValueForKeyMutableSet() {
        let test: (SwiftMutableSetObject) -> Void = { object in
            XCTAssertEqual((object.value(forKey: "int") as! MutableSet<Int>).count, 0)
            XCTAssertEqual((object.value(forKey: "int8") as! MutableSet<Int8>).count, 0)
            XCTAssertEqual((object.value(forKey: "int16") as! MutableSet<Int16>).count, 0)
            XCTAssertEqual((object.value(forKey: "int32") as! MutableSet<Int32>).count, 0)
            XCTAssertEqual((object.value(forKey: "int64") as! MutableSet<Int64>).count, 0)
            XCTAssertEqual((object.value(forKey: "float") as! MutableSet<Float>).count, 0)
            XCTAssertEqual((object.value(forKey: "double") as! MutableSet<Double>).count, 0)
            XCTAssertEqual((object.value(forKey: "string") as! MutableSet<String>).count, 0)
            XCTAssertEqual((object.value(forKey: "data") as! MutableSet<Data>).count, 0)
            XCTAssertEqual((object.value(forKey: "date") as! MutableSet<Date>).count, 0)
            XCTAssertEqual((object.value(forKey: "decimal") as! MutableSet<Decimal128>).count, 0)
            XCTAssertEqual((object.value(forKey: "objectId") as! MutableSet<ObjectId>).count, 0)
            XCTAssertEqual((object.value(forKey: "uuid") as! MutableSet<UUID>).count, 0)
            XCTAssertEqual((object.value(forKey: "any") as! MutableSet<AnyRealmValue>).count, 0)

            XCTAssertEqual((object.value(forKey: "intOpt") as! MutableSet<Int?>).count, 0)
            XCTAssertEqual((object.value(forKey: "int8Opt") as! MutableSet<Int8?>).count, 0)
            XCTAssertEqual((object.value(forKey: "int16Opt") as! MutableSet<Int16?>).count, 0)
            XCTAssertEqual((object.value(forKey: "int32Opt") as! MutableSet<Int32?>).count, 0)
            XCTAssertEqual((object.value(forKey: "int64Opt") as! MutableSet<Int64?>).count, 0)
            XCTAssertEqual((object.value(forKey: "floatOpt") as! MutableSet<Float?>).count, 0)
            XCTAssertEqual((object.value(forKey: "doubleOpt") as! MutableSet<Double?>).count, 0)
            XCTAssertEqual((object.value(forKey: "stringOpt") as! MutableSet<String?>).count, 0)
            XCTAssertEqual((object.value(forKey: "dataOpt") as! MutableSet<Data?>).count, 0)
            XCTAssertEqual((object.value(forKey: "dateOpt") as! MutableSet<Date?>).count, 0)
            XCTAssertEqual((object.value(forKey: "decimalOpt") as! MutableSet<Decimal128?>).count, 0)
            XCTAssertEqual((object.value(forKey: "objectIdOpt") as! MutableSet<ObjectId?>).count, 0)
            XCTAssertEqual((object.value(forKey: "uuidOpt") as! MutableSet<UUID?>).count, 0)
        }

        test(SwiftMutableSetObject())
        let realm = try! Realm()
        try! realm.write {
            test(realm.create(SwiftMutableSetObject.self, value: [:]))
            let addedObj = SwiftMutableSetObject()
            realm.add(addedObj)
            test(addedObj)
        }
    }

    func testValueForKeyLinkingObjects() {
        let test: (SwiftDogObject) -> Void = { object in
            let owners = object.value(forKey: "owners") as! LinkingObjects<SwiftOwnerObject>
            if object.realm != nil {
                XCTAssertEqual(owners.first!.name, "owner name")
            }
        }

        let dog = SwiftDogObject()
        let owner = SwiftOwnerObject(value: ["owner name", dog])
        test(dog)
        let realm = try! Realm()
        try! realm.write {
            test(realm.create(SwiftOwnerObject.self, value: owner).dog!)
            realm.add(owner)
            test(dog)
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

        let json2: [String: Any] = ["name": "foo", "set": [["stringCol": "bar"]], "intSet": [["intCol": 50]]]
        let object2 = SwiftMutableSetPropertyObject()
        json2.keys.forEach { key in
            object2.setValue(json2[key], forKey: key)
        }
        XCTAssertEqual(object2.name, "foo")
        XCTAssertEqual(object2.set[0].stringCol, "bar")
        XCTAssertEqual(object2.intSet[0].intCol, 50)
    }

    func testSettingUnmanagedObjectValuesWithBadSwiftDictionary() {
        let json: [String: Any] = ["name": "foo", "array": [["stringCol": NSObject()]], "intArray": [["intCol": 50]]]
        let object = SwiftArrayPropertyObject()
        assertThrows({ json.keys.forEach { key in object.setValue(json[key], forKey: key) } }())

        let json2: [String: Any] = ["name": "foo", "set": [["stringCol": NSObject()]], "intSet": [["intCol": 50]]]
        let object2 = SwiftMutableSetPropertyObject()
        assertThrows({ json2.keys.forEach { key in object2.setValue(json2[key], forKey: key) } }())
    }

    func setAndTestAllTypes(_ setter: (SwiftObject, Any?, String) -> Void,
                            getter: (SwiftObject, String) -> (Any?), object: SwiftObject) {
        setter(object, true, "boolCol")
        XCTAssertEqual(getter(object, "boolCol") as! Bool?, true)

        setter(object, 321, "intCol")
        XCTAssertEqual(getter(object, "intCol") as! Int?, 321)

        setter(object, Int8(1), "int8Col")
        XCTAssertEqual(getter(object, "int8Col") as! Int8?, 1)

        setter(object, Int16(321), "int16Col")
        XCTAssertEqual(getter(object, "int16Col") as! Int16?, 321)

        setter(object, Int32(321), "int32Col")
        XCTAssertEqual(getter(object, "int32Col") as! Int32?, 321)

        setter(object, Int64(321), "int64Col")
        XCTAssertEqual(getter(object, "int64Col") as! Int64?, 321)

        setter(object, NSNumber(value: 32.1 as Float), "floatCol")
        XCTAssertEqual(getter(object, "floatCol") as! Float?, 32.1 as Float)

        setter(object, 3.21, "doubleCol")
        XCTAssertEqual(getter(object, "doubleCol") as! Double?, 3.21)

        setter(object, "z", "stringCol")
        XCTAssertEqual(getter(object, "stringCol") as! String?, "z")

        setter(object, "z".data(using: String.Encoding.utf8)! as Data, "binaryCol")
        let gotData = getter(object, "binaryCol") as! Data
        XCTAssertTrue(gotData == "z".data(using: String.Encoding.utf8)!)

        setter(object, Date(timeIntervalSince1970: 333), "dateCol")
        XCTAssertEqual(getter(object, "dateCol") as! Date?, Date(timeIntervalSince1970: 333))

        setter(object, UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD89"), "uuidCol")
        XCTAssertEqual(getter(object, "uuidCol") as! UUID?, UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD89"))

        setter(object, "hello", "anyCol")
        XCTAssertEqual(getter(object, "anyCol") as! String, "hello")

        let boolObject = SwiftBoolObject(value: [true])

        setter(object, boolObject, "anyCol")
        assertEqual(getter(object, "anyCol") as? SwiftBoolObject, boolObject)
        XCTAssertEqual((getter(object, "anyCol") as! SwiftBoolObject).boolCol, true)

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

        let set = MutableSet<SwiftBoolObject>()
        set.insert(boolObject)
        setter(object, set, "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>).count, 1)
        assertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>)[0], boolObject)

        set.removeAll()
        setter(object, set, "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>).count, 0)

        setter(object, [boolObject], "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>).count, 1)
        assertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>)[0], boolObject)

        setter(object, nil, "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>).count, 0)

        setter(object, [boolObject], "setCol")
        setter(object, NSNull(), "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<SwiftBoolObject>).count, 0)
    }

    func dynamicSetAndTestAllTypes(_ setter: (DynamicObject, Any?, String) -> Void,
                                   getter: (DynamicObject, String) -> (Any?), object: DynamicObject,
                                   boolObject: DynamicObject) {
        setter(object, true, "boolCol")
        XCTAssertEqual((getter(object, "boolCol") as! Bool), true)

        setter(object, 321, "intCol")
        XCTAssertEqual((getter(object, "intCol") as! Int), 321)

        setter(object, Int8(1), "int8Col")
        XCTAssertEqual(getter(object, "int8Col") as! Int8?, 1)

        setter(object, Int16(321), "int16Col")
        XCTAssertEqual(getter(object, "int16Col") as! Int16?, 321)

        setter(object, Int32(321), "int32Col")
        XCTAssertEqual(getter(object, "int32Col") as! Int32?, 321)

        setter(object, Int64(321), "int64Col")
        XCTAssertEqual(getter(object, "int64Col") as! Int64?, 321)

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

        setter(object, UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD89"), "uuidCol")
        XCTAssertEqual(getter(object, "uuidCol") as! UUID?, UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD89"))

        setter(object, "hello", "anyCol")
        XCTAssertEqual((getter(object, "anyCol") as! String), "hello")

        setter(object, boolObject, "anyCol")
        assertEqual((getter(object, "anyCol") as! DynamicObject), boolObject)
        XCTAssertEqual(((getter(object, "anyCol") as! DynamicObject)["boolCol"] as! Bool), true)
        XCTAssertEqual(((getter(object, "anyCol") as! DynamicObject).boolCol as! Bool), true)

        setter(object, boolObject, "objectCol")
        assertEqual((getter(object, "objectCol") as! DynamicObject), boolObject)
        XCTAssertEqual(((getter(object, "objectCol") as! DynamicObject)["boolCol"] as! Bool), true)
        XCTAssertEqual(((getter(object, "objectCol") as! DynamicObject).boolCol as! Bool), true)

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

        setter(object, [boolObject], "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>).count, 1)
        assertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>)[0], boolObject)

        let set = getter(object, "setCol") as! MutableSet<DynamicObject>
        set.removeAll()
        setter(object, set, "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>).count, 0)

        setter(object, [boolObject], "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>).count, 1)
        assertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>)[0], boolObject)

        setter(object, nil, "setCol")
        XCTAssertEqual((getter(object, "setCol") as! MutableSet<DynamicObject>).count, 0)
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
        }
        let getter: (Object, String) -> Any? = { object, key in
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

    func testDynamicMemberSubscript() {
        withMigrationObject { migrationObject, migration in
            let boolObject = migration.create("SwiftBoolObject", value: [true])
            migrationObject.anyCol = boolObject
            self.assertEqual(migrationObject.anyCol as? DynamicObject, boolObject)
            migrationObject.objectCol = boolObject
            self.assertEqual(migrationObject.objectCol as? DynamicObject, boolObject)
            migrationObject.anyCol = 12345
            XCTAssertEqual(migrationObject.anyCol as! Int, 12345)
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

    func testDynamicMutableSet() {
        let realm = try! Realm()
        let setObject = SwiftMutableSetPropertyObject()
        let str1 = SwiftStringObject()
        let str2 = SwiftStringObject()
        setObject.set.insert(objectsIn: [str1, str2])
        try! realm.write {
            realm.add(setObject)
        }
        let dynamicSet = setObject.dynamicMutableSet("set")
        XCTAssertEqual(dynamicSet.count, 2)

        XCTAssertTrue(dynamicSet.map { (o) in
            o.isSameObject(as: str1)
        }.contains(true))
        XCTAssertTrue(dynamicSet.map { (o) in
            o.isSameObject(as: str2)
        }.contains(true))

        XCTAssertEqual(setObject.dynamicMutableSet("intSet").count, 0)
        assertThrows(setObject.dynamicMutableSet("noSuchSet"))
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
        }
        XCTAssertEqual("Hello world!", object.stringCol)
        XCTAssertEqual(now, object.dateCol)
        XCTAssertEqual(data, object.dataCol)
    }

    // MARK: - Observation tests

    func testObserveUnmanagedObject() {
        assertThrows(SwiftIntObject().observe { _ in }, reason: "managed")
        assertThrows(SwiftIntObject().observe(keyPaths: ["intCol"]) { _ in }, reason: "managed")
    }

    func testDeleteObservedObject() {
        let realm = try! Realm()
        realm.beginWrite()
        let object0 = realm.create(SwiftIntObject.self, value: [0])
        let object1 = realm.create(SwiftIntObject.self, value: [0])
        try! realm.commitWrite()

        let exp0 = expectation(description: "Delete observed object")
        let token0 = object0.observe { change in
            if case .deleted = change {
            } else {
                XCTFail("expected .deleted, got \(change)")
            }
            exp0.fulfill()
        }

        let exp1 = expectation(description: "Delete observed object")
        let token1 = object1.observe(keyPaths: ["intCol"]) { change in
            if case .deleted = change {
            } else {
                XCTFail("expected .deleted, got \(change)")
            }
            exp1.fulfill()
        }

        realm.beginWrite()
        realm.delete(object0)
        realm.delete(object1)
        try! realm.commitWrite()

        waitForExpectations(timeout: 1)
        token0.invalidate()
        token1.invalidate()
    }

    func testObserveInvalidKeyPath () {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftObject.self)
        try! realm.commitWrite()
        assertThrows(object.observe(keyPaths: ["notAProperty"], { _ in }), reason: "Property 'notAProperty' not found in object of type 'SwiftObject'")
        assertThrows(object.observe(keyPaths: ["arrayCol.alsoNotAProperty"], { _ in }), reason: "Property 'alsoNotAProperty' not found in object of type 'SwiftBoolObject'")

    }

    func checkChange<T: Equatable, U: Equatable>(_ name: String, _ old: T?, _ new: U?, _ change: ObjectChange<ObjectBase>) {
        if case .change(_, let properties) = change {
            XCTAssertEqual(properties.count, 1)
            if let prop = properties.first {
                XCTAssertEqual(prop.name, name)
                XCTAssertEqual(prop.oldValue as? T, old)
                XCTAssertEqual(prop.newValue as? U, new)
            }
        } else {
            XCTFail("expected .change, got \(change)")
        }
    }

    func expectChange<T: Equatable, U: Equatable>(_ name: String, _ old: T?, _ new: U?, _ inverted: Bool = false) -> ((ObjectChange<ObjectBase>) -> Void) {
        let exp = expectation(description: "change from \(String(describing: old)) to \(String(describing: new))")
        exp.isInverted = inverted
        return { change in
            self.checkChange(name, old, new, change)
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

    // !!!: Fails, but the feature will not support this behavior at first.
    // See version below
//    func testModifyObservedKeyPathLocally() {
//        let realm = try! Realm()
//        realm.beginWrite()
//        let object = realm.create(SwiftObject.self)
//        try! realm.commitWrite()
//
//        // Expect notification for "intCol" keyPath when "intCol" is modified
//        let token1 = object.observe(keyPaths: ["intCol"], expectChange("intCol", Int?.none, 2))
//
//        // Expect no notification for "boolCol" keypath when "intCol" is modified
//        let token0 = object.observe(keyPaths: ["boolCol"], { change in
//            XCTFail("expected no change, got \(change)")
//        })
//
//        try! realm.write {
//            object.intCol = 2
//        }
//
//        waitForExpectations(timeout: 2)
//        token0.invalidate()
//        token1.invalidate()
//    }

    func testModifyObservedKeyPathLocally() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = SwiftObject()
        realm.add(object)
        try! realm.commitWrite()

        // Expect notification for "intCol" keyPath when "intCol" is modified
        let token = object.observe(keyPaths: ["intCol"], expectChange("intCol", Int?.none, 2))
        try! realm.write {
            object.intCol = 2
        }
        waitForExpectations(timeout: 0.1)
        token.invalidate()
    }

    func testModifyUnobservedKeyPathLocally() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = SwiftObject()
        realm.add(object)
        try! realm.commitWrite()

        // Expect no notification for "boolCol" keypath when "intCol" is modified
        let ex = expectation(description: "no change")
        ex.isInverted = true
        let token = object.observe(keyPaths: ["boolCol"], { _ in
            ex.fulfill()
        })
        try! realm.write {
            object.intCol = 3
        }
        waitForExpectations(timeout: 0.1, handler: nil)
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

        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()
    }

    func testModifyObservedKeyPathRemotely() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = SwiftObject()
        realm.add(object)
        try! realm.commitWrite()

        // Expect notification for "intCol" keyPath when "intCol" is modified
        let token = object.observe(keyPaths: ["intCol"], expectChange("intCol", 123, 2))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftObject.self).first!.intCol = 2
            }
        }
        realm.refresh()
        waitForExpectations(timeout: 0.1)
        token.invalidate()


    }

    func testModifyUnobservedKeyPathRemotely() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = SwiftObject()
        realm.add(object)
        try! realm.commitWrite()

        // Expect no notification for "boolCol" keypath when "intCol" is modified
        let ex = expectation(description: "no change")
        ex.isInverted = true
        let token = object.observe(keyPaths: ["boolCol"], { _ in
            ex.fulfill()
        })

        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                let first = realm.objects(SwiftObject.self).first!
                first.intCol += 1
            }
        }
        realm.refresh()
        waitForExpectations(timeout: 0.1, handler: nil)
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

    // How could these expectations be broken down into their own tests?
    // Naming was getting out of hand.
    func testListPropertyKeyPathNotifications() {
        let realm = try! Realm()
        realm.beginWrite()
        let employee = realm.create(SwiftEmployeeObject.self)
        let company = realm.create(SwiftCompanyObject.self)
        company.employees.append(employee)
        try! realm.commitWrite()

        // Expect no notification for "employees" when "employee.hired" is changed
        var ex = expectation(description: "no change notification")
        ex.isInverted = true
        var token = company.observe(keyPaths: ["employees"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            employee.hired = true
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect a notification for "employees.hired" when "employee.hired" is changed
        token = company.observe(keyPaths: ["employees.hired"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            XCTAssertTrue(employee.hired)
            employee.hired = false
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect no notification for "employees.hired" when "employee.age" is changed.
        ex = expectation(description: "no change notification")
        ex.isInverted = true
        token = company.observe(keyPaths: ["employees.hired"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            employee.age = 35
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect notification for "employees.hired" when an employee is deleted.
        token = company.observe(keyPaths: ["employees.hired"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            realm.delete(employee)
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect notification for "employees.hired" when an employee is added.
        token = company.observe(keyPaths: ["employees.hired"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            let employee2 = realm.create(SwiftEmployeeObject.self)
            company.employees.append(employee2)
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
        
        // Expect notification for "employees.hired" when an employee is reassigned.
        token = company.observe(keyPaths: ["employees.hired"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            let employee3 = realm.create(SwiftEmployeeObject.self)
            company.employees[0] = employee3
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect notification for "employees" when an employee is added.
        token = company.observe(keyPaths: ["employees"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            let employee4 = realm.create(SwiftEmployeeObject.self)
            company.employees.append(employee4)
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect notification for "employees" when an employee is reassigned.
        token = company.observe(keyPaths: ["employees"], expectChange("employees", Int?.none, Int?.none))
        try! realm.write({
            let employee5 = realm.create(SwiftEmployeeObject.self)
            company.employees[0] = employee5
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()

        // Expect no notification for "employees" when "company.name" is changed
        ex = expectation(description: "no change notification")
        ex.isInverted = true
        token = company.observe(keyPaths: ["employees"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            company.name = "changed"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testLinkPropertyKeyPathNotifications1() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect notification for "dog.dogName" when "dog.dogName" is changed
        let token = person.observe(keyPaths: ["dog.dogName"], expectChange("dog", Int?.none, Int?.none))
        try! realm.write({
            dog.dogName = "rex"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testLinkPropertyKeyPathNotifications2() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect notification for "dog.dogName" when "dog" is reassigned.
        let token = person.observe(keyPaths: ["dog.dogName"], expectChange("dog", Int?.none, Int?.none))
        try! realm.write({
            let newDog = SwiftDogObject()
            person.dog = newDog
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testLinkPropertyKeyPathNotifications3() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect no notification for "dog" when "person.name" is changed
        let ex = expectation(description: "no change notification")
        ex.isInverted = true
        let token = person.observe(keyPaths: ["dog"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            person.name = "Teddy"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testLinkPropertyKeyPathNotifications4() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect no notification for "dog" when "dog.dogName" is changed
        let ex = expectation(description: "no change notification")
        ex.isInverted = true
        let token = person.observe(keyPaths: ["dog"], {_ in
            ex.fulfill()
        })
        try! realm.write({
            dog.dogName = "fido"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testBacklinkPropertyKeyPathNotifications1() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect no notification for "owners" when "dog.dogName" is changed
        let ex = expectation(description: "no change notification")
        ex.isInverted = true
        let token = dog.observe(keyPaths: ["owners"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            dog.dogName = "fido"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testBacklinkPropertyKeyPathNotifications2() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect no notification for "owners" when "owner.name" is changed
        let ex = expectation(description: "no change notification")
        ex.isInverted = true
        let token = dog.observe(keyPaths: ["owners"], { _ in
            ex.fulfill()
        })
        try! realm.write({
            let owner = dog.owners.first!
            owner.name = "Tom"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testBacklinkPropertyKeyPathNotifications3() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect notification for "owners.name" when "owner.name" is changed
        let token = dog.observe(keyPaths: ["owners.name"], expectChange("owners", String?.none, String?.none))
        try! realm.write({
            let owner = dog.owners.first!
            owner.name = "Abe"
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testBacklinkPropertyKeyPathNotifications4() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect notification for "owners" when a new owner is added.
        let token = dog.observe(keyPaths: ["owners"], expectChange("owners", Int?.none, Int?.none))
        try! realm.write({
            let newPerson = SwiftOwnerObject()
            realm.add(newPerson)
            newPerson.dog = dog
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
    }

    func testBacklinkPropertyKeyPathNotifications5() {
        let realm = try! Realm()
        realm.beginWrite()
        let person = realm.create(SwiftOwnerObject.self)
        let dog = realm.create(SwiftDogObject.self)
        person.dog = dog
        try! realm.commitWrite()

        // Expect notification for "owners.name" when a new owner is added.
        let token = dog.observe(keyPaths: ["owners.name"], expectChange("owners", Int?.none, Int?.none))
        try! realm.write({
            let newPerson = SwiftOwnerObject()
            realm.add(newPerson)
            newPerson.dog = dog
        })
        waitForExpectations(timeout: 0.1, handler: nil)
        token.invalidate()
}

    func testMutableSetPropertyNotifications() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftRecursiveObject.self, value: [[]])
        try! realm.commitWrite()

        let token = object.observe(expectChange("objectSet", Int?.none, Int?.none))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                let obj = realm.objects(SwiftRecursiveObject.self).first!
                obj.objectSet.insert(obj)
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
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()

        token = object.observe(expectChange("optIntCol", 2, Int?.none))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = nil
            }
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()

        token = object.observe(expectChange("optIntCol", Int?.none, 3))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write {
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 3
            }
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()
    }

    func testOptionalPropertyKeyPathNotifications() {
        let realm = try! Realm()
        let object = SwiftOptionalDefaultValuesObject()
        try! realm.write({
            realm.add(object)
        })

        // Expect notification for change on observed path
        var token = object.observe(keyPaths: ["optIntCol"], expectChange("optIntCol", 1, 2))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write({
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 2
            })
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()

        // Expect no notification for change outside of observed path
        token = object.observe(keyPaths: ["optStringCol"], expectChange("optIntCol", 2, 3, true)) // Passing true inverts expectation
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write({
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 3
            })
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()

        // Expect notification for change from value to nil on observed path
        token = object.observe(keyPaths: ["optIntCol"], expectChange("optIntCol", 3, Int?.none))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write({
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = nil
            })
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()

        // Expect notification for change from nil to value on observed path
        token = object.observe(keyPaths: ["optIntCol"], expectChange("optIntCol", Int?.none, 2))
        dispatchSyncNewThread {
            let realm = try! Realm()
            try! realm.write({
                realm.objects(SwiftOptionalDefaultValuesObject.self).first!.optIntCol.value = 2
            })
        }
        realm.refresh()
        waitForExpectations(timeout: 0)
        token.invalidate()
    }

    func testObserveOnDifferentQueue() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftIntObject.self, value: [1])
        try! realm.commitWrite()

        let queue = DispatchQueue(label: "label")
        let sema = DispatchSemaphore(value: 0)
        let token = object.observe(on: queue) { change in
            self.checkChange("intCol", 1, 2, change)
            sema.signal()
        }
        // wait for the notification to be registered as otherwise it may not
        // have the old value
        queue.sync { }
        try! realm.write {
            object.intCol = 2
        }

        sema.wait()
        token.invalidate()
        queue.sync { }
    }

    func testObserveKeyPathOnDifferentQueue() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftObject.self)
        object.intCol = 1
        try! realm.commitWrite()

        let queue = DispatchQueue(label: "label")
        let sema = DispatchSemaphore(value: 0)
        let token = object.observe(keyPaths: ["intCol"], on: queue) { change in
            self.checkChange("intCol", 1, 2, change)
            sema.signal()
        }

        // wait for the notification to be registered as otherwise it may not
        // have the old value
        queue.sync { }
        try! realm.write {
            object.intCol = 2
        }

        sema.wait()
        token.invalidate()
        queue.sync { }
    }

    func testInvalidateObserverOnDifferentQueueBeforeRegistration() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftIntObject.self, value: [1])
        try! realm.commitWrite()

        let queue = DispatchQueue(label: "label")
        let sema = DispatchSemaphore(value: 0)

        // Block the queue for now
        queue.async { sema.wait() }

        // Add two observers, invalidating one
        let token1 = object.observe(on: queue) { _ in
            XCTFail("notification should not have fired")
        }
        let token2 = object.observe(on: queue) { _ in
            sema.signal()
        }
        token1.invalidate()

        // Now let token2 registration happen
        sema.signal()
        queue.sync { }

        // Perform a write and make sure only token2 notifies
        try! realm.write {
            object.intCol = 2
        }
        sema.wait()
        token2.invalidate()
        queue.sync { }
    }

    // MARK: Equality Tests

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

    func testEqualityForFrozenObjectTypeWithoutPrimaryKey() {
        let realm = try! Realm()
        let testObject = try! realm.write {
            realm.create(SwiftStringObject.self)
        }

        let frozen = testObject.freeze()
        let retrievedObject = realm.objects(SwiftStringObject.self).first!.freeze()
        XCTAssertEqual(frozen, retrievedObject)
    }

    func testRetrievingObjectWithRuntimeType() {
        let realm = try! Realm()

        let unmanagedStringObject = SwiftPrimaryStringObject()
        unmanagedStringObject.stringCol = UUID().uuidString
        let managedStringObject = SwiftPrimaryStringObject()
        managedStringObject.stringCol = UUID().uuidString

        // Add the object.
        try! realm.write {
            realm.add(managedStringObject)
        }

        // Shouldn't throw when using type(of:).
        XCTAssertNotNil(realm.object(ofType: type(of: unmanagedStringObject),
                                     forPrimaryKey: managedStringObject.stringCol))

        // Shouldn't throw when using type(of:).
        XCTAssertNotNil(realm.object(ofType: type(of: managedStringObject),
                                     forPrimaryKey: managedStringObject.stringCol))
    }

    func testRetrievingObjectsWithRuntimeType() {
        let realm = try! Realm()

        let unmanagedStringObject = SwiftStringObject()
        unmanagedStringObject.stringCol = "foo"
        let managedStringObject = SwiftStringObject()
        managedStringObject.stringCol = "bar"

        // Add the object.
        try! realm.write {
            realm.add(managedStringObject)
        }

        // Shouldn't throw when using type(of:).
        XCTAssertEqual(realm.objects(type(of: unmanagedStringObject)).count, 1)

        // Shouldn't throw when using type(of:).
        XCTAssertEqual(realm.objects(type(of: managedStringObject)).count, 1)
    }

    // MARK: Frozen Objects Tests

    func testIsFrozen() {
        let obj = SwiftStringObject()
        XCTAssertFalse(obj.isFrozen)

        let realm = try! Realm()
        try! realm.write { realm.add(obj) }
        XCTAssertFalse(obj.isFrozen)

        let frozen = obj.freeze()
        XCTAssertFalse(obj.isFrozen)
        XCTAssertTrue(frozen.isFrozen)
    }

    func testFreezeUnmanaged() {
        assertThrows(SwiftStringObject().freeze(), reason: "Unmanaged objects cannot be frozen.")
    }

    func testFreezeDynamicObject() {
        let realm = try! Realm()
        try! realm.write {
            realm.create(SwiftObject.self, value: ["arrayCol": [[true]], "setCol": [[true]]])
        }
        let obj = realm.dynamicObjects("SwiftObject").first!.freeze()
        XCTAssertTrue(obj.isFrozen)
        XCTAssertTrue(obj.dynamicList("arrayCol").isFrozen)
        XCTAssertTrue(obj.dynamicList("arrayCol").first!.isFrozen)
        XCTAssertTrue(obj.dynamicMutableSet("setCol").isFrozen)
        XCTAssertTrue(obj.dynamicMutableSet("setCol").first!.isFrozen)
    }

    func testFreezeAllPropertyTypes() {
        let realm = try! Realm()
        let (obj, optObj, listObj) = try! realm.write {
            return (
                realm.create(SwiftObject.self, value: [
                    "boolCol": true,
                    "intCol": 456,
                    "floatCol": 4.56 as Float,
                    "doubleCol": 45.6,
                    "stringCol": "b",
                    "binaryCol": "b".data(using: String.Encoding.utf8)!,
                    "dateCol": Date(timeIntervalSince1970: 2),
                    "objectCol": [true],
                    "uuidCol": UUID(),
                    "anyCol": "hello"
                ]),
                realm.create(SwiftOptionalObject.self, value: [
                    "optNSStringCol": "NSString",
                    "optStringCol": "String",
                    "optBinaryCol": Data(),
                    "optDateCol": Date(),
                    "optIntCol": 1,
                    "optInt8Col": 2,
                    "optInt16Col": 3,
                    "optInt32Col": 4,
                    "optInt64Col": 5,
                    "optFloatCol": 6.1,
                    "optDoubleCol": 7.2,
                    "optBoolCol": true
                ]),
                realm.create(SwiftListObject.self, value: [
                    "int": [1],
                    "int8": [2],
                    "int16": [3],
                    "int32": [4],
                    "int64": [5],
                    "float": [6.6 as Float],
                    "double": [7.7],
                    "string": ["8"],
                    "data": ["9".data(using: String.Encoding.utf8)!],
                    "date": [Date(timeIntervalSince1970: 10)],
                    "intOpt": [11, nil],
                    "int8Opt": [12, nil],
                    "int16Opt": [13, nil],
                    "int32Opt": [14, nil],
                    "int64Opt": [15, nil],
                    "floatOpt": [16.16, nil],
                    "doubleOpt": [17.17, nil],
                    "stringOpt": ["18", nil],
                    "dataOpt": ["19".data(using: String.Encoding.utf8)!, nil],
                    "dateOpt": [Date(timeIntervalSince1970: 20), nil],
                    "uuid": [UUID()],
                    "uuidOpt": [UUID(), nil],
                    "any": ["hello", nil]
                ])
            )
        }

        let frozenObj = obj.freeze()
        XCTAssertEqual(obj.boolCol, frozenObj.boolCol)
        XCTAssertEqual(obj.intCol, frozenObj.intCol)
        XCTAssertEqual(obj.floatCol, frozenObj.floatCol)
        XCTAssertEqual(obj.doubleCol, frozenObj.doubleCol)
        XCTAssertEqual(obj.stringCol, frozenObj.stringCol)
        XCTAssertEqual(obj.binaryCol, frozenObj.binaryCol)
        XCTAssertEqual(obj.dateCol, frozenObj.dateCol)
        XCTAssertEqual(obj.objectCol?.boolCol, frozenObj.objectCol?.boolCol)
        XCTAssertEqual(obj.uuidCol, frozenObj.uuidCol)
        XCTAssertEqual(obj.anyCol.value, frozenObj.anyCol.value)

        let frozenOptObj = optObj.freeze()
        XCTAssertEqual(optObj.optNSStringCol, frozenOptObj.optNSStringCol)
        XCTAssertEqual(optObj.optStringCol, frozenOptObj.optStringCol)
        XCTAssertEqual(optObj.optBinaryCol, frozenOptObj.optBinaryCol)
        XCTAssertEqual(optObj.optDateCol, frozenOptObj.optDateCol)
        XCTAssertEqual(optObj.optIntCol.value, frozenOptObj.optIntCol.value)
        XCTAssertEqual(optObj.optInt8Col.value, frozenOptObj.optInt8Col.value)
        XCTAssertEqual(optObj.optInt16Col.value, frozenOptObj.optInt16Col.value)
        XCTAssertEqual(optObj.optInt32Col.value, frozenOptObj.optInt32Col.value)
        XCTAssertEqual(optObj.optInt64Col.value, frozenOptObj.optInt64Col.value)
        XCTAssertEqual(optObj.optFloatCol.value, frozenOptObj.optFloatCol.value)
        XCTAssertEqual(optObj.optDoubleCol.value, frozenOptObj.optDoubleCol.value)
        XCTAssertEqual(optObj.optBoolCol.value, frozenOptObj.optBoolCol.value)
        XCTAssertEqual(optObj.optEnumCol.value, frozenOptObj.optEnumCol.value)
        XCTAssertEqual(optObj.optUuidCol, frozenOptObj.optUuidCol)

        let frozenListObj = listObj.freeze()
        XCTAssertEqual(Array(listObj.int), Array(frozenListObj.int))
        XCTAssertEqual(Array(listObj.int8), Array(frozenListObj.int8))
        XCTAssertEqual(Array(listObj.int16), Array(frozenListObj.int16))
        XCTAssertEqual(Array(listObj.int32), Array(frozenListObj.int32))
        XCTAssertEqual(Array(listObj.int64), Array(frozenListObj.int64))
        XCTAssertEqual(Array(listObj.float), Array(frozenListObj.float))
        XCTAssertEqual(Array(listObj.double), Array(frozenListObj.double))
        XCTAssertEqual(Array(listObj.string), Array(frozenListObj.string))
        XCTAssertEqual(Array(listObj.data), Array(frozenListObj.data))
        XCTAssertEqual(Array(listObj.date), Array(frozenListObj.date))
        XCTAssertEqual(Array(listObj.intOpt), Array(frozenListObj.intOpt))
        XCTAssertEqual(Array(listObj.int8Opt), Array(frozenListObj.int8Opt))
        XCTAssertEqual(Array(listObj.int16Opt), Array(frozenListObj.int16Opt))
        XCTAssertEqual(Array(listObj.int32Opt), Array(frozenListObj.int32Opt))
        XCTAssertEqual(Array(listObj.int64Opt), Array(frozenListObj.int64Opt))
        XCTAssertEqual(Array(listObj.floatOpt), Array(frozenListObj.floatOpt))
        XCTAssertEqual(Array(listObj.doubleOpt), Array(frozenListObj.doubleOpt))
        XCTAssertEqual(Array(listObj.stringOpt), Array(frozenListObj.stringOpt))
        XCTAssertEqual(Array(listObj.dataOpt), Array(frozenListObj.dataOpt))
        XCTAssertEqual(Array(listObj.dateOpt), Array(frozenListObj.dateOpt))
        XCTAssertEqual(Array(listObj.uuid), Array(frozenListObj.uuid))
        XCTAssertEqual(Array(listObj.uuidOpt), Array(frozenListObj.uuidOpt))
        XCTAssertEqual(Array(listObj.any.map { $0 }), Array(frozenListObj.any.map { $0 }))
    }

    func testThaw() {
        let realm = try! Realm()
        let obj = try! realm.write {
            realm.create(SwiftBoolObject.self, value: ["boolCol": true])
        }

        let frozenObj = obj.freeze()
        XCTAssertTrue(frozenObj.isFrozen)
        assertThrows(try! frozenObj.realm!.write {}, reason: "Can't perform transactions on a frozen Realm")

        let liveObj = frozenObj.thaw()!
        XCTAssertFalse(liveObj.isFrozen)
        XCTAssertEqual(liveObj.boolCol, frozenObj.boolCol)

        try! liveObj.realm!.write({ liveObj.boolCol = false })
        XCTAssertNotEqual(liveObj.boolCol, frozenObj.boolCol)
    }

    func testThawUnmanaged() {
        assertThrows(SwiftBoolObject().thaw(), reason: "Unmanaged objects cannot be thawed.")
    }

    func testThawDeleted() {
        let realm = try! Realm()
        let obj = try! realm.write {
            realm.create(SwiftBoolObject.self, value: ["boolCol": true])
        }

        let frozen = obj.freeze()
        try! realm.write { realm.delete(obj) }
        XCTAssertNotNil(frozen)

        let thawed = frozen.thaw()
        XCTAssertNil(thawed, "Thaw should return nil when object was deleted")
    }

    func testThawPreviousVersion() {
        let realm = try! Realm()
        let obj = try! realm.write {
            realm.create(SwiftBoolObject.self, value: ["boolCol": true])
        }

        let frozen = obj.freeze()
        XCTAssertTrue(frozen.isFrozen)

        try! obj.realm!.write({ obj.boolCol = false })
        XCTAssert(frozen.boolCol, "Frozen objects shouldn't mutate")

        let thawed = frozen.thaw()!
        XCTAssertFalse(thawed.isFrozen)
        XCTAssertFalse(thawed.boolCol, "Thaw should reflect transactions since the original reference was frozen")
    }

    func testThawUpdatedOnDifferentThread() {
        let obj = try! Realm().write {
            try! Realm().create(SwiftBoolObject.self, value: ["boolCol": true])
        }
        let frozen = obj.freeze()
        let thawed = frozen.thaw()!
        let tsr = ThreadSafeReference(to: thawed)

        dispatchSyncNewThread {
            let resolved = try! Realm().resolve(tsr)!
            try! Realm().write({ resolved.boolCol = false })
        }

        XCTAssert(frozen.thaw()!.boolCol)
        XCTAssert(thawed.boolCol)
        try! Realm().refresh()
        XCTAssertFalse(frozen.thaw()!.boolCol)
        XCTAssertFalse(thawed.boolCol)
    }
}
