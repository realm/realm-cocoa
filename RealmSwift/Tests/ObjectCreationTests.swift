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
import Realm.Private

class ObjectWithPrivateOptionals: Object {
    private var nilInt: Int?
    private var nilFloat: Float?
    private var nilString: String?
    private var int: Int? = 123
    private var float: Float? = 1.23
    private var string: String? = "123"

    @objc dynamic var value = 5
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class ObjectCreationTests: TestCase {
    // MARK: - Init tests

    func testInitWithDefaults() {
        // test all properties are defaults
        let object = SwiftObject()
        XCTAssertNil(object.realm)

        // test defaults values
        verifySwiftObjectWithDictionaryLiteral(object, dictionary: SwiftObject.defaultValues(), boolObjectValue: false,
            boolObjectListValues: [])

        // test realm properties are nil for standalone
        XCTAssertNil(object.realm)
        XCTAssertNil(object.objectCol!.realm)
        XCTAssertNil(object.arrayCol.realm)
        XCTAssertNil(object.setCol.realm)
        XCTAssertNil(object.mapCol.realm)
    }

    func testInitWithOptionalWithoutDefaults() {
        let object = SwiftOptionalObject()
        for prop in object.objectSchema.properties {
            let value = object[prop.name]
            if let value = value as? RLMSwiftValueStorage {
                XCTAssertNil(RLMGetSwiftValueStorage(value))
            } else {
                XCTAssertNil(value)
            }
        }
    }

    func testInitWithOptionalDefaults() {
        let object = SwiftOptionalDefaultValuesObject()
        verifySwiftOptionalObjectWithDictionaryLiteral(object, dictionary:
            SwiftOptionalDefaultValuesObject.defaultValues(), boolObjectValue: true)
    }

    func testInitWithDictionary() {
        // dictionary with all values specified
        let baselineValues: [String: Any] =
           ["boolCol": true,
            "intCol": 1,
            "int8Col": 1 as Int8,
            "int16Col": 1 as Int16,
            "int32Col": 1 as Int32,
            "int64Col": 1 as Int64,
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "decimalCol": 3 as Decimal128,
            "objectIdCol": ObjectId.generate(),
            "objectCol": SwiftBoolObject(value: [true]),
            "uuidCol": UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!,
            "anyCol": "hello",
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "setCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "mapCol": ["trueVal": SwiftBoolObject(value: [true]), "falseVal": SwiftBoolObject(value: [false])]
           ]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with valid value and init
                var values = baselineValues
                values[props[propNum].name] = validValue
                let object = SwiftObject(value: values)
                verifySwiftObjectWithDictionaryLiteral(object, dictionary: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
            }
        }

        // test with invalid dictionary literals
        for propNum in 0..<props.count {
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with invalid value and init
                var values = baselineValues
                values[props[propNum].name] = invalidValue
                assertThrows(SwiftObject(value: values), "Invalid property value")
            }
        }
    }

    func testInitWithDefaultsAndDictionary() {
        // test with dictionary with mix of default and one specified value
        let object = SwiftObject(value: ["intCol": 200])
        let valueDict = defaultSwiftObjectValuesWithReplacements(["intCol": 200])
        verifySwiftObjectWithDictionaryLiteral(object, dictionary: valueDict, boolObjectValue: false,
            boolObjectListValues: [])
    }

    func testInitWithArray() {
        // array with all values specified
        let baselineValues: [Any] = [true, 1, Int8(1), Int16(1), Int32(1), Int64(1), IntEnum.value1.rawValue, 1.1 as Float,
                                     11.1, "b", "b".data(using: String.Encoding.utf8)!,
                                     Date(timeIntervalSince1970: 2), Decimal128(number: 123),
                                     ObjectId.generate(), ["boolCol": true],
                                     UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!,
                                     "anyCol", [[true], [false]], [[true], [false]],
                                     ["trueVal": ["boolCol": true], "falseVal": ["boolCol": false]]]
        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                var values = baselineValues
                values[propNum] = validValue
                let object = SwiftObject(value: values)
                verifySwiftObjectWithArrayLiteral(object, array: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
            }
        }

        // test with invalid dictionary literals
        for propNum in 0..<props.count {
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with invalid value and init
                var values = baselineValues
                values[propNum] = invalidValue
                assertThrows(SwiftObject(value: values), "Invalid property value")
            }
        }
    }

    func testInitWithKVCObject() {
        // test with kvc object
        let objectWithInt = SwiftObject(value: ["intCol": 200])
        let objectWithKVCObject = SwiftObject(value: objectWithInt)
        let valueDict = defaultSwiftObjectValuesWithReplacements(["intCol": 200])
        verifySwiftObjectWithDictionaryLiteral(objectWithKVCObject, dictionary: valueDict, boolObjectValue: false,
            boolObjectListValues: [])
    }

    func testGenericInit() {
        func createObject<T: Object>() -> T {
            return T()
        }
        let obj1: SwiftBoolObject = createObject()
        let obj2 = SwiftBoolObject()
        XCTAssertEqual(obj1.boolCol, obj2.boolCol,
            "object created via generic initializer should equal object created by calling initializer directly")
    }

    func testInitWithObjcName() {
        // Test that init doesn't crash going into non-swift init logic for renamed Swift classes.
        _ = SwiftObjcRenamedObject()
        _ = SwiftObjcArbitrarilyRenamedObject()
    }

    // MARK: - Creation tests

    func testCreateWithDefaults() {
        let realm = try! Realm()
        assertThrows(realm.create(SwiftObject.self), "Must be in write transaction")

        var object: SwiftObject!
        let objects = realm.objects(SwiftObject.self)
        XCTAssertEqual(0, objects.count)
        try! realm.write {
            // test create with all defaults
            object = realm.create(SwiftObject.self)
            return
        }
        verifySwiftObjectWithDictionaryLiteral(object, dictionary: SwiftObject.defaultValues(), boolObjectValue: false,
            boolObjectListValues: [])

        // test realm properties are populated correctly
        XCTAssertEqual(object.realm!, realm)
        XCTAssertEqual(object.objectCol!.realm!, realm)
        XCTAssertEqual(object.arrayCol.realm!, realm)
    }

    func testCreateWithOptionalWithoutDefaults() {
        let realm = try! Realm()
        try! realm.write {
            let object = realm.create(SwiftOptionalObject.self)
            for prop in object.objectSchema.properties {
                XCTAssertNil(object[prop.name])
            }
        }
    }

    func testCreateWithOptionalDefaults() {
        let realm = try! Realm()
        try! realm.write {
            let object = realm.create(SwiftOptionalDefaultValuesObject.self)
            self.verifySwiftOptionalObjectWithDictionaryLiteral(object,
                dictionary: SwiftOptionalDefaultValuesObject.defaultValues(), boolObjectValue: true)
        }
    }

    func testCreateWithOptionalIgnoredProperties() {
        let realm = try! Realm()
        try! realm.write {
            let object = realm.create(SwiftOptionalIgnoredPropertiesObject.self)
            let properties = object.objectSchema.properties
            XCTAssertEqual(properties.count, 1)
            XCTAssertEqual(properties[0].name, "id")
        }
    }

    func testCreateWithDictionary() {
        // dictionary with all values specified
        let baselineValues: [String: Any] = [
            "boolCol": true,
            "intCol": 1,
            "int8Col": 1 as Int8,
            "int16Col": 1 as Int16,
            "int32Col": 1 as Int32,
            "int64Col": 1 as Int64,
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "decimalCol": 3 as Decimal128,
            "objectIdCol": ObjectId.generate(),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "setCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "mapCol": ["trueVal": ["boolCol": true], "falseVal": ["boolCol": false]]
        ]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with valid value and init
                var values = baselineValues
                values[props[propNum].name] = validValue
                try! Realm().beginWrite()
                let object = try! Realm().create(SwiftObject.self, value: values)
                verifySwiftObjectWithDictionaryLiteral(object, dictionary: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
                try! Realm().commitWrite()
                verifySwiftObjectWithDictionaryLiteral(object, dictionary: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
            }
        }

        // test with invalid dictionary literals
        for propNum in 0..<props.count {
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with invalid value and init
                var values = baselineValues
                values[props[propNum].name] = invalidValue
                try! Realm().beginWrite()
                assertThrows(try! Realm().create(SwiftObject.self, value: values), "Invalid property value")
                try! Realm().cancelWrite()
            }
        }
    }

    func testCreateWithDefaultsAndDictionary() {
        // test with dictionary with mix of default and one specified value
        let realm = try! Realm()
        realm.beginWrite()
        let objectWithInt = realm.create(SwiftObject.self, value: ["intCol": 200])
        try! realm.commitWrite()

        let valueDict = defaultSwiftObjectValuesWithReplacements(["intCol": 200])
        verifySwiftObjectWithDictionaryLiteral(objectWithInt, dictionary: valueDict, boolObjectValue: false,
            boolObjectListValues: [])
    }

    func testCreateWithArray() {
        // array with all values specified
        let baselineValues: [Any] = [true, 1, Int8(1), Int16(1), Int32(1), Int64(1), IntEnum.value1.rawValue, 1.1 as Float,
                                     11.1, "b", "b".data(using: String.Encoding.utf8)!,
                                     Date(timeIntervalSince1970: 2), Decimal128(number: 123),
                                     ObjectId.generate(), ["boolCol": true],
                                     UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!,
                                     "anyCol", [[true], [false]], [[true], [false]],
                                     ["trueVal": ["boolCol": true], "falseVal": ["boolCol": false]]]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                var values = baselineValues
                values[propNum] = validValue
                try! Realm().beginWrite()
                let object = try! Realm().create(SwiftObject.self, value: values)
                verifySwiftObjectWithArrayLiteral(object, array: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
                try! Realm().commitWrite()
                verifySwiftObjectWithArrayLiteral(object, array: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
            }
        }

        // test with invalid array literals
        for propNum in 0..<props.count {
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, (props[propNum].isArray || props[propNum].isSet), props[propNum].isMap) {
                // update dict with invalid value and init
                var values = baselineValues
                values[propNum] = invalidValue

                try! Realm().beginWrite()
                assertThrows(try! Realm().create(SwiftObject.self, value: values),
                    "Invalid property value '\(invalidValue)' for property number \(propNum)")
                try! Realm().cancelWrite()
            }
        }
    }

    func testCreateWithKVCObject() {
        // test with kvc object
        try! Realm().beginWrite()
        let objectWithInt = try! Realm().create(SwiftObject.self, value: ["intCol": 200])
        let objectWithKVCObject = try! Realm().create(SwiftObject.self, value: objectWithInt)
        let valueDict = defaultSwiftObjectValuesWithReplacements(["intCol": 200])
        try! Realm().commitWrite()

        verifySwiftObjectWithDictionaryLiteral(objectWithKVCObject, dictionary: valueDict, boolObjectValue: false,
            boolObjectListValues: [])
        XCTAssertEqual(try! Realm().objects(SwiftObject.self).count, 2, "Object should have been copied")
    }

    func testCreateWithNestedObjects() {
        let standalone = SwiftPrimaryStringObject(value: ["p0", 11])
        let realm = try! Realm()

        realm.beginWrite()
        let objectWithNestedObjects = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["p1", ["p1", 12],
            [standalone]])
        try! realm.commitWrite()

        let stringObjects = realm.objects(SwiftPrimaryStringObject.self)
        XCTAssertEqual(stringObjects.count, 2)
        let p0 = realm.object(ofType: SwiftPrimaryStringObject.self, forPrimaryKey: "p0")
        let p1 = realm.object(ofType: SwiftPrimaryStringObject.self, forPrimaryKey: "p1")

        // standalone object should be copied into the realm, not added directly
        XCTAssertNil(standalone.realm)
        XCTAssertNotEqual(standalone, p0)
        XCTAssertEqual(objectWithNestedObjects.object!, p1)
        XCTAssertEqual(objectWithNestedObjects.objects.first!, p0)

        let standalone1 = SwiftPrimaryStringObject(value: ["p3", 11])
        realm.beginWrite()
        assertThrows(realm.create(SwiftLinkToPrimaryStringObject.self, value: ["p3", ["p3", 11], [standalone1]]),
            "Should throw with duplicate primary key")
        try! realm.commitWrite()
    }

    func testUpdateWithNestedObjects() {
        let standalone = SwiftPrimaryStringObject(value: ["primary", 11])
        try! Realm().beginWrite()
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["otherPrimary", ["primary", 12],
            [["primary", 12]]], update: .all)
        try! Realm().commitWrite()

        let stringObjects = try! Realm().objects(SwiftPrimaryStringObject.self)
        XCTAssertEqual(stringObjects.count, 1)
        let persistedObject = object.object!

        XCTAssertEqual(persistedObject.intCol, 12)
        XCTAssertNil(standalone.realm) // the standalone object should be copied, rather than added, to the realm
        XCTAssertEqual(object.object!, persistedObject)
        XCTAssertEqual(object.objects.first!, persistedObject)
    }

    func testUpdateChangedWithNestedObjects() {
        let standalone = SwiftPrimaryStringObject(value: ["primary", 11])
        try! Realm().beginWrite()
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["otherPrimary", ["primary", 12],
                                                                                      [["primary", 12]]], update: .modified)
        try! Realm().commitWrite()

        let stringObjects = try! Realm().objects(SwiftPrimaryStringObject.self)
        XCTAssertEqual(stringObjects.count, 1)
        let persistedObject = object.object!

        XCTAssertEqual(persistedObject.intCol, 12)
        XCTAssertNil(standalone.realm) // the standalone object should be copied, rather than added, to the realm
        XCTAssertEqual(object.object!, persistedObject)
        XCTAssertEqual(object.objects.first!, persistedObject)
    }

    func testCreateWithObjectsFromAnotherRealm() {
        let values: [String: Any] = [
            "boolCol": true,
            "intCol": 1,
            "int8Col": 1 as Int8,
            "int16Col": 1 as Int16,
            "int32Col": 1 as Int32,
            "int64Col": 1 as Int64,
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "decimalCol": 3 as Decimal128,
            "objectIdCol": ObjectId.generate(),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "setCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "mapCol": ["trueVal": SwiftBoolObject(value: [true]), "falseVal": SwiftBoolObject(value: [false])]
        ]

        realmWithTestPath().beginWrite()
        let otherRealmObject = realmWithTestPath().create(SwiftObject.self, value: values)
        try! realmWithTestPath().commitWrite()

        try! Realm().beginWrite()
        let object = try! Realm().create(SwiftObject.self, value: otherRealmObject)
        try! Realm().commitWrite()

        XCTAssertNotEqual(otherRealmObject, object)
        verifySwiftObjectWithDictionaryLiteral(object, dictionary: values, boolObjectValue: true,
            boolObjectListValues: [true, false])
    }

    func testCreateWithDeeplyNestedObjectsFromAnotherRealm() {
        let values: [String: Any] = [
            "boolCol": true,
            "intCol": 1,
            "int8Col": 1 as Int8,
            "int16Col": 1 as Int16,
            "int32Col": 1 as Int32,
            "int64Col": 1 as Int64,
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "decimalCol": 3 as Decimal128,
            "objectIdCol": ObjectId.generate(),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "setCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "mapCol": ["trueVal": SwiftBoolObject(value: [true]), "falseVal": SwiftBoolObject(value: [false])]
        ]

        let realmA = realmWithTestPath()
        let realmB = try! Realm()

        var realmAListObject: SwiftListOfSwiftObject?
        try! realmA.write {
            let array = [SwiftObject(value: values), SwiftObject(value: values)]
            realmAListObject = realmA.create(SwiftListOfSwiftObject.self, value: ["array": array])
        }

        var realmBListObject: SwiftListOfSwiftObject!
        try! realmB.write {
            realmBListObject = realmB.create(SwiftListOfSwiftObject.self, value: realmAListObject!)
        }

        XCTAssertNotEqual(realmAListObject, realmBListObject)
        XCTAssertEqual(realmBListObject.array.count, 2)
        for swiftObject in realmBListObject.array {
            verifySwiftObjectWithDictionaryLiteral(swiftObject, dictionary: values, boolObjectValue: true,
                boolObjectListValues: [true, false])
        }

        var realmASetObject: SwiftMutableSetOfSwiftObject?
        try! realmA.write {
            let set = [SwiftObject(value: values), SwiftObject(value: values)]
            realmASetObject = realmA.create(SwiftMutableSetOfSwiftObject.self, value: ["set": set])
        }

        var realmBSetObject: SwiftMutableSetOfSwiftObject!
        try! realmB.write {
            realmBSetObject = realmB.create(SwiftMutableSetOfSwiftObject.self, value: realmASetObject!)
        }

        XCTAssertNotEqual(realmASetObject, realmBSetObject)
        XCTAssertEqual(realmBSetObject.set.count, 2)
        for swiftObject in realmBSetObject.set {
            verifySwiftObjectWithDictionaryLiteral(swiftObject, dictionary: values, boolObjectValue: true,
                boolObjectListValues: [true, false])
        }
    }

    func testUpdateWithObjectsFromAnotherRealm() {
        realmWithTestPath().beginWrite()
        let otherRealmObject = realmWithTestPath().create(SwiftLinkToPrimaryStringObject.self,
                                                                value: ["primary", NSNull(), [["2", 2], ["4", 4]]])
        try! realmWithTestPath().commitWrite()

        try! Realm().beginWrite()
        try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["primary", ["10", 10], [["11", 11]]])
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: otherRealmObject, update: .all)
        try! Realm().commitWrite()

        XCTAssertNotEqual(otherRealmObject, object) // the object from the other realm should be copied into this realm
        XCTAssertEqual(try! Realm().objects(SwiftLinkToPrimaryStringObject.self).count, 1)
        XCTAssertEqual(try! Realm().objects(SwiftPrimaryStringObject.self).count, 4)
    }

    func testUpdateChangedWithObjectsFromAnotherRealm() {
        realmWithTestPath().beginWrite()
        let otherRealmObject = realmWithTestPath().create(SwiftLinkToPrimaryStringObject.self,
                                                          value: ["primary", NSNull(), [["2", 2], ["4", 4]]])
        try! realmWithTestPath().commitWrite()

        try! Realm().beginWrite()
        try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["primary", ["10", 10], [["11", 11]]])
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: otherRealmObject, update: .modified)
        try! Realm().commitWrite()

        XCTAssertNotEqual(otherRealmObject, object) // the object from the other realm should be copied into this realm
        XCTAssertEqual(try! Realm().objects(SwiftLinkToPrimaryStringObject.self).count, 1)
        XCTAssertEqual(try! Realm().objects(SwiftPrimaryStringObject.self).count, 4)
    }

    func testCreateWithNSNullLinks() {
        let values: [String: Any] = [
            "boolCol": true,
            "intCol": 1,
            "floatCol": 1.1,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "decimalCol": 3 as Decimal128,
            "objectIdCol": ObjectId.generate(),
            "objectCol": NSNull(),
            "arrayCol": NSNull(),
            "setCol": NSNull()
        ]

        realmWithTestPath().beginWrite()
        let object = realmWithTestPath().create(SwiftObject.self, value: values)
        try! realmWithTestPath().commitWrite()

        XCTAssert(object.objectCol == nil) // XCTAssertNil caused a NULL deref inside _swift_getClass
        XCTAssertEqual(object.arrayCol.count, 0)
        XCTAssertEqual(object.setCol.count, 0)
    }

    func testCreateWithObjcName() {
        let realm = try! Realm()
        try! realm.write {
            let object = realm.create(SwiftObjcRenamedObject.self)
            object.stringCol = "string"
        }

        XCTAssertEqual(realm.objects(SwiftObjcRenamedObject.self).count, 1)

        try! realm.write {
            realm.delete(realm.objects(SwiftObjcRenamedObject.self))
        }
    }

    func testCreateWithDifferentObjcName() {
        let realm = try! Realm()
        try! realm.write {
            let object = realm.create(SwiftObjcArbitrarilyRenamedObject.self)
            object.boolCol = true
        }

        XCTAssertEqual(realm.objects(SwiftObjcArbitrarilyRenamedObject.self).count, 1)

        try! realm.write {
            realm.delete(realm.objects(SwiftObjcArbitrarilyRenamedObject.self))
        }
    }

    func testCreateOrUpdateNil() {
        let realm = try! Realm()
        realm.beginWrite()

        // Create with all fields nil
        let object = realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: .all)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        // Try to switch to non-nil
        let object2 = SwiftOptionalPrimaryObject()
        object2.optIntCol.value = 1
        object2.optInt8Col.value = 1
        object2.optInt16Col.value = 1
        object2.optInt32Col.value = 1
        object2.optInt64Col.value = 1
        object2.optFloatCol.value = 1
        object2.optDoubleCol.value = 1
        object2.optBoolCol.value = true
        object2.optDateCol = Date()
        object2.optStringCol = ""
        object2.optNSStringCol = ""
        object2.optBinaryCol = Data()
        object2.optObjectCol = SwiftBoolObject()
        realm.create(SwiftOptionalPrimaryObject.self, value: object2, update: .all)

        XCTAssertNil(object.id.value)
        XCTAssertNotNil(object.optIntCol.value)
        XCTAssertNotNil(object.optInt8Col.value)
        XCTAssertNotNil(object.optInt16Col.value)
        XCTAssertNotNil(object.optInt32Col.value)
        XCTAssertNotNil(object.optInt64Col.value)
        XCTAssertNotNil(object.optBoolCol.value)
        XCTAssertNotNil(object.optFloatCol.value)
        XCTAssertNotNil(object.optDoubleCol.value)
        XCTAssertNotNil(object.optDateCol)
        XCTAssertNotNil(object.optStringCol)
        XCTAssertNotNil(object.optNSStringCol)
        XCTAssertNotNil(object.optBinaryCol)
        XCTAssertNotNil(object.optObjectCol)

        // Try to switch back to nil
        realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: .all)

        XCTAssertNil(object.id.value)

        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        realm.cancelWrite()
    }

    func testCreateOrUpdateModifiedNil() {
        let realm = try! Realm()
        realm.beginWrite()

        // Create with all fields nil
        let object = realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: .modified)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        // Try to switch to non-nil
        let object2 = SwiftOptionalPrimaryObject()
        object2.optIntCol.value = 1
        object2.optInt8Col.value = 1
        object2.optInt16Col.value = 1
        object2.optInt32Col.value = 1
        object2.optInt64Col.value = 1
        object2.optFloatCol.value = 1
        object2.optDoubleCol.value = 1
        object2.optBoolCol.value = true
        object2.optDateCol = Date()
        object2.optStringCol = ""
        object2.optNSStringCol = ""
        object2.optBinaryCol = Data()
        object2.optObjectCol = SwiftBoolObject()
        realm.create(SwiftOptionalPrimaryObject.self, value: object2, update: .modified)

        XCTAssertNil(object.id.value)
        XCTAssertNotNil(object.optIntCol.value)
        XCTAssertNotNil(object.optInt8Col.value)
        XCTAssertNotNil(object.optInt16Col.value)
        XCTAssertNotNil(object.optInt32Col.value)
        XCTAssertNotNil(object.optInt64Col.value)
        XCTAssertNotNil(object.optBoolCol.value)
        XCTAssertNotNil(object.optFloatCol.value)
        XCTAssertNotNil(object.optDoubleCol.value)
        XCTAssertNotNil(object.optDateCol)
        XCTAssertNotNil(object.optStringCol)
        XCTAssertNotNil(object.optNSStringCol)
        XCTAssertNotNil(object.optBinaryCol)
        XCTAssertNotNil(object.optObjectCol)

        // Try to switch back to nil
        realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: .modified)

        XCTAssertNil(object.id.value)

        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        realm.cancelWrite()
    }

    func testCreateOrUpdateDynamicUnmanagedType() {
        let realm = try! Realm()
        let unmanagedValue = SwiftOptionalPrimaryObject()
        // Shouldn't throw.
        realm.beginWrite()
        _ = realm.create(type(of: unmanagedValue), value: unmanagedValue, update: .modified)
        realm.cancelWrite()
    }

    func testCreateOrUpdateDynamicManagedType() {
        let realm = try! Realm()
        let managedValue = SwiftOptionalPrimaryObject()
        try! realm.write {
            realm.add(managedValue)
        }
        // Shouldn't throw.
        realm.beginWrite()
        _ = realm.create(type(of: managedValue), value: managedValue, update: .all)
        realm.cancelWrite()
    }

    func testCreateOrUpdateModifiedDynamicManagedType() {
        let realm = try! Realm()
        let managedValue = SwiftOptionalPrimaryObject()
        try! realm.write {
            realm.add(managedValue)
        }
        // Shouldn't throw.
        realm.beginWrite()
        _ = realm.create(type(of: managedValue), value: managedValue, update: .modified)
        realm.cancelWrite()
    }

    func testCreateOrUpdateWithMismatchedStaticAndDynamicTypes() {
        let realm = try! Realm()
        let obj: Object = SwiftOptionalPrimaryObject()
        try! realm.write {
            let obj2 = realm.create(type(of: obj), value: obj)
            XCTAssertEqual(obj2.objectSchema.className, "SwiftOptionalPrimaryObject")
            let obj3 = realm.create(type(of: obj), value: obj, update: .all)
            XCTAssertEqual(obj3.objectSchema.className, "SwiftOptionalPrimaryObject")
        }
    }

    func testDynamicCreateEmbeddedDirectly() {
        let realm = try! Realm()
        realm.beginWrite()
        assertThrows(realm.dynamicCreate("EmbeddedTreeObject1", value: []),
                     reasonMatching: "Embedded objects cannot be created directly")
        realm.cancelWrite()
    }

    func testCreateEmbeddedWithDictionary() {
        let realm = try! Realm()
        realm.beginWrite()
        let parent = realm.create(EmbeddedParentObject.self, value: [
            "object": ["value": 5, "child": ["value": 6], "children": [[7], [8]]],
            "array": [[9], [10]]
        ])
        XCTAssertEqual(parent.object!.value, 5)
        XCTAssertEqual(parent.object!.child!.value, 6)
        XCTAssertEqual(parent.object!.children.count, 2)
        XCTAssertEqual(parent.object!.children[0].value, 7)
        XCTAssertEqual(parent.object!.children[1].value, 8)
        XCTAssertEqual(parent.array.count, 2)
        XCTAssertEqual(parent.array[0].value, 9)
        XCTAssertEqual(parent.array[1].value, 10)

        XCTAssertTrue(parent.isSameObject(as: parent.object!.parent1.first!))
        XCTAssertTrue(parent.isSameObject(as: parent.array[0].parent2.first!))
        XCTAssertTrue(parent.isSameObject(as: parent.array[1].parent2.first!))
        XCTAssertTrue(parent.object!.isSameObject(as: parent.object!.child!.parent3.first!))
        XCTAssertTrue(parent.object!.isSameObject(as: parent.object!.children[0].parent4.first!))
        XCTAssertTrue(parent.object!.isSameObject(as: parent.object!.children[1].parent4.first!))

        realm.cancelWrite()
    }

    func testCreateEmbeddedWithUnmanagedObjects() {
        let sourceObject = EmbeddedParentObject()
        sourceObject.object = .init(value: [5])
        sourceObject.object!.child = .init(value: [6])
        sourceObject.object!.children.append(.init(value: [7]))
        sourceObject.object!.children.append(.init(value: [8]))
        sourceObject.array.append(.init(value: [9]))
        sourceObject.array.append(.init(value: [10]))

        let realm = try! Realm()
        realm.beginWrite()
        let parent = realm.create(EmbeddedParentObject.self, value: sourceObject)
        XCTAssertNil(sourceObject.realm)
        XCTAssertEqual(parent.object!.value, 5)
        XCTAssertEqual(parent.object!.child!.value, 6)
        XCTAssertEqual(parent.object!.children.count, 2)
        XCTAssertEqual(parent.object!.children[0].value, 7)
        XCTAssertEqual(parent.object!.children[1].value, 8)
        XCTAssertEqual(parent.array.count, 2)
        XCTAssertEqual(parent.array[0].value, 9)
        XCTAssertEqual(parent.array[1].value, 10)
        realm.cancelWrite()
    }

    func testCreateEmbeddedFromManagedObjectInSameRealm() {
        let realm = try! Realm()
        realm.beginWrite()
        let parent = realm.create(EmbeddedParentObject.self, value: [
            "object": ["value": 5, "child": ["value": 6], "children": [[7], [8]]],
            "array": [[9], [10]]
        ])
        let copy = realm.create(EmbeddedParentObject.self, value: parent)
        XCTAssertNotEqual(parent, copy)
        XCTAssertEqual(copy.object!.value, 5)
        XCTAssertEqual(copy.object!.child!.value, 6)
        XCTAssertEqual(copy.object!.children.count, 2)
        XCTAssertEqual(copy.object!.children[0].value, 7)
        XCTAssertEqual(copy.object!.children[1].value, 8)
        XCTAssertEqual(copy.array.count, 2)
        XCTAssertEqual(copy.array[0].value, 9)
        XCTAssertEqual(copy.array[1].value, 10)
        try! realm.commitWrite()
        XCTAssertEqual(realm.objects(EmbeddedParentObject.self).count, 2)
    }

    func testCreateEmbeddedFromManagedObjectInSameRealmCopyingByAdd() {
        let realm = try! Realm()
        try! realm.write {
            let parent = realm.create(EmbeddedParentObject.self, value: [
                "object": ["value": 5, "child": ["value": 6], "children": [[7], [8]]],
                "array": [[9], [10]]
            ])
            let copy = EmbeddedParentObject(value: parent)
            realm.add(copy)
            XCTAssertNotEqual(parent, copy)
            XCTAssertEqual(copy.object!.value, 5)
            XCTAssertEqual(copy.object!.child!.value, 6)
            XCTAssertEqual(copy.object!.children.count, 2)
            XCTAssertEqual(copy.object!.children[0].value, 7)
            XCTAssertEqual(copy.object!.children[1].value, 8)
            XCTAssertEqual(copy.array.count, 2)
            XCTAssertEqual(copy.array[0].value, 9)
            XCTAssertEqual(copy.array[1].value, 10)
        }
        XCTAssertEqual(realm.objects(EmbeddedParentObject.self).count, 2)
    }

    func testCreateEmbeddedFromManagedObjectInSameRealmCopyingByAssign() {
        let realm = try! Realm()
        try! realm.write {
            let parent = realm.create(EmbeddedParentObject.self, value: [
                "object": ["value": 5, "child": ["value": 6], "children": [[7], [8]]],
                "array": [[9], [10]]
            ])

            let copy = EmbeddedParentObject()
            copy.object = parent.object
            realm.add(copy)
            
            XCTAssertNotEqual(parent, copy)
            XCTAssertEqual(copy.object!.value, 5)
            XCTAssertEqual(copy.object!.child!.value, 6)
            XCTAssertEqual(copy.object!.children.count, 2)
            XCTAssertEqual(copy.object!.children[0].value, 7)
            XCTAssertEqual(copy.object!.children[1].value, 8)
            XCTAssertEqual(copy.array.count, 2)
            XCTAssertEqual(copy.array[0].value, 9)
            XCTAssertEqual(copy.array[1].value, 10)
        }
        XCTAssertEqual(realm.objects(EmbeddedParentObject.self).count, 2)
    }

    func testCreateEmbeddedFromManagedObjectInDifferentRealm() {
        let realmA = realmWithTestPath()
        let realmB = try! Realm()
        realmA.beginWrite()
        let parent = realmA.create(EmbeddedParentObject.self, value: [
            "object": ["value": 5, "child": ["value": 6], "children": [[7], [8]]],
            "array": [[9], [10]]
        ])
        try! realmA.commitWrite()

        realmB.beginWrite()
        let copy = realmB.create(EmbeddedParentObject.self, value: parent)
        XCTAssertNotEqual(parent, copy)
        XCTAssertEqual(copy.object!.value, 5)
        XCTAssertEqual(copy.object!.child!.value, 6)
        XCTAssertEqual(copy.object!.children.count, 2)
        XCTAssertEqual(copy.object!.children[0].value, 7)
        XCTAssertEqual(copy.object!.children[1].value, 8)
        XCTAssertEqual(copy.array.count, 2)
        XCTAssertEqual(copy.array[0].value, 9)
        XCTAssertEqual(copy.array[1].value, 10)
        realmB.cancelWrite()
    }

    // test null object
    // test null list

    // MARK: - Add tests
    func testAddWithExisingNestedObjects() {
        try! Realm().beginWrite()
        let existingObject = try! Realm().create(SwiftBoolObject.self)
        try! Realm().commitWrite()

        try! Realm().beginWrite()
        let object = SwiftObject(value: ["objectCol": existingObject])
        try! Realm().add(object)
        try! Realm().commitWrite()

        XCTAssertNotNil(object.realm)

        assertEqual(object.objectCol, existingObject)
    }

    class EmbeddedObjectFactory {
        private var value = 0
        var objects = [EmbeddedObject]()

        func create<T: EmbeddedTreeObject>() -> T {
            let obj = T()
            obj.value = value
            value += 1
            objects.append(obj)
            return obj
        }
    }

    func testAddEmbedded() {
        let objectFactory = EmbeddedObjectFactory()
        let parent = EmbeddedParentObject()
        parent.object = objectFactory.create()
        parent.object!.child = objectFactory.create()
        parent.object!.children.append(objectFactory.create())
        parent.object!.children.append(objectFactory.create())
        parent.array.append(objectFactory.create())
        parent.array.append(objectFactory.create())

        let realm = try! Realm()
        realm.beginWrite()
        realm.add(parent)
        for (i, object) in objectFactory.objects.enumerated() {
            XCTAssertEqual(object.realm, realm)
            XCTAssertEqual((object as! EmbeddedTreeObject).value, i)
        }
        XCTAssertEqual(parent.object!.value, 0)
        XCTAssertEqual(parent.object!.child!.value, 1)
        XCTAssertEqual(parent.object!.children.count, 2)
        XCTAssertEqual(parent.object!.children[0].value, 2)
        XCTAssertEqual(parent.object!.children[1].value, 3)
        XCTAssertEqual(parent.array.count, 2)
        XCTAssertEqual(parent.array[0].value, 4)
        XCTAssertEqual(parent.array[1].value, 5)
        realm.cancelWrite()
    }

    func testAddAndUpdateWithExisingNestedObjects() {
        try! Realm().beginWrite()
        let existingObject = try! Realm().create(SwiftPrimaryStringObject.self, value: ["primary", 1])
        try! Realm().commitWrite()

        try! Realm().beginWrite()
        let object = SwiftLinkToPrimaryStringObject(value: ["primary", ["primary", 2], []])
        try! Realm().add(object, update: .all)
        try! Realm().commitWrite()

        XCTAssertNotNil(object.realm)
        XCTAssertEqual(object.object!, existingObject) // the existing object should be updated
        XCTAssertEqual(existingObject.intCol, 2)
    }

    func testAddAndUpdateEmbedded() {
        let objectFactory = EmbeddedObjectFactory()
        let parent = EmbeddedPrimaryParentObject()
        parent.object = objectFactory.create()
        parent.object!.child = objectFactory.create()
        parent.object!.children.append(objectFactory.create())
        parent.object!.children.append(objectFactory.create())
        parent.array.append(objectFactory.create())
        parent.array.append(objectFactory.create())

        let parent2 = EmbeddedPrimaryParentObject()
        parent2.object = objectFactory.create()
        parent2.object!.child = objectFactory.create()
        parent2.object!.children.append(objectFactory.create())
        parent2.object!.children.append(objectFactory.create())
        parent2.array.append(objectFactory.create())
        parent2.array.append(objectFactory.create())

        let realm = try! Realm()
        realm.beginWrite()
        realm.add(parent)
        realm.add(parent2, update: .all)

        // update all deletes the old embedded objects and creates new ones
        for (i, object) in objectFactory.objects.enumerated() {
            XCTAssertEqual(object.realm, realm)
            if i < 6 {
                XCTAssertTrue(object.isInvalidated)
            } else {
                XCTAssertEqual((object as! EmbeddedTreeObject).value, i)
            }
        }
        XCTAssertTrue(parent.isSameObject(as: parent2))
        XCTAssertEqual(parent.object!.value, 6)
        XCTAssertEqual(parent.object!.child!.value, 7)
        XCTAssertEqual(parent.object!.children.count, 2)
        XCTAssertEqual(parent.object!.children[0].value, 8)
        XCTAssertEqual(parent.object!.children[1].value, 9)
        XCTAssertEqual(parent.array.count, 2)
        XCTAssertEqual(parent.array[0].value, 10)
        XCTAssertEqual(parent.array[1].value, 11)
        realm.cancelWrite()
    }

    func testAddAndUpdateChangedWithExisingNestedObjects() {
        try! Realm().beginWrite()
        let existingObject = try! Realm().create(SwiftPrimaryStringObject.self, value: ["primary", 1])
        try! Realm().commitWrite()

        try! Realm().beginWrite()
        let object = SwiftLinkToPrimaryStringObject(value: ["primary", ["primary", 2], []])
        try! Realm().add(object, update: .modified)
        try! Realm().commitWrite()

        XCTAssertNotNil(object.realm)
        XCTAssertEqual(object.object!, existingObject) // the existing object should be updated
        XCTAssertEqual(existingObject.intCol, 2)
    }

    func testAddAndUpdateChangedEmbedded() {
        let objectFactory = EmbeddedObjectFactory()
        let parent = EmbeddedPrimaryParentObject()
        parent.object = objectFactory.create()
        parent.object!.child = objectFactory.create()
        parent.object!.children.append(objectFactory.create())
        parent.object!.children.append(objectFactory.create())
        parent.array.append(objectFactory.create())
        parent.array.append(objectFactory.create())

        let parent2 = EmbeddedPrimaryParentObject()
        parent2.object = objectFactory.create()
        parent2.object!.child = objectFactory.create()
        parent2.object!.children.append(objectFactory.create())
        parent2.object!.children.append(objectFactory.create())
        parent2.array.append(objectFactory.create())
        parent2.array.append(objectFactory.create())

        let realm = try! Realm()
        realm.beginWrite()
        realm.add(parent)
        realm.add(parent2, update: .modified)

        // update modified modifies the existing embedded objects
        for (i, object) in objectFactory.objects.enumerated() {
            XCTAssertEqual(object.realm, realm)
            XCTAssertEqual((object as! EmbeddedTreeObject).value, i < 6 ? i + 6 : i)
        }
        XCTAssertTrue(parent.isSameObject(as: parent2))
        XCTAssertEqual(parent.object!.value, 6)
        XCTAssertEqual(parent.object!.child!.value, 7)
        XCTAssertEqual(parent.object!.children.count, 2)
        XCTAssertEqual(parent.object!.children[0].value, 8)
        XCTAssertEqual(parent.object!.children[1].value, 9)
        XCTAssertEqual(parent.array.count, 2)
        XCTAssertEqual(parent.array[0].value, 10)
        XCTAssertEqual(parent.array[1].value, 11)
        realm.cancelWrite()
    }

    func testAddObjectCycle() {
        weak var weakObj1: SwiftCircleObject? = nil, weakObj2: SwiftCircleObject? = nil

        autoreleasepool {
            let obj1 = SwiftCircleObject(value: [])
            let obj2 = SwiftCircleObject(value: [obj1, [obj1]])
            obj1.obj = obj2
            obj1.array.append(obj2)

            weakObj1 = obj1
            weakObj2 = obj2

            let realm = try! Realm()
            try! realm.write {
                realm.add(obj1)
            }

            XCTAssertEqual(obj1.realm, realm)
            XCTAssertEqual(obj2.realm, realm)
        }

        XCTAssertNil(weakObj1)
        XCTAssertNil(weakObj2)
    }

    func testAddOrUpdateNil() {
        let realm = try! Realm()
        realm.beginWrite()

        // Create with all fields nil
        let object = SwiftOptionalPrimaryObject()
        realm.add(object)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        // Try to switch to non-nil
        let object2 = SwiftOptionalPrimaryObject()
        object2.optIntCol.value = 1
        object2.optInt8Col.value = 1
        object2.optInt16Col.value = 1
        object2.optInt32Col.value = 1
        object2.optInt64Col.value = 1
        object2.optFloatCol.value = 1
        object2.optDoubleCol.value = 1
        object2.optBoolCol.value = true
        object2.optDateCol = Date()
        object2.optStringCol = ""
        object2.optNSStringCol = ""
        object2.optBinaryCol = Data()
        object2.optObjectCol = SwiftBoolObject()
        realm.add(object2, update: .all)

        XCTAssertNil(object.id.value)
        XCTAssertNotNil(object.optIntCol.value)
        XCTAssertNotNil(object.optInt8Col.value)
        XCTAssertNotNil(object.optInt16Col.value)
        XCTAssertNotNil(object.optInt32Col.value)
        XCTAssertNotNil(object.optInt64Col.value)
        XCTAssertNotNil(object.optBoolCol.value)
        XCTAssertNotNil(object.optFloatCol.value)
        XCTAssertNotNil(object.optDoubleCol.value)
        XCTAssertNotNil(object.optDateCol)
        XCTAssertNotNil(object.optStringCol)
        XCTAssertNotNil(object.optNSStringCol)
        XCTAssertNotNil(object.optBinaryCol)
        XCTAssertNotNil(object.optObjectCol)

        // Try to switch back to nil
        let object3 = SwiftOptionalPrimaryObject()
        realm.add(object3, update: .all)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        realm.cancelWrite()
    }

    func testAddOrUpdateModifiedNil() {
        let realm = try! Realm()
        realm.beginWrite()

        // Create with all fields nil
        let object = SwiftOptionalPrimaryObject()
        realm.add(object)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        // Try to switch to non-nil
        let object2 = SwiftOptionalPrimaryObject()
        object2.optIntCol.value = 1
        object2.optInt8Col.value = 1
        object2.optInt16Col.value = 1
        object2.optInt32Col.value = 1
        object2.optInt64Col.value = 1
        object2.optFloatCol.value = 1
        object2.optDoubleCol.value = 1
        object2.optBoolCol.value = true
        object2.optDateCol = Date()
        object2.optStringCol = ""
        object2.optNSStringCol = ""
        object2.optBinaryCol = Data()
        object2.optObjectCol = SwiftBoolObject()
        realm.add(object2, update: .modified)

        XCTAssertNil(object.id.value)
        XCTAssertNotNil(object.optIntCol.value)
        XCTAssertNotNil(object.optInt8Col.value)
        XCTAssertNotNil(object.optInt16Col.value)
        XCTAssertNotNil(object.optInt32Col.value)
        XCTAssertNotNil(object.optInt64Col.value)
        XCTAssertNotNil(object.optBoolCol.value)
        XCTAssertNotNil(object.optFloatCol.value)
        XCTAssertNotNil(object.optDoubleCol.value)
        XCTAssertNotNil(object.optDateCol)
        XCTAssertNotNil(object.optStringCol)
        XCTAssertNotNil(object.optNSStringCol)
        XCTAssertNotNil(object.optBinaryCol)
        XCTAssertNotNil(object.optObjectCol)

        // Try to switch back to nil
        let object3 = SwiftOptionalPrimaryObject()
        realm.add(object3, update: .modified)

        XCTAssertNil(object.id.value)
        XCTAssertNil(object.optIntCol.value)
        XCTAssertNil(object.optInt8Col.value)
        XCTAssertNil(object.optInt16Col.value)
        XCTAssertNil(object.optInt32Col.value)
        XCTAssertNil(object.optInt64Col.value)
        XCTAssertNil(object.optBoolCol.value)
        XCTAssertNil(object.optFloatCol.value)
        XCTAssertNil(object.optDoubleCol.value)
        XCTAssertNil(object.optDateCol)
        XCTAssertNil(object.optStringCol)
        XCTAssertNil(object.optNSStringCol)
        XCTAssertNil(object.optBinaryCol)
        XCTAssertNil(object.optObjectCol)

        realm.cancelWrite()
    }

    /// If a Swift class declares generic properties before non-generic ones, the properties
    /// should be registered in order and creation from an array of values should work.
    func testProperOrderingOfProperties() {
        let v: [Any] = [
            // Superclass's columns
            [["intCol": 42], ["intCol": 9001]],
            [["intCol": 42], ["intCol": 9001]],
            100,
            200,
            // Class's columns
            1,
            [["stringCol": "hello"], ["stringCol": "world"]],
            [["stringCol": "hello"], ["stringCol": "world"]],
            2,
            [["stringCol": "goodbye"], ["stringCol": "cruel"], ["stringCol": "world"]],
            [["stringCol": "goodbye"], ["stringCol": "cruel"], ["stringCol": "world"]],
            NSNull(),
            3,
            300]
        let object = SwiftGenericPropsOrderingObject(value: v)
        XCTAssertEqual(object.firstNumber, 1)
        XCTAssertEqual(object.secondNumber, 2)
        XCTAssertEqual(object.thirdNumber, 3)
        XCTAssertTrue(object.firstArray.count == 2)
        XCTAssertEqual(object.firstArray[0].stringCol, "hello")
        XCTAssertEqual(object.firstArray[1].stringCol, "world")
        XCTAssertTrue(object.secondArray.count == 3)
        XCTAssertEqual(object.secondArray[0].stringCol, "goodbye")
        XCTAssertEqual(object.secondArray[1].stringCol, "cruel")
        XCTAssertEqual(object.secondArray[2].stringCol, "world")
        XCTAssertTrue(object.firstSet.count == 2)
        assertSetContains(object.firstSet, keyPath: \.stringCol, items: ["hello", "world"])
        XCTAssertTrue(object.secondSet.count == 3)
        assertSetContains(object.secondSet, keyPath: \.stringCol, items: ["goodbye", "cruel", "world"])
        XCTAssertEqual(object.firstOptionalNumber.value, nil)
        XCTAssertEqual(object.secondOptionalNumber.value, 300)
        XCTAssertTrue(object.parentFirstList.count == 2)
        XCTAssertEqual(object.parentFirstList[0].intCol, 42)
        XCTAssertEqual(object.parentFirstList[1].intCol, 9001)
        XCTAssertEqual(object.parentFirstNumber, 100)
        XCTAssertEqual(object.parentSecondNumber, 200)
        XCTAssertTrue(object.firstLinking.count == 0)
        XCTAssertTrue(object.secondLinking.count == 0)
    }

    func testPrivateOptionalNonobjcString() {
        let realm = try! Realm()
        try! realm.write {
            let obj = ObjectWithPrivateOptionals()
            obj.value = 5
            realm.add(obj)
            XCTAssertEqual(realm.objects(ObjectWithPrivateOptionals.self).first!.value, 5)
        }
    }

    // MARK: - Private utilities
    private func verifySwiftObjectWithArrayLiteral(_ object: SwiftObject, array: [Any], boolObjectValue: Bool,
                                                   boolObjectListValues: [Bool]) {
        XCTAssertEqual(object.boolCol, (array[0] as! Bool))
        XCTAssertEqual(object.intCol, (array[1] as! Int))
        XCTAssertEqual(object.int8Col, (array[2] as! Int8))
        XCTAssertEqual(object.int16Col, (array[3] as! Int16))
        XCTAssertEqual(object.int32Col, (array[4] as! Int32))
        XCTAssertEqual(object.int64Col, (array[5] as! Int64))
        XCTAssertEqual(object.intEnumCol, IntEnum(rawValue: array[6] as! Int))
        XCTAssertEqual(object.floatCol, (array[7] as! NSNumber).floatValue)
        XCTAssertEqual(object.doubleCol, (array[8] as! Double))
        XCTAssertEqual(object.stringCol, (array[9] as! String))
        XCTAssertEqual(object.binaryCol, (array[10] as! Data))
        XCTAssertEqual(object.dateCol, (array[11] as! Date))
        XCTAssertEqual(object.decimalCol, Decimal128(value: array[12]))
        XCTAssertEqual(object.objectIdCol, (array[13] as! ObjectId))
        XCTAssertEqual(object.objectCol!.boolCol, boolObjectValue)
        XCTAssertEqual(object.arrayCol.count, boolObjectListValues.count)
        XCTAssertEqual(object.setCol.count, boolObjectListValues.count)
        for i in 0..<boolObjectListValues.count {
            XCTAssertEqual(object.arrayCol[i].boolCol, boolObjectListValues[i])
        }
        object.setCol.forEach { obj in
            XCTAssertTrue(boolObjectListValues.contains(obj.boolCol))
        }
        for value in object.mapCol.map({ $0.value!.boolCol }) {
            XCTAssertTrue(boolObjectListValues.contains(value))
        }
    }

    private func verifySwiftObjectWithDictionaryLiteral(_ object: SwiftObject, dictionary: [String: Any],
                                                        boolObjectValue: Bool, boolObjectListValues: [Bool]) {
        XCTAssertEqual(object.boolCol, (dictionary["boolCol"] as! Bool))
        XCTAssertEqual(object.intCol, (dictionary["intCol"] as? Int))
        XCTAssertEqual(object.int8Col, (dictionary["int8Col"] as? Int8))
        XCTAssertEqual(object.int16Col, (dictionary["int16Col"] as? Int16))
        XCTAssertEqual(object.int32Col, (dictionary["int32Col"] as? Int32))
        XCTAssertEqual(object.int64Col, (dictionary["int64Col"] as? Int64))
        XCTAssertEqual(object.floatCol, (dictionary["floatCol"] as! NSNumber).floatValue)
        XCTAssertEqual(object.doubleCol, (dictionary["doubleCol"] as! Double))
        XCTAssertEqual(object.stringCol, (dictionary["stringCol"] as! String))
        XCTAssertEqual(object.binaryCol, (dictionary["binaryCol"] as! Data))
        XCTAssertEqual(object.dateCol, (dictionary["dateCol"] as! Date))
        XCTAssertEqual(object.decimalCol, Decimal128(value: dictionary["decimalCol"]!))
        XCTAssertEqual(object.objectIdCol, (dictionary["objectIdCol"] as! ObjectId))
        XCTAssertEqual(object.objectCol!.boolCol, boolObjectValue)
        XCTAssertEqual(object.arrayCol.count, boolObjectListValues.count)
        XCTAssertEqual(object.setCol.count, boolObjectListValues.count)
        XCTAssertEqual(object.mapCol.count, boolObjectListValues.count)

        for i in 0..<boolObjectListValues.count {
            XCTAssertEqual(object.arrayCol[i].boolCol, boolObjectListValues[i])
            XCTAssertTrue(boolObjectListValues.contains(object.setCol[i].boolCol))
        }
    }

    private func verifySwiftOptionalObjectWithDictionaryLiteral(_ object: SwiftOptionalDefaultValuesObject,
                                                                dictionary: [String: Any],
                                                                boolObjectValue: Bool?) {
        XCTAssertEqual(object.optBoolCol.value, (dictionary["optBoolCol"] as! Bool?))
        XCTAssertEqual(object.optIntCol.value, (dictionary["optIntCol"] as! Int?))
        XCTAssertEqual(object.optInt8Col.value,
                       ((dictionary["optInt8Col"] as! NSNumber?)?.int8Value).map({Int8($0)}))
        XCTAssertEqual(object.optInt16Col.value,
                       ((dictionary["optInt16Col"] as! NSNumber?)?.int16Value).map({Int16($0)}))
        XCTAssertEqual(object.optInt32Col.value,
            ((dictionary["optInt32Col"] as! NSNumber?)?.int32Value).map({Int32($0)}))
        XCTAssertEqual(object.optInt64Col.value, (dictionary["optInt64Col"] as! NSNumber?)?.int64Value)
        XCTAssertEqual(object.optFloatCol.value, (dictionary["optFloatCol"] as! Float?))
        XCTAssertEqual(object.optDoubleCol.value, (dictionary["optDoubleCol"] as! Double?))
        XCTAssertEqual(object.optStringCol, (dictionary["optStringCol"] as! String?))
        XCTAssertEqual(object.optNSStringCol, (dictionary["optNSStringCol"] as! NSString))
        XCTAssertEqual(object.optBinaryCol, (dictionary["optBinaryCol"] as! Data?))
        XCTAssertEqual(object.optDateCol, (dictionary["optDateCol"] as! Date?))
        XCTAssertEqual(object.optDecimalCol, (dictionary["optDecimalCol"] as! Decimal128?))
        XCTAssertEqual(object.optObjectIdCol, (dictionary["optObjectIdCol"] as! ObjectId?))
        XCTAssertEqual(object.optObjectCol?.boolCol, boolObjectValue)
        XCTAssertEqual(object.optUuidCol, (dictionary["optUuidCol"] as! UUID?))
    }

    private func defaultSwiftObjectValuesWithReplacements(_ replace: [String: Any]) -> [String: Any] {
        var valueDict = SwiftObject.defaultValues()
        for (key, value) in replace {
            valueDict[key] = value
        }
        return valueDict
    }

    // return an array of valid values that can be used to initialize each type
    private func validValuesForSwiftObjectType(_ type: PropertyType, _ array: Bool, _ map: Bool) -> [Any] {
        try! Realm().beginWrite()
        let persistedObject = try! Realm().create(SwiftBoolObject.self, value: [true])
        try! Realm().commitWrite()
        if map {
            return [
                ["trueVal": ["boolCol": true], "falseVal": ["boolCol": false]],
                ["trueVal": SwiftBoolObject(value: [true]), "falseVal": SwiftBoolObject(value: [false])],
                ["trueVal": persistedObject, "falseVal": [false]]
            ]
        }
        if array {
            return [
                [[true], [false]],
                [["boolCol": true], ["boolCol": false]],
                [SwiftBoolObject(value: [true]), SwiftBoolObject(value: [false])],
                [persistedObject, [false]]
            ]
        }
        switch type {
        case .bool:     return [true, NSNumber(value: 0 as Int), NSNumber(value: 1 as Int)]
        case .int:      return [NSNumber(value: 1 as Int)]
        case .float:    return [NSNumber(value: 1 as Int), NSNumber(value: 1.1 as Float), NSNumber(value: 11.1 as Double)]
        case .double:   return [NSNumber(value: 1 as Int), NSNumber(value: 1.1 as Float), NSNumber(value: 11.1 as Double)]
        case .string:   return ["b"]
        case .data:     return ["b".data(using: String.Encoding.utf8, allowLossyConversion: false)!]
        case .date:     return [Date(timeIntervalSince1970: 2)]
        case .object:   return [[true], ["boolCol": true], SwiftBoolObject(value: [true]), persistedObject]
        case .objectId: return [ObjectId("1234567890ab1234567890ab")]
        case .decimal128: return [1, "2", Decimal128(number: 3)]
        case .any:      return ["hello"]
        case .linkingObjects: fatalError("not supported")
        case .UUID: return [UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!, UUID(uuidString: "00000000-0000-0000-0000-000000000000")!]
        }
    }

    private func invalidValuesForSwiftObjectType(_ type: PropertyType, _ array: Bool, _ map: Bool) -> [Any] {
        try! Realm().beginWrite()
        let persistedObject = try! Realm().create(SwiftIntObject.self)
        try! Realm().commitWrite()
        if map {
            return [
                ["trueVal": ["boolCol": "invalid"], "falseVal": ["boolCol": false]],
                ["trueVal": "invalid", "falseVal": SwiftBoolObject(value: [false])]
            ]
        }
        if array {
            return ["invalid", [["a"]], [["boolCol": "a"]], [[SwiftIntObject()]], [[persistedObject]]]
        }
        switch type {
        case .bool:     return ["invalid", NSNumber(value: 2 as Int), NSNumber(value: 1.1 as Float), NSNumber(value: 11.1 as Double)]
        case .int:      return ["invalid", NSNumber(value: 1.1 as Float), NSNumber(value: 11.1 as Double)]
        case .float:    return ["invalid", true, false]
        case .double:   return ["invalid", true, false]
        case .string:   return [0x197A71D, true, false]
        case .data:     return ["invalid"]
        case .date:     return ["invalid"]
        case .object:   return ["invalid", ["a"], ["boolCol": "a"], SwiftIntObject()]
        case .objectId: return ["invalid", 123]
        case .decimal128: return ["invalid"]
        case .any: return [List<String>()]
        case .linkingObjects: fatalError("not supported")
        case .UUID: return ["invalid"]
        }
    }
}
