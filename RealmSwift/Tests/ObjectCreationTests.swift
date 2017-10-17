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

class ObjectCreationTests: TestCase {

    // MARK: Init tests
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
    }

    func testInitWithOptionalWithoutDefaults() {
        let object = SwiftOptionalObject()
        for prop in object.objectSchema.properties {
            let value = object[prop.name]
            if let value = value as? RLMOptionalBase {
                XCTAssertNil(value.__underlyingValue)
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
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "realmIntCol": RealmInteger(value: 100)
           ]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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
        let baselineValues: [Any] = [true, 1, 1.1 as Float, 11.1, "b", "b".data(using: String.Encoding.utf8)!,
                                     Date(timeIntervalSince1970: 2), ["boolCol": true], RealmInteger(value: 50),
                                     [[true], [false]]]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
                // update dict with valid value and init
                var values = baselineValues
                values[propNum] = validValue
                let object = SwiftObject(value: values)
                verifySwiftObjectWithArrayLiteral(object, array: values, boolObjectValue: true,
                    boolObjectListValues: [true, false])
            }
        }

        // test with invalid dictionary literals
        for propNum in 0..<props.count {
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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

    // MARK: Creation tests

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
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "realmIntCol": RealmInteger()
        ]

        // test with valid dictionary literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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
        let baselineValues: [Any] = [true, 1, 1.1 as Float, 11.1, "b", "b".data(using: String.Encoding.utf8)!,
            Date(timeIntervalSince1970: 2), ["boolCol": true], RealmInteger(), [[true], [false]]]

        // test with valid array literals
        let props = try! Realm().schema["SwiftObject"]!.properties
        for propNum in 0..<props.count {
            for validValue in validValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
                // update dict with valid value and init
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
            for invalidValue in invalidValuesForSwiftObjectType(props[propNum].type, props[propNum].isArray) {
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

        try! Realm().beginWrite()
        let objectWithNestedObjects = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["p1", ["p1", 11],
            [standalone]])
        try! Realm().commitWrite()

        let stringObjects = try! Realm().objects(SwiftPrimaryStringObject.self)
        XCTAssertEqual(stringObjects.count, 2)
        let persistedObject = stringObjects.first!

        // standalone object should be copied into the realm, not added directly
        XCTAssertNotEqual(standalone, persistedObject)
        XCTAssertEqual(objectWithNestedObjects.object!, persistedObject)
        XCTAssertEqual(objectWithNestedObjects.objects.first!, stringObjects.last!)

        let standalone1 = SwiftPrimaryStringObject(value: ["p3", 11])
        try! Realm().beginWrite()
        assertThrows(try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["p3", ["p3", 11], [standalone1]]),
            "Should throw with duplicate primary key")
        try! Realm().commitWrite()
    }

    func testUpdateWithNestedObjects() {
        let standalone = SwiftPrimaryStringObject(value: ["primary", 11])
        try! Realm().beginWrite()
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: ["otherPrimary", ["primary", 12],
            [["primary", 12]]], update: true)
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
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "realmIntCol": RealmInteger(value: 9001)
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
            "floatCol": 1.1 as Float,
            "doubleCol": 11.1,
            "stringCol": "b",
            "binaryCol": "b".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 2),
            "objectCol": SwiftBoolObject(value: [true]),
            "arrayCol": [SwiftBoolObject(value: [true]), SwiftBoolObject()],
            "realmIntCol": RealmInteger(value: 100)
        ]

        let realmA = realmWithTestPath()
        let realmB = try! Realm()

        var realmAObject: SwiftListOfSwiftObject!
        try! realmA.write {
            let array = [SwiftObject(value: values), SwiftObject(value: values)]
            realmAObject = realmA.create(SwiftListOfSwiftObject.self, value: ["array": array])
        }

        var realmBObject: SwiftListOfSwiftObject!
        try! realmB.write {
            realmBObject = realmB.create(SwiftListOfSwiftObject.self, value: realmAObject)
        }

        XCTAssertNotEqual(realmAObject, realmBObject)
        XCTAssertEqual(realmBObject.array.count, 2)
        for swiftObject in realmBObject.array {
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
        let object = try! Realm().create(SwiftLinkToPrimaryStringObject.self, value: otherRealmObject, update: true)
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
            "objectCol": NSNull(),
            "arrayCol": NSNull(),
            "realmIntCol": RealmInteger()
        ]

        realmWithTestPath().beginWrite()
        let object = realmWithTestPath().create(SwiftObject.self, value: values)
        try! realmWithTestPath().commitWrite()

        XCTAssert(object.objectCol == nil) // XCTAssertNil caused a NULL deref inside _swift_getClass
        XCTAssertEqual(object.arrayCol.count, 0)
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
        let object = realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: true)

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
        realm.create(SwiftOptionalPrimaryObject.self, value: object2, update: true)

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
        realm.create(SwiftOptionalPrimaryObject.self, value: SwiftOptionalPrimaryObject(), update: true)

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

    // test null object
    // test null list

    // MARK: Add tests
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

    func testAddAndUpdateWithExisingNestedObjects() {
        try! Realm().beginWrite()
        let existingObject = try! Realm().create(SwiftPrimaryStringObject.self, value: ["primary", 1])
        try! Realm().commitWrite()

        try! Realm().beginWrite()
        let object = SwiftLinkToPrimaryStringObject(value: ["primary", ["primary", 2], []])
        try! Realm().add(object, update: true)
        try! Realm().commitWrite()

        XCTAssertNotNil(object.realm)
        XCTAssertEqual(object.object!, existingObject) // the existing object should be updated
        XCTAssertEqual(existingObject.intCol, 2)
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
        realm.add(object2, update: true)

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
        realm.add(object3, update: true)

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
            100,
            200,
            // Class's columns
            1,
            [["stringCol": "hello"], ["stringCol": "world"]],
            2,
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

    // MARK: Private utilities
    private func verifySwiftObjectWithArrayLiteral(_ object: SwiftObject, array: [Any], boolObjectValue: Bool,
                                                   boolObjectListValues: [Bool]) {
        XCTAssertEqual(object.boolCol, (array[0] as! Bool))
        XCTAssertEqual(object.intCol, (array[1] as! Int))
        //XCTAssertEqual(object.floatCol, (array[2] as! Float)) // FIXME: crashes with swift 3.2
        XCTAssertEqual(object.doubleCol, (array[3] as! Double))
        XCTAssertEqual(object.stringCol, (array[4] as! String))
        XCTAssertEqual(object.binaryCol, (array[5] as! Data))
        XCTAssertEqual(object.dateCol, (array[6] as! Date))
        XCTAssertEqual(object.objectCol!.boolCol, boolObjectValue)
        XCTAssertEqual(object.realmIntCol.value, (array[8] as? RealmInteger)?.value ?? array[8] as? Int)
        XCTAssertEqual(object.arrayCol.count, boolObjectListValues.count)
        for i in 0..<boolObjectListValues.count {
            XCTAssertEqual(object.arrayCol[i].boolCol, boolObjectListValues[i])
        }
    }

    private func verifySwiftObjectWithDictionaryLiteral(_ object: SwiftObject, dictionary: [String: Any],
                                                        boolObjectValue: Bool, boolObjectListValues: [Bool]) {
        XCTAssertEqual(object.boolCol, (dictionary["boolCol"] as! Bool))
        XCTAssertEqual(object.intCol, (dictionary["intCol"] as! Int))
        //XCTAssertEqual(object.floatCol, (dictionary["floatCol"] as! Float)) // FIXME: crashes with swift 3.2
        XCTAssertEqual(object.doubleCol, (dictionary["doubleCol"] as! Double))
        XCTAssertEqual(object.stringCol, (dictionary["stringCol"] as! String))
        XCTAssertEqual(object.binaryCol, (dictionary["binaryCol"] as! Data))
        XCTAssertEqual(object.dateCol, (dictionary["dateCol"] as! Date))
        XCTAssertEqual(object.objectCol!.boolCol, boolObjectValue)
        XCTAssertEqual(object.arrayCol.count, boolObjectListValues.count)
        for i in 0..<boolObjectListValues.count {
            XCTAssertEqual(object.arrayCol[i].boolCol, boolObjectListValues[i])
        }
        XCTAssertEqual(object.realmIntCol.value,
                       (dictionary["realmIntCol"] as? RealmInteger)?.value ?? dictionary["realmIntCol"] as? Int)
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
        XCTAssertEqual(object.optObjectCol?.boolCol, boolObjectValue)
    }

    private func defaultSwiftObjectValuesWithReplacements(_ replace: [String: Any]) -> [String: Any] {
        var valueDict = SwiftObject.defaultValues()
        for (key, value) in replace {
            valueDict[key] = value
        }
        return valueDict
    }

    // return an array of valid values that can be used to initialize each type
    // swiftlint:disable:next cyclomatic_complexity
    private func validValuesForSwiftObjectType(_ type: PropertyType, _ array: Bool) -> [Any] {
        try! Realm().beginWrite()
        let persistedObject = try! Realm().create(SwiftBoolObject.self, value: [true])
        try! Realm().commitWrite()
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
        case .any: XCTFail("not supported")
        case .linkingObjects: XCTFail("not supported")
        }
        return []
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func invalidValuesForSwiftObjectType(_ type: PropertyType, _ array: Bool) -> [Any] {
        try! Realm().beginWrite()
        let persistedObject = try! Realm().create(SwiftIntObject.self)
        try! Realm().commitWrite()
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
        case .any: XCTFail("not supported")
        case .linkingObjects: XCTFail("not supported")
        }
        return []
    }
}
