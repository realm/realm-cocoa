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

class ObjectAccessorTests: TestCase {
    func setAndTestAllProperties(_ object: SwiftObject) {
        object.boolCol = true
        XCTAssertEqual(object.boolCol, true)
        object.boolCol = false
        XCTAssertEqual(object.boolCol, false)

        object.intCol = -1
        XCTAssertEqual(object.intCol, -1)
        object.intCol = 0
        XCTAssertEqual(object.intCol, 0)
        object.intCol = 1
        XCTAssertEqual(object.intCol, 1)

        object.floatCol = 20
        XCTAssertEqual(object.floatCol, 20 as Float)
        object.floatCol = 20.2
        XCTAssertEqual(object.floatCol, 20.2 as Float)
        object.floatCol = 16777217
        XCTAssertEqual(Double(object.floatCol), 16777216.0 as Double)

        object.doubleCol = 20
        XCTAssertEqual(object.doubleCol, 20)
        object.doubleCol = 20.2
        XCTAssertEqual(object.doubleCol, 20.2)
        object.doubleCol = 16777217
        XCTAssertEqual(object.doubleCol, 16777217)

        object.stringCol = ""
        XCTAssertEqual(object.stringCol, "")
        let utf8TestString = "值значен™👍☞⎠‱௹♣︎☐▼❒∑⨌⧭иеمرحبا"
        object.stringCol = utf8TestString
        XCTAssertEqual(object.stringCol, utf8TestString)

        let data = "b".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        object.binaryCol = data
        XCTAssertEqual(object.binaryCol, data)

        let date = Date(timeIntervalSinceReferenceDate: 2)
        object.dateCol = date
        XCTAssertEqual(object.dateCol, date)

        object.objectCol = SwiftBoolObject(value: [true])
        XCTAssertEqual(object.objectCol!.boolCol, true)

        object.realmIntCol = RealmInteger(value: 10)
        XCTAssertEqual(object.realmIntCol.value, 10)
        object.realmIntCol = RealmInteger(value: 11)
        XCTAssertEqual(object.realmIntCol.value, 11)
    }

    func testStandaloneAccessors() {
        let object = SwiftObject()
        setAndTestAllProperties(object)

        let optionalObject = SwiftOptionalObject()
        setAndTestAllOptionalProperties(optionalObject)
    }

    func testPersistedAccessors() {
        let realm = try! Realm()
        realm.beginWrite()
        let object = realm.create(SwiftObject.self)
        let optionalObject = realm.create(SwiftOptionalObject.self)
        setAndTestAllProperties(object)
        setAndTestAllOptionalProperties(optionalObject)
        try! realm.commitWrite()
    }

    func testIntSizes() {
        let realm = realmWithTestPath()

        let v8  = Int8(1)  << 6
        let v16 = Int16(1) << 12
        let v32 = Int32(1) << 30
        // 1 << 40 doesn't auto-promote to Int64 on 32-bit platforms
        let v64 = Int64(1) << 40
        try! realm.write {
            let obj = SwiftAllIntSizesObject()

            let testObject: () -> Void = {
                obj.objectSchema.properties.map { $0.name }.forEach { obj[$0] = 0 }

                obj["int8"] = NSNumber(value: v8)
                XCTAssertEqual((obj["int8"]! as! Int), Int(v8))
                obj["int16"] = NSNumber(value: v16)
                XCTAssertEqual((obj["int16"]! as! Int), Int(v16))
                obj["int32"] = NSNumber(value: v32)
                XCTAssertEqual((obj["int32"]! as! Int), Int(v32))
                obj["int64"] = NSNumber(value: v64)
                XCTAssertEqual((obj["int64"]! as! NSNumber), NSNumber(value: v64))

                obj.objectSchema.properties.map { $0.name }.forEach { obj[$0] = 0 }

                obj.setValue(NSNumber(value: v8), forKey: "int8")
                XCTAssertEqual((obj.value(forKey: "int8")! as! Int), Int(v8))
                obj.setValue(NSNumber(value: v16), forKey: "int16")
                XCTAssertEqual((obj.value(forKey: "int16")! as! Int), Int(v16))
                obj.setValue(NSNumber(value: v32), forKey: "int32")
                XCTAssertEqual((obj.value(forKey: "int32")! as! Int), Int(v32))
                obj.setValue(NSNumber(value: v64), forKey: "int64")
                XCTAssertEqual((obj.value(forKey: "int64")! as! NSNumber), NSNumber(value: v64))

                obj.objectSchema.properties.map { $0.name }.forEach { obj[$0] = 0 }

                obj.int8 = v8
                XCTAssertEqual(obj.int8, v8)
                obj.int16 = v16
                XCTAssertEqual(obj.int16, v16)
                obj.int32 = v32
                XCTAssertEqual(obj.int32, v32)
                obj.int64 = v64
                XCTAssertEqual(obj.int64, v64)
            }

            testObject()

            realm.add(obj)

            testObject()
        }

        let obj = realm.objects(SwiftAllIntSizesObject.self).first!
        XCTAssertEqual(obj.int8, v8)
        XCTAssertEqual(obj.int16, v16)
        XCTAssertEqual(obj.int32, v32)
        XCTAssertEqual(obj.int64, v64)
    }

    func testLongType() {
        let longNumber: Int64 = 17179869184
        let intNumber: Int64 = 2147483647
        let negativeLongNumber: Int64 = -17179869184
        let updatedLongNumber: Int64 = 8589934592

        let realm = realmWithTestPath()

        realm.beginWrite()
        realm.create(SwiftLongObject.self, value: [NSNumber(value: longNumber)])
        realm.create(SwiftLongObject.self, value: [NSNumber(value: intNumber)])
        realm.create(SwiftLongObject.self, value: [NSNumber(value: negativeLongNumber)])
        try! realm.commitWrite()

        let objects = realm.objects(SwiftLongObject.self)
        XCTAssertEqual(objects.count, Int(3), "3 rows expected")
        XCTAssertEqual(objects[0].longCol, longNumber, "2 ^ 34 expected")
        XCTAssertEqual(objects[1].longCol, intNumber, "2 ^ 31 - 1 expected")
        XCTAssertEqual(objects[2].longCol, negativeLongNumber, "-2 ^ 34 expected")

        realm.beginWrite()
        objects[0].longCol = updatedLongNumber
        try! realm.commitWrite()

        XCTAssertEqual(objects[0].longCol, updatedLongNumber, "After update: 2 ^ 33 expected")
    }

    func testListsDuringResultsFastEnumeration() {
        let realm = realmWithTestPath()

        let object1 = SwiftObject()
        let object2 = SwiftObject()

        let trueObject = SwiftBoolObject()
        trueObject.boolCol = true

        let falseObject = SwiftBoolObject()
        falseObject.boolCol = false

        object1.arrayCol.append(trueObject)
        object1.arrayCol.append(falseObject)

        object2.arrayCol.append(trueObject)
        object2.arrayCol.append(falseObject)

        try! realm.write {
            realm.add(object1)
            realm.add(object2)
        }

        let objects = realm.objects(SwiftObject.self)

        let firstObject = objects.first
        XCTAssertEqual(2, firstObject!.arrayCol.count)

        let lastObject = objects.last
        XCTAssertEqual(2, lastObject!.arrayCol.count)

        var iterator = objects.makeIterator()
        let next = iterator.next()!
        XCTAssertEqual(next.arrayCol.count, 2)

        for obj in objects {
            XCTAssertEqual(2, obj.arrayCol.count)
        }
    }

    func testSettingOptionalPropertyOnDeletedObjectsThrows() {
        let realm = try! Realm()
        try! realm.write {
            let obj = realm.create(SwiftOptionalObject.self)
            let copy = realm.objects(SwiftOptionalObject.self).first!
            realm.delete(obj)

            self.assertThrows(copy.optIntCol.value = 1)
            self.assertThrows(copy.optIntCol.value = nil)

            self.assertThrows(obj.optIntCol.value = 1)
            self.assertThrows(obj.optIntCol.value = nil)
        }
    }

    func setAndTestAllOptionalProperties(_ object: SwiftOptionalObject) {
        object.optNSStringCol = ""
        XCTAssertEqual(object.optNSStringCol!, "")
        let utf8TestString = "值значен™👍☞⎠‱௹♣︎☐▼❒∑⨌⧭иеمرحبا"
        object.optNSStringCol = utf8TestString as NSString?
        XCTAssertEqual(object.optNSStringCol! as String, utf8TestString)
        object.optNSStringCol = nil
        XCTAssertNil(object.optNSStringCol)

        object.optStringCol = ""
        XCTAssertEqual(object.optStringCol!, "")
        object.optStringCol = utf8TestString
        XCTAssertEqual(object.optStringCol!, utf8TestString)
        object.optStringCol = nil
        XCTAssertNil(object.optStringCol)

        let data = "b".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        object.optBinaryCol = data
        XCTAssertEqual(object.optBinaryCol!, data)
        object.optBinaryCol = nil
        XCTAssertNil(object.optBinaryCol)

        let date = Date(timeIntervalSinceReferenceDate: 2)
        object.optDateCol = date
        XCTAssertEqual(object.optDateCol!, date)
        object.optDateCol = nil
        XCTAssertNil(object.optDateCol)

        object.optIntCol.value = Int.min
        XCTAssertEqual(object.optIntCol.value!, Int.min)
        object.optIntCol.value = 0
        XCTAssertEqual(object.optIntCol.value!, 0)
        object.optIntCol.value = Int.max
        XCTAssertEqual(object.optIntCol.value!, Int.max)
        object.optIntCol.value = nil
        XCTAssertNil(object.optIntCol.value)

        object.optInt8Col.value = Int8.min
        XCTAssertEqual(object.optInt8Col.value!, Int8.min)
        object.optInt8Col.value = 0
        XCTAssertEqual(object.optInt8Col.value!, 0)
        object.optInt8Col.value = Int8.max
        XCTAssertEqual(object.optInt8Col.value!, Int8.max)
        object.optInt8Col.value = nil
        XCTAssertNil(object.optInt8Col.value)

        object.optInt16Col.value = Int16.min
        XCTAssertEqual(object.optInt16Col.value!, Int16.min)
        object.optInt16Col.value = 0
        XCTAssertEqual(object.optInt16Col.value!, 0)
        object.optInt16Col.value = Int16.max
        XCTAssertEqual(object.optInt16Col.value!, Int16.max)
        object.optInt16Col.value = nil
        XCTAssertNil(object.optInt16Col.value)

        object.optInt32Col.value = Int32.min
        XCTAssertEqual(object.optInt32Col.value!, Int32.min)
        object.optInt32Col.value = 0
        XCTAssertEqual(object.optInt32Col.value!, 0)
        object.optInt32Col.value = Int32.max
        XCTAssertEqual(object.optInt32Col.value!, Int32.max)
        object.optInt32Col.value = nil
        XCTAssertNil(object.optInt32Col.value)

        object.optInt64Col.value = Int64.min
        XCTAssertEqual(object.optInt64Col.value!, Int64.min)
        object.optInt64Col.value = 0
        XCTAssertEqual(object.optInt64Col.value!, 0)
        object.optInt64Col.value = Int64.max
        XCTAssertEqual(object.optInt64Col.value!, Int64.max)
        object.optInt64Col.value = nil
        XCTAssertNil(object.optInt64Col.value)

        object.optFloatCol.value = -Float.greatestFiniteMagnitude
        XCTAssertEqual(object.optFloatCol.value!, -Float.greatestFiniteMagnitude)
        object.optFloatCol.value = 0
        XCTAssertEqual(object.optFloatCol.value!, 0)
        object.optFloatCol.value = Float.greatestFiniteMagnitude
        XCTAssertEqual(object.optFloatCol.value!, Float.greatestFiniteMagnitude)
        object.optFloatCol.value = nil
        XCTAssertNil(object.optFloatCol.value)

        object.optDoubleCol.value = -Double.greatestFiniteMagnitude
        XCTAssertEqual(object.optDoubleCol.value!, -Double.greatestFiniteMagnitude)
        object.optDoubleCol.value = 0
        XCTAssertEqual(object.optDoubleCol.value!, 0)
        object.optDoubleCol.value = Double.greatestFiniteMagnitude
        XCTAssertEqual(object.optDoubleCol.value!, Double.greatestFiniteMagnitude)
        object.optDoubleCol.value = nil
        XCTAssertNil(object.optDoubleCol.value)

        object.optBoolCol.value = true
        XCTAssertEqual(object.optBoolCol.value!, true)
        object.optBoolCol.value = false
        XCTAssertEqual(object.optBoolCol.value!, false)
        object.optBoolCol.value = nil
        XCTAssertNil(object.optBoolCol.value)

        object.optObjectCol = SwiftBoolObject(value: [true])
        XCTAssertEqual(object.optObjectCol!.boolCol, true)
        object.optObjectCol = nil
        XCTAssertNil(object.optObjectCol)

        object.optRealmIntCol = RealmInteger(value: 20)
        XCTAssertEqual(object.optRealmIntCol?.value, 20)
        object.optRealmIntCol = nil
        XCTAssertNil(object.optRealmIntCol)
        object.optRealmIntCol = RealmInteger(value: 21)
        XCTAssertEqual(object.optRealmIntCol?.value, 21)
    }
}
