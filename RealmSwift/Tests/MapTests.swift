////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

class MapTests: TestCase {
    var str1: SwiftStringObject!
    var str2: SwiftStringObject!
    var realm: Realm!

    func createMap() -> Map<String, SwiftStringObject?> {
        fatalError("abstract")
    }

    func createEmbeddedMap() -> Map<String, EmbeddedTreeObject1?> {
        fatalError("abstract")
    }

    override func setUp() {
        super.setUp()

        let str1 = SwiftStringObject()
        str1.stringCol = "1"
        self.str1 = str1

        let str2 = SwiftStringObject()
        str2.stringCol = "2"
        self.str2 = str2

        realm = realmWithTestPath()
        try! realm.write {
            realm.add(str1)
            realm.add(str2)
        }
        realm.beginWrite()
    }

    override func tearDown() {
        if realm.isInWriteTransaction {
            realm.cancelWrite()
        }
        str1 = nil
        str2 = nil
        realm = nil
        super.tearDown()
    }

    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(MapTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func testPrimitive() {
        let obj = SwiftMapObject()
        obj.int["key"] = 5
        XCTAssertEqual(obj.int["key"]!, 5)
        XCTAssertNil(obj.int["doesntExist"])
        obj.int["keyB"] = 6
        obj.int["keyC"] = 7
        obj.int["keyD"] = 8
        XCTAssertEqual(obj.int.max(), 8)
        XCTAssertEqual(obj.int.min(), 5)
        XCTAssertEqual(obj.int.sum(), 26)
        XCTAssertEqual(obj.int.average(), 6.5)

        obj.string["key"] = "str"
        XCTAssertEqual(obj.string["key"], "str")
    }

    func testPrimitiveIterationAcrossNil() {
        let obj = SwiftMapObject()

        XCTAssertFalse(obj.int.contains(where: { $0 == "0" || $1 == 5 }))
        XCTAssertFalse(obj.int8.contains(where: { $0 == "0" || $1 == 5 }))
        XCTAssertFalse(obj.int16.contains(where: { $0 == "0" || $1 == 5 }))
        XCTAssertFalse(obj.int32.contains(where: { $0 == "0" || $1 == 5 }))
        XCTAssertFalse(obj.int64.contains(where: { $0 == "0" || $1 == 5 }))
        XCTAssertFalse(obj.float.contains(where: { $0 == "0" || $1 == 3.141592 }))
        XCTAssertFalse(obj.double.contains(where: { $0 == "0" || $1 == 3.141592 }))
        XCTAssertFalse(obj.string.contains(where: { $0 == "0" || $1 == "foobar" }))
        XCTAssertFalse(obj.data.contains(where: { $0 == "0" || $1 == Data() }))
        XCTAssertFalse(obj.date.contains(where: { $0 == "0" || $1 == Date() }))
        XCTAssertFalse(obj.decimal.contains(where: { $0 == "0" || $1 == Decimal128() }))
        XCTAssertFalse(obj.objectId.contains(where: { $0 == "0" || $1 == ObjectId() }))
        XCTAssertFalse(obj.uuid.contains(where: { $0 == "0" || $1 == UUID() }))
        XCTAssertFalse(obj.object.contains(where: { $0 == "0" || $1 == SwiftStringObject() }))

        XCTAssertFalse(obj.intOpt.contains { $1 == nil })
        XCTAssertFalse(obj.int8Opt.contains { $1 == nil })
        XCTAssertFalse(obj.int16Opt.contains { $1 == nil })
        XCTAssertFalse(obj.int32Opt.contains { $1 == nil })
        XCTAssertFalse(obj.int64Opt.contains { $1 == nil })
        XCTAssertFalse(obj.floatOpt.contains { $1 == nil })
        XCTAssertFalse(obj.doubleOpt.contains { $1 == nil })
        XCTAssertFalse(obj.stringOpt.contains { $1 == nil })
        XCTAssertFalse(obj.dataOpt.contains { $1 == nil })
        XCTAssertFalse(obj.dateOpt.contains { $1 == nil })
        XCTAssertFalse(obj.decimalOpt.contains { $1 == nil })
        XCTAssertFalse(obj.objectIdOpt.contains { $1 == nil })
        XCTAssertFalse(obj.uuidOpt.contains { $1 == nil })

        // Map also supports itteration through `SingleMapEntry` being the element.
        // We can't create this struct directly so we need to map over the contents of the dictionary
        // and test if that element exists.
        XCTAssertFalse(obj.int.map(obj.int.contains).contains(true))
        XCTAssertFalse(obj.int8.map(obj.int8.contains).contains(true))
        XCTAssertFalse(obj.int16.map(obj.int16.contains).contains(true))
        XCTAssertFalse(obj.int32.map(obj.int32.contains).contains(true))
        XCTAssertFalse(obj.int64.map(obj.int64.contains).contains(true))
        XCTAssertFalse(obj.float.map(obj.float.contains).contains(true))
        XCTAssertFalse(obj.double.map(obj.double.contains).contains(true))
        XCTAssertFalse(obj.string.map(obj.string.contains).contains(true))
        XCTAssertFalse(obj.data.map(obj.data.contains).contains(true))
        XCTAssertFalse(obj.date.map(obj.date.contains).contains(true))
        XCTAssertFalse(obj.decimal.map(obj.decimal.contains).contains(true))
        XCTAssertFalse(obj.objectId.map(obj.objectId.contains).contains(true))
        XCTAssertFalse(obj.uuid.map(obj.uuid.contains).contains(true))
        XCTAssertFalse(obj.object.map(obj.object.contains).contains(true))

        XCTAssertFalse(obj.intOpt.map(obj.intOpt.contains).contains(true))
        XCTAssertFalse(obj.int8Opt.map(obj.int8Opt.contains).contains(true))
        XCTAssertFalse(obj.int16Opt.map(obj.int16Opt.contains).contains(true))
        XCTAssertFalse(obj.int32Opt.map(obj.int32Opt.contains).contains(true))
        XCTAssertFalse(obj.int64Opt.map(obj.int64Opt.contains).contains(true))
        XCTAssertFalse(obj.floatOpt.map(obj.floatOpt.contains).contains(true))
        XCTAssertFalse(obj.doubleOpt.map(obj.doubleOpt.contains).contains(true))
        XCTAssertFalse(obj.stringOpt.map(obj.stringOpt.contains).contains(true))
        XCTAssertFalse(obj.dataOpt.map(obj.dataOpt.contains).contains(true))
        XCTAssertFalse(obj.dateOpt.map(obj.dateOpt.contains).contains(true))
        XCTAssertFalse(obj.decimalOpt.map(obj.decimalOpt.contains).contains(true))
        XCTAssertFalse(obj.objectIdOpt.map(obj.objectIdOpt.contains).contains(true))
        XCTAssertFalse(obj.uuidOpt.map(obj.uuidOpt.contains).contains(true))
    }

    func testInvalidated() {
        let mapObject = SwiftMapOfSwiftObject()
        realm.add(mapObject)
        XCTAssertFalse(mapObject.map.isInvalidated)

        if let realm = mapObject.realm {
            realm.delete(mapObject)
            XCTAssertTrue(mapObject.map.isInvalidated)
        }
    }

    func testFastEnumerationWithMutation() {
        let map = createMap()
        for i in 0...5 {
            map["key\(i)"] = str1
        }
        var str = ""

        for obj in map {
            str += obj.value!.stringCol
            map[obj.key] = str2
        }
        XCTAssertEqual(str, "111111")
    }

    func testMapDescription() {
        let map = createMap()
        for i in 0...5 {
            map["key\(i)"] = SwiftStringObject(value: [String(i)])
        }

        XCTAssertTrue(map.description.hasPrefix("Map<string, SwiftStringObject>"))
        XCTAssertTrue(map.description.contains("[key3]: SwiftStringObject {\n\t\tstringCol = 3;\n\t}"))
    }

    func testAppendObject() {
        let map = createMap()
        map["key1"] = str1
        map["key2"] = str2
        XCTAssertEqual(2, map.count)
        XCTAssertEqual("1", map["key1"]!!.stringCol)
        XCTAssertEqual("2", map["key2"]!!.stringCol)
    }

    func testInsert() {
        let map = createMap()
        XCTAssertEqual(0, map.count)

        XCTAssertNil(map[str1.stringCol] as Any?)
        map[str1.stringCol] = str1
        XCTAssertEqual(1, map.count)

        XCTAssertNil(map[str2.stringCol] as Any?)
        map[str2.stringCol] = str2
        XCTAssertEqual(2, map.count)
    }

    func testRemove() {
        let map = createMap()
        map[str1.stringCol] = str1
        XCTAssertEqual(1, map.count)
        XCTAssertNotNil(map[str1.stringCol] as Any?)

        map.removeObject(for: str1.stringCol)
        XCTAssertEqual(0, map.count)
        XCTAssertNil(map[str1.stringCol] as Any?)

        map[str1.stringCol] = str1
        XCTAssertEqual(1, map.count)
        XCTAssertNotNil(map[str1.stringCol] as Any?)

        map[str1.stringCol] = nil
        XCTAssertEqual(0, map.count)
        XCTAssertNil(map[str1.stringCol] as Any?)
    }

    func testRemoveAll() {
        let map = createMap()
        for i in 0..<5 {
            map[String(i)] = str1
        }
        XCTAssertEqual(5, map.count)
        map.removeAll()
        XCTAssertEqual(0, map.count)
    }

    func testDeleteObjectFromMap() {
        let map = createMap()
        if let realm = map.realm {
            map["key"] = str1
            XCTAssertEqual(map["key"]!!.stringCol, str1.stringCol)
            realm.delete(str1)
            XCTAssertNil(map["key"] ?? nil)
        }
    }

    func testMerge() {
        let map = createMap()
        map["a"] = str1

        map.merge(["b": str2], uniquingKeysWith: { (old, _) in
            XCTFail("combine called with no duplicates")
            return old
        })
        XCTAssertEqual(map.count, 2)
        XCTAssertTrue(str1.isSameObject(as: map["a"]!!))
        XCTAssertTrue(str2.isSameObject(as: map["b"]!!))

        // Does not actually update because the combine function picks the existing value
        map.merge(["b": str1], uniquingKeysWith: { (old, _) in
            return old
        })
        XCTAssertEqual(map.count, 2)
        XCTAssertTrue(str1.isSameObject(as: map["a"]!!))
        XCTAssertTrue(str2.isSameObject(as: map["b"]!!))

        // Does actually update
        map.merge(["b": str1], uniquingKeysWith: { (_, new) in
            return new
        })
        XCTAssertEqual(map.count, 2)
        XCTAssertTrue(str1.isSameObject(as: map["a"]!!))
        XCTAssertTrue(str1.isSameObject(as: map["b"]!!))

        // Creating an entirely new value is valid too
        map.merge(["a": str1], uniquingKeysWith: { (_, _) in
            return SwiftStringObject(value: ["c"])
        })
        XCTAssertEqual(map.count, 2)
        XCTAssertEqual(map["a"]!!.stringCol, "c")
        XCTAssertTrue(str1.isSameObject(as: map["b"]!!))
    }

    func testChangesArePersisted() {
        let map = createMap()
        map["key"] = str1
        map["key2"] = str2
        if let realm = map.realm {
            let mapFromResults = realm.objects(SwiftMapPropertyObject.self).first!.map
            XCTAssertEqual(map["key"]!!.stringCol, mapFromResults["key"]!!.stringCol)
            XCTAssertEqual(map["key2"]!!.stringCol, mapFromResults["key2"]!!.stringCol)
        }
    }

    func testPopulateEmptyMap() {
        let map = createMap()
        XCTAssertEqual(map.count, 0, "Should start with no array elements.")

        map["a"] = SwiftStringObject(value: ["a"])
        map["b"] = realmWithTestPath().create(SwiftStringObject.self, value: ["b"])
        map[str1.stringCol] = str1

        XCTAssertEqual(map.count, 3)
        XCTAssertEqual(map["a"]!!.stringCol, "a")
        XCTAssertEqual(map["b"]!!.stringCol, "b")
        XCTAssertEqual(map[str1.stringCol]!!.stringCol, str1.stringCol)

        var count = 0
        for object in map {
            XCTAssertTrue(object.key.description.utf16.count > 0, "Object should have description")
            XCTAssertTrue(object.value!.description.utf16.count > 0, "Object should have description")
            count += 1
        }
        XCTAssertEqual(count, 3)
    }

    func testEnumeratingMap() {
        let map = createMap()
        for i in 0..<10 {
            map["key\(i)"] = SwiftStringObject(value: ["key\(i)"])
        }

        XCTAssertEqual(10, map.count)

        var expected = Set((0..<10).map { "key\($0)" })
        for element in map {
            XCTAssertEqual(element.key, element.value!.stringCol)
            expected.remove(element.key)
        }
        XCTAssertEqual(expected.count, 0)

        expected = Set((0..<10).map { "key\($0)" })
        for (key, value) in map.asKeyValueSequence() {
            XCTAssertEqual(key, value!.stringCol)
            expected.remove(key)
        }
        XCTAssertEqual(expected.count, 0)
    }

    func testValueForKey() {
        let realm = try! Realm()
        try! realm.write {
            for value in [1, 2] {
                let mapObject = SwiftMapOfSwiftObject()
                let object = SwiftObject()
                object.intCol = value
                object.doubleCol = Double(value)
                object.stringCol = String(value)
                object.decimalCol = Decimal128(number: value as NSNumber)
                object.objectIdCol = try! ObjectId(string: String(repeating: String(value), count: 24))
                mapObject.map["key"] = object
                realm.add(mapObject)
            }
        }

        let mapObjects = realm.objects(SwiftMapOfSwiftObject.self)
        let mapsOfObjects = mapObjects.value(forKeyPath: "map") as! [Map<String, SwiftObject?>]
        let objects = realm.objects(SwiftObject.self)

        func testProperty<T: Equatable>(line: UInt = #line, fn: @escaping (SwiftObject?) -> T) {
            let properties: [T] = Array(mapObjects.flatMap {
                $0.map.values.map(fn)
            })
            let kvcProperties: [T] = Array(mapsOfObjects.flatMap { $0.values.map(fn) })
            XCTAssertEqual(properties, kvcProperties, line: line)
        }
        func testProperty<T: Equatable>(_ name: String, line: UInt = #line, fn: @escaping (SwiftObject?) -> T) {
            let properties = Array(objects.compactMap(fn))
            let mapsOfObjects = objects.value(forKeyPath: name) as! [T]
            let kvcProperties = Array(mapsOfObjects.compactMap { $0 })
            XCTAssertEqual(properties, kvcProperties, line: line)
        }

        testProperty { $0!.intCol }
        testProperty { $0!.doubleCol }
        testProperty { $0!.stringCol }
        testProperty { $0!.decimalCol }
        testProperty { $0!.objectIdCol }

        testProperty("intCol") { $0!.intCol }
        testProperty("doubleCol") { $0!.doubleCol }
        testProperty("stringCol") { $0!.stringCol }
        testProperty("decimalCol") { $0!.decimalCol }
        testProperty("objectIdCol") { $0!.objectIdCol }
    }

    @available(*, deprecated) // Silence deprecation warnings for RealmOptional
    func testValueForKeyOptional() {
        let realm = try! Realm()
        try! realm.write {
            for value in [1, 2] {
                let mapObject = SwiftMapOfSwiftOptionalObject()
                let object = SwiftOptionalObject()
                object.optIntCol.value = value
                object.optInt8Col.value = Int8(value)
                object.optDoubleCol.value = Double(value)
                object.optStringCol = String(value)
                object.optNSStringCol = NSString(format: "%d", value)
                object.optDecimalCol = Decimal128(number: value as NSNumber)
                object.optObjectIdCol = try! ObjectId(string: String(repeating: String(value), count: 24))
                mapObject.map["key"] = object
                realm.add(mapObject)
            }
        }

        let mapObjects = realm.objects(SwiftMapOfSwiftOptionalObject.self)
        let mapsOfObjects = mapObjects.value(forKeyPath: "map") as! [Map<String, SwiftOptionalObject?>]
        let objects = realm.objects(SwiftOptionalObject.self)

        func testProperty<T: Equatable>(line: UInt = #line, fn: @escaping (SwiftOptionalObject?) -> T) {
            let properties: [T] = mapObjects.flatMap { $0.map.values.map(fn) }
            let kvcProperties: [T] = mapsOfObjects.flatMap { $0.values.map(fn) }
            XCTAssertEqual(properties, kvcProperties, line: line)
        }
        func testProperty<T: Equatable>(_ name: String, line: UInt = #line, fn: @escaping (SwiftOptionalObject?) -> T) {
            let properties = Array(objects.compactMap(fn))
            let mapsOfObjects = objects.value(forKeyPath: name) as! [T]
            let kvcProperties = Array(mapsOfObjects.compactMap { $0 })
            XCTAssertEqual(properties, kvcProperties, line: line)
        }

        testProperty { $0!.optIntCol.value }
        testProperty { $0!.optInt8Col.value }
        testProperty { $0!.optDoubleCol.value }
        testProperty { $0!.optStringCol }
        testProperty { $0!.optNSStringCol }
        testProperty { $0!.optDecimalCol }
        testProperty { $0!.optObjectCol }

        testProperty("optIntCol") { $0!.optIntCol.value }
        testProperty("optInt8Col") { $0!.optInt8Col.value }
        testProperty("optDoubleCol") { $0!.optDoubleCol.value }
        testProperty("optStringCol") { $0!.optStringCol }
        testProperty("optNSStringCol") { $0!.optNSStringCol }
        testProperty("optDecimalCol") { $0!.optDecimalCol }
        testProperty("optObjectCol") { $0!.optObjectCol }
    }

    func testAppendEmbedded() {
        let map = createEmbeddedMap()
        for i in 0..<10 {
            map["\(i)"] = EmbeddedTreeObject1(value: [i])
        }
        XCTAssertEqual(10, map.count)

        for element in map {
            XCTAssertEqual(Int(element.key), element.value!.value)
            XCTAssertEqual(map.realm, element.value!.realm)
        }

        if map.realm != nil {
            // This message comes from Core and is incorrect for Dictionary.
            assertThrows((map["unassigned"] = map["0"]),
                         reason: "Cannot add an existing managed embedded object to a List.")
        }
        realm.cancelWrite()
    }

    func testSetEmbedded() {
        let map = createEmbeddedMap()
        map["key"] = EmbeddedTreeObject1(value: [0])

        let oldObj = map["key"]
        let obj = EmbeddedTreeObject1(value: [1])
        map["key"] = obj
        XCTAssertTrue(map["key"]!!.isSameObject(as: obj))
        XCTAssertEqual(obj.value, 1)
        XCTAssertEqual(obj.realm, map.realm)

        if map.realm != nil {
            XCTAssertTrue(oldObj!!.isInvalidated)
            assertThrows(map["key"] = obj,
                         reason: "Cannot add an existing managed embedded object to a List.")
        }

        realm.cancelWrite()
    }

    func testUnmanagedMapComparison() {
        let obj = SwiftIntObject()
        obj.intCol = 5
        let obj2 = SwiftIntObject()
        obj2.intCol = 6
        let obj3 = SwiftIntObject()
        obj3.intCol = 8

        let objects = ["obj": obj, "obj2": obj2, "obj3": obj3]
        let objects2 = ["obj": obj, "obj2": obj2]

        let map1 = Map<String, SwiftIntObject?>()
        let map2 = Map<String, SwiftIntObject?>()
        XCTAssertEqual(map1, map2, "Empty instances should be equal by `==` operator")

        map1.merge(objects) { (a, _) in a }
        map2.merge(objects) { (a, _) in a }

        let map3 = Map<String, SwiftIntObject?>()
        map3.merge(objects2) { (a, _) in a }

        XCTAssertTrue(map1 !== map2, "instances should not be identical")

        XCTAssertEqual(map1, map2, "instances should be equal by `==` operator")
        XCTAssertNotEqual(map1, map3, "instances should be equal by `==` operator")

        XCTAssertTrue(map1.isEqual(map2), "instances should be equal by `isEqual` method")
        XCTAssertTrue(!map1.isEqual(map3), "instances should be equal by `isEqual` method")

        map3["obj3"] = obj3
        XCTAssertEqual(map1, map3, "instances should be equal by `==` operator")

        XCTAssertEqual(Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map1),
                       Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map2),
                       "instances converted to Swift.Dictionary should be equal")
        XCTAssertEqual(Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map1),
                       Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map3),
                       "instances converted to Swift.Dictionary should be equal")
        map3["obj3"] = nil
        map1["obj3"] = nil
        XCTAssertEqual(Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map1),
                       Dictionary<String, SwiftIntObject?>(_immutableCocoaDictionary: map3),
                       "instances should be equal by `==` operator")
    }

    func testFilter() {
        let map = createMap()

        map["key"] = SwiftStringObject(value: ["apples"])
        map["key2"] = SwiftStringObject(value: ["bananas"])
        map["key3"] = SwiftStringObject(value: ["cockroach"])

        if map.realm != nil {
            let results: Results<SwiftStringObject?> = map.filter(NSPredicate(format: "stringCol = 'apples'"))
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first!!.stringCol, "apples")

            let results2: Results<SwiftStringObject?> = map.sorted(byKeyPath: "stringCol", ascending: true)
            XCTAssertEqual(results2.count, 3)
            XCTAssertEqual(results2[0]!.stringCol, "apples")
            XCTAssertEqual(results2[1]!.stringCol, "bananas")
            XCTAssertEqual(results2[2]!.stringCol, "cockroach")
        } else {
            assertThrows(map.filter(NSPredicate(format: "stringCol = 'apples'")))
            assertThrows(map.sorted(byKeyPath: "stringCol", ascending: false))
        }
    }

    func testKeyedSortable() {
        let map = createMap()

        map["key"] = SwiftStringObject(value: ["apples"])
        map["key2"] = SwiftStringObject(value: ["bananas"])
        map["key3"] = SwiftStringObject(value: ["cockroach"])

        if map.realm != nil {
            let results2: Results<SwiftStringObject?> = map.sorted(by: \.stringCol,
                                                                   ascending: true)
            XCTAssertEqual(results2.count, 3)
            XCTAssertEqual(results2[0]?.stringCol, "apples")
            XCTAssertEqual(results2[1]?.stringCol, "bananas")
            XCTAssertEqual(results2[2]?.stringCol, "cockroach")
        } else {
            assertThrows(map.sorted(by: \.stringCol, ascending: true))
        }
    }

    func testKeyedAggregatable() {
        let map = SwiftMapPropertyObject()
        map.intMap["key"] = SwiftIntObject(value: [1])
        map.intMap["key2"] = SwiftIntObject(value: [2])
        map.intMap["key3"] = SwiftIntObject(value: [3])

        func assertAggregations() {
            let min = map.intMap.min(of: \.intCol)
            let max = map.intMap.max(of: \.intCol)
            let sum = map.intMap.sum(of: \.intCol)
            let avg = map.intMap.average(of: \.intCol)
            XCTAssertEqual(min, 1)
            XCTAssertEqual(max, 3)
            XCTAssertEqual(sum, 6)
            XCTAssertEqual(avg, 2)
        }
        // unmanaged
        assertAggregations()
        realm.add(map)
        try! realm.commitWrite()
        // managed
        assertAggregations()
    }

    func testAllKeysQuery() {
        let map = createMap()
        if let realm = map.realm {
            func test<T: RealmCollectionValue>(on key: String, value: T) {
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys = 'aKey'").count, 0)
                let o = SwiftMapObject()
                (o.value(forKey: key) as! Map<String, T>)["aKey"] = value
                let o2 = SwiftMapObject()
                (o2.value(forKey: key) as! Map<String, T>)["aKey2"] = value
                let o3 = SwiftMapObject()
                (o3.value(forKey: key) as! Map<String, T>)["aKey3"] = value
                let o4 = SwiftMapObject()
                // this object should be visible from `ANY \(key).@allKeys != 'aKey'`
                // as the dictionary contains more than one key.
                (o4.value(forKey: key) as! Map<String, T>)["aKey"] = value
                (o4.value(forKey: key) as! Map<String, T>)["aKey4"] = value
                realm.add([o, o2, o3, o4])

                XCTAssertEqual(realm.objects(SwiftMapObject.self).count, 4)
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys = 'aKey'").count, 2)
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys != 'aKey'").count, 3)

                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys =[c] 'akey'").count, 2)
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys !=[c] 'akey'").count, 3)

                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys =[cd] 'akéy'").count, 2)
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allKeys !=[cd] 'akéy'").count, 3)

                realm.delete([o, o2, o3, o4])
            }

            test(on: "int", value: Int(123))
            test(on: "int8", value: Int8(127))
            test(on: "int16", value: Int16(789))
            test(on: "int32", value: Int32(789))
            test(on: "int64", value: Int64(789))
            test(on: "float", value: Float(789.123))
            test(on: "double", value: Double(789.123))
            test(on: "string", value: "Hello")
            test(on: "data", value: Data(count: 16))
            test(on: "date", value: Date())
            test(on: "decimal", value: Decimal128(floatLiteral: 123.456))
            test(on: "objectId", value: ObjectId())
            test(on: "uuid", value: UUID())
            test(on: "object", value: Optional<SwiftStringObject>(SwiftStringObject(value: ["hello"])))
        }
    }

    func testAllValuesQuery() {
        let map = createMap()
        if let realm = map.realm {
            func test<T: RealmCollectionValue>(on key: String, values: T...) {
                XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues = %@", values[0]).count, 0)
                let o = SwiftMapObject()
                (o.value(forKey: key) as! Map<String, T>)["aKey"] = values[0]
                let o2 = SwiftMapObject()
                (o2.value(forKey: key) as! Map<String, T>)["aKey2"] = values[1]
                let o3 = SwiftMapObject()
                (o3.value(forKey: key) as! Map<String, T>)["aKey3"] = values[2]
                realm.add([o, o2, o3])

                if T.self is Object.Type {
                    let stringObj = realm.objects(SwiftStringObject.self).filter("stringCol == 'hello'").first!
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues = %@", stringObj).count, 1)
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues != %@", stringObj).count, 2)
                } else {
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).count, 3)
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues = %@", values[0]).count, 1)
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues != %@", values[0]).count, 2)
                }

                if T.self is String.Type {
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues =[c] %@", values[0]).count, 2)
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues !=[c] %@", values[0]).count, 1)

                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues =[cd] %@", values[0]).count, 3)
                    XCTAssertEqual(realm.objects(SwiftMapObject.self).filter("ANY \(key).@allValues !=[cd] %@", values[0]).count, 0)
                }
                realm.delete([o, o2, o3])
            }

            test(on: "int", values: Int(123), Int(456), Int(789))
            test(on: "int8", values: Int8(127), Int8(0), Int8(64))
            test(on: "int16", values: Int16(789), Int16(345), Int16(567))
            test(on: "int32", values: Int32(789), Int32(132), Int32(345))
            test(on: "int64", values: Int64(789), Int64(234), Int64(345))
            test(on: "float", values: Float(789.123), Float(123.123), Float(234.123))
            test(on: "double", values: Double(789.123), Double(123.123), Double(234.123))
            test(on: "string", values: "Hello", "Héllo", "hello")
            test(on: "data", values: Data(count: 16), Data(count: 32), Data(count: 64))
            test(on: "date",
                 values: Date(timeIntervalSince1970: 2000),
                 Date(timeIntervalSince1970: 4000),
                 Date(timeIntervalSince1970: 8000))
            test(on: "decimal", values: Decimal128(floatLiteral: 123.456), Decimal128(floatLiteral: 234.456), Decimal128(floatLiteral: 345.456))
            test(on: "objectId",
                 values: ObjectId("507f1f77bcf86cd799439011"),
                 ObjectId("507f1f77bcf86cd799439012"),
                 ObjectId("507f1f77bcf86cd799439013"))
            test(on: "uuid",
                 values: UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD89")!,
                 UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD88")!,
                 UUID(uuidString: "137DECC8-B300-4954-A233-F89909F4FD87")!)
            test(on: "object",
                 values: Optional<SwiftStringObject>(SwiftStringObject(value: ["hello"])),
                 Optional<SwiftStringObject>(SwiftStringObject(value: ["there"])),
                 Optional<SwiftStringObject>(SwiftStringObject(value: ["bye"])))
        }
    }
}

class MapStandaloneTests: MapTests {
    override func createMap() -> Map<String, SwiftStringObject?> {
        let mapObj = SwiftMapPropertyObject()
        XCTAssertNil(mapObj.realm)
        return mapObj.map
    }

    override func createEmbeddedMap() -> Map<String, EmbeddedTreeObject1?> {
        return Map<String, EmbeddedTreeObject1?>()
    }
}

class MapNewlyAddedTests: MapTests {
    override func createMap() -> Map<String, SwiftStringObject?> {
        let mapObj = SwiftMapPropertyObject()
        realm.add(mapObj)
        XCTAssertNotNil(mapObj.realm)
        return mapObj.map
    }

    override func createEmbeddedMap() -> Map<String, EmbeddedTreeObject1?> {
        let parent = EmbeddedParentObject()
        let map = parent.map
        realm.add(parent)
        return map
    }
}

class MapNewlyCreatedTests: MapTests {
    override func createMap() -> Map<String, SwiftStringObject?> {
        let mapObj = realm.create(SwiftMapPropertyObject.self, value: ["name", [], []])
        try! realm.commitWrite()
        realm.beginWrite()
        XCTAssertNotNil(mapObj.realm)
        return mapObj.map
    }

    override func createEmbeddedMap() -> Map<String, EmbeddedTreeObject1?> {
        return realm.create(EmbeddedParentObject.self, value: []).map
    }
}

class MapRetrievedTests: MapTests {
    override func createMap() -> Map<String, SwiftStringObject?> {
        realm.create(SwiftMapPropertyObject.self, value: ["name", [:], [:]])
        try! realm.commitWrite()
        let mapObj = realm.objects(SwiftMapPropertyObject.self).first!

        XCTAssertNotNil(mapObj.realm)
        realm.beginWrite()
        return mapObj.map
    }

    override func createEmbeddedMap() -> Map<String, EmbeddedTreeObject1?> {
        realm.create(EmbeddedParentObject.self, value: [])
        return realm.objects(EmbeddedParentObject.self).first!.map
    }
}

class MapNotificationTests: TestCase {
    func testNotificationSentInitially() {
        let realm = realmWithTestPath()
        realm.beginWrite()
        let mapObj = realm.create(SwiftMapPropertyObject.self)
        try! realm.commitWrite()
        let queue = DispatchQueue(label: "testNotificationSentInitially", autoreleaseFrequency: .workItem)
        let exp = expectation(description: "does receive notification")
        let token = mapObj.map.observe(on: queue) { change in
            switch change {
            case .initial(let map):
                XCTAssertNotNil(map)
                exp.fulfill()
            case .update(_, deletions: _, insertions: _, modifications: _):
                XCTFail("should not get here for this test")
            case .error(_):
                XCTFail("should not get here for this test")
            }
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        token.invalidate()
        queue.sync { }
    }

    func testNotificationSentAfterCommit() {
        let realm = realmWithTestPath()
        realm.beginWrite()
        let mapObj = realm.create(SwiftMapPropertyObject.self)
        try! realm.commitWrite()
        let queue = DispatchQueue(label: "testNotificationSentAfterCommit", autoreleaseFrequency: .workItem)
        var exp = expectation(description: "does receive notification")
        var didInsert = false
        var didModify = false
        var didDelete = false
        let token = mapObj.map.observe(on: queue) { change in
            switch change {
            case .initial(let map):
                XCTAssertNotNil(map)
                exp.fulfill()
            case let .update(map, deletions: deletions, insertions: insertions, modifications: modifications):
                XCTAssertNotNil(map)
                if didModify && !didDelete {
                    XCTAssertEqual(deletions, ["myNewKey"])
                    didDelete.toggle()
                } else if didInsert {
                    XCTAssertEqual(modifications, ["myNewKey"])
                    didModify.toggle()
                } else {
                    XCTAssertEqual(insertions, ["anotherNewKey", "myNewKey"])
                    didInsert.toggle()
                }
                exp.fulfill()
            case .error(_):
                XCTFail("should not get here for this test")
            }
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        exp = expectation(description: "does receive notification")
        try! realm.write {
            mapObj.map["myNewKey"] = SwiftStringObject(value: ["one"])
            mapObj.map["anotherNewKey"] = SwiftStringObject(value: ["two"])
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        XCTAssertTrue(didInsert)

        exp = expectation(description: "does receive notification")
        try! realm.write {
            mapObj.map["myNewKey"] = SwiftStringObject(value: ["three"])
        }
        waitForExpectations(timeout: 2.0, handler: nil)

        exp = expectation(description: "does receive notification")
        XCTAssertTrue(didModify)
        try! realm.write {
            mapObj.map["myNewKey"] = nil
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        XCTAssertTrue(didDelete)

        token.invalidate()
        queue.sync { }
    }
}
