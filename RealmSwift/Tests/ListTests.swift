////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
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

class ListTests: TestCase {
    var str1: SwiftStringObject?
    var str2: SwiftStringObject?
    var arrayObject: SwiftArrayPropertyObject!
    var array: List<SwiftStringObject>?

    func createArray() -> SwiftArrayPropertyObject {
        fatalError("abstract")
    }

    func createArrayWithLinks() -> SwiftListOfSwiftObject {
        fatalError("abstract")
    }

    func createEmbeddedArray() -> List<EmbeddedTreeObject1> {
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

        arrayObject = createArray()
        array = arrayObject.array

        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(str1)
            realm.add(str2)
        }

        realm.beginWrite()
    }

    override func tearDown() {
        try! realmWithTestPath().commitWrite()

        str1 = nil
        str2 = nil
        arrayObject = nil
        array = nil

        super.tearDown()
    }

    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(ListTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func testPrimitive() {
        let obj = SwiftListObject()
        obj.int.append(5)
        XCTAssertEqual(obj.int.first!, 5)
        XCTAssertEqual(obj.int.last!, 5)
        XCTAssertEqual(obj.int[0], 5)
        obj.int.append(objectsIn: [6, 7, 8] as [Int])
        XCTAssertEqual(obj.int.index(of: 6), 1)
        XCTAssertEqual(2, obj.int.index(matching: NSPredicate(format: "self == 7")))
        XCTAssertNil(obj.int.index(matching: NSPredicate(format: "self == 9")))
        XCTAssertEqual(obj.int.max(), 8)
        XCTAssertEqual(obj.int.sum(), 26)

        obj.string.append("str")
        XCTAssertEqual(obj.string.first!, "str")
        XCTAssertEqual(obj.string[0], "str")
    }

    func testPrimitiveIterationAcrossNil() {
        let obj = SwiftListObject()
        XCTAssertFalse(obj.int.contains(5))
        XCTAssertFalse(obj.int8.contains(5))
        XCTAssertFalse(obj.int16.contains(5))
        XCTAssertFalse(obj.int32.contains(5))
        XCTAssertFalse(obj.int64.contains(5))
        XCTAssertFalse(obj.float.contains(3.141592))
        XCTAssertFalse(obj.double.contains(3.141592))
        XCTAssertFalse(obj.string.contains("foobar"))
        XCTAssertFalse(obj.data.contains(Data()))
        XCTAssertFalse(obj.date.contains(Date()))
        XCTAssertFalse(obj.decimal.contains(Decimal128()))
        XCTAssertFalse(obj.objectId.contains(ObjectId()))
        XCTAssertFalse(obj.uuidOpt.contains(UUID()))

        XCTAssertFalse(obj.intOpt.contains { $0 == nil })
        XCTAssertFalse(obj.int8Opt.contains { $0 == nil })
        XCTAssertFalse(obj.int16Opt.contains { $0 == nil })
        XCTAssertFalse(obj.int32Opt.contains { $0 == nil })
        XCTAssertFalse(obj.int64Opt.contains { $0 == nil })
        XCTAssertFalse(obj.floatOpt.contains { $0 == nil })
        XCTAssertFalse(obj.doubleOpt.contains { $0 == nil })
        XCTAssertFalse(obj.stringOpt.contains { $0 == nil })
        XCTAssertFalse(obj.dataOpt.contains { $0 == nil })
        XCTAssertFalse(obj.dateOpt.contains { $0 == nil })
        XCTAssertFalse(obj.decimalOpt.contains { $0 == nil })
        XCTAssertFalse(obj.objectIdOpt.contains { $0 == nil })
        XCTAssertFalse(obj.uuidOpt.contains { $0 == nil })
    }

    func testInvalidated() {
        guard let array = array else {
            fatalError("Test precondition failure")
        }
        XCTAssertFalse(array.isInvalidated)

        if let realm = arrayObject.realm {
            realm.delete(arrayObject)
            XCTAssertTrue(array.isInvalidated)
        }
    }

    func testFastEnumerationWithMutation() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2, str1, str2, str1, str2, str1, str2, str1,
            str2, str1, str2, str1, str2, str1, str2, str1, str2, str1, str2])
        var str = ""
        for obj in array {
            str += obj.stringCol
            array.append(objectsIn: [str1])
        }

        XCTAssertEqual(str, "12121212121212121212")
    }

    func testAppendObject() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }
        for str in [str1, str2, str1] {
            array.append(str)
        }
        XCTAssertEqual(Int(3), array.count)
        assertEqual(str1, array[0])
        assertEqual(str2, array[1])
        assertEqual(str1, array[2])
    }

    func testAppendArray() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }
        array.append(objectsIn: [str1, str2, str1])
        XCTAssertEqual(Int(3), array.count)
        assertEqual(str1, array[0])
        assertEqual(str2, array[1])
        assertEqual(str1, array[2])
    }

    func testAppendResults() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }
        array.append(objectsIn: realmWithTestPath().objects(SwiftStringObject.self))
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str1, array[0])
        assertEqual(str2, array[1])
    }

    func testInsert() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        XCTAssertEqual(Int(0), array.count)

        array.insert(str1, at: 0)
        XCTAssertEqual(Int(1), array.count)
        assertEqual(str1, array[0])

        array.insert(str2, at: 0)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str1, array[1])

        assertThrows(array.insert(str2, at: 200))
        assertThrows(array.insert(str2, at: -200))
    }

    func testRemoveAtIndex() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2, str1])

        array.remove(at: 1)
        assertEqual(str1, array[0])
        assertEqual(str1, array[1])

        assertThrows(array.remove(at: 2))
        assertThrows(array.remove(at: -2))
    }

    func testRemoveLast() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2])

        array.removeLast()
        XCTAssertEqual(Int(1), array.count)
        assertEqual(str1, array[0])

        array.removeLast()
        XCTAssertEqual(Int(0), array.count)

        assertThrows(array.removeLast())    // Should throw if already empty
    }

    func testRemoveAll() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2])

        array.removeAll()
        XCTAssertEqual(Int(0), array.count)

        array.removeAll() // should be a no-op
        XCTAssertEqual(Int(0), array.count)
    }

    func testReplace() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str1])

        array.replace(index: 0, object: str2)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str1, array[1])

        array.replace(index: 1, object: str2)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str2, array[1])

        assertThrows(array.replace(index: 200, object: str2))
        assertThrows(array.replace(index: -200, object: str2))
    }

    func testMove() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2])

        array.move(from: 1, to: 0)

        XCTAssertEqual(array[0].stringCol, "2")
        XCTAssertEqual(array[1].stringCol, "1")

        array.move(from: 0, to: 1)

        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "2")

        array.move(from: 0, to: 0)

        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "2")

        assertThrows(array.move(from: 0, to: 2))
        assertThrows(array.move(from: 2, to: 0))
    }

    func testMoveFromOffsets() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }
        let str3 = SwiftStringObject(value: ["3"])

        array.append(objectsIn: [str1, str2, str3])

        array.move(fromOffsets: IndexSet([1]), toOffset: 0)
        // [2, 1, 3]
        XCTAssertEqual(array[0].stringCol, "2")
        XCTAssertEqual(array[1].stringCol, "1")
        XCTAssertEqual(array[2].stringCol, "3")

        array.move(fromOffsets: IndexSet([0]), toOffset: 3)
        // [1, 3, 2]
        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "3")
        XCTAssertEqual(array[2].stringCol, "2")

        array.move(fromOffsets: IndexSet([0]), toOffset: 0)
        // [1, 3, 2]
        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "3")
        XCTAssertEqual(array[2].stringCol, "2")

        array.move(fromOffsets: IndexSet([2]), toOffset: 1)
        // [1, 2, 3]
        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "2")
        XCTAssertEqual(array[2].stringCol, "3")

        assertThrows(array.move(fromOffsets: IndexSet([0]), toOffset: 4))
        assertThrows(array.move(fromOffsets: IndexSet([4]), toOffset: 0))

        array.move(fromOffsets: IndexSet([]), toOffset: 1)
        // [1, 2, 3]
        XCTAssertEqual(array[0].stringCol, "1")
        XCTAssertEqual(array[1].stringCol, "2")
        XCTAssertEqual(array[2].stringCol, "3")

        array.move(fromOffsets: IndexSet([0, 2]), toOffset: 1)
        // [2, 3, 1]
        XCTAssertEqual(array[0].stringCol, "2")
        XCTAssertEqual(array[1].stringCol, "3")
        XCTAssertEqual(array[2].stringCol, "1")
    }

    func testReplaceRange() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str1])

        array.replaceSubrange(0..<1, with: [str2])
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str1, array[1])

        array.replaceSubrange(1..<2, with: [str2])
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str2, array[1])

        array.replaceSubrange(0..<0, with: [str2])
        XCTAssertEqual(Int(3), array.count)
        assertEqual(str2, array[0])
        assertEqual(str2, array[1])
        assertEqual(str2, array[2])

        array.replaceSubrange(0..<3, with: [])
        XCTAssertEqual(Int(0), array.count)

        assertThrows(array.replaceSubrange(200..<201, with: [str2]))
        assertThrows(array.replaceSubrange(-200..<200, with: [str2]))
        assertThrows(array.replaceSubrange(0..<200, with: [str2]))
    }

    func testSwapAt() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }

        array.append(objectsIn: [str1, str2])

        array.swapAt(0, 1)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str1, array[1])

        array.swapAt(1, 1)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(str2, array[0])
        assertEqual(str1, array[1])

        assertThrows(array.swapAt(-1, 0))
        assertThrows(array.swapAt(0, -1))
        assertThrows(array.swapAt(1000, 0))
        assertThrows(array.swapAt(0, 1000))
    }

    func testChangesArePersisted() {
        guard let array = array, let str1 = str1, let str2 = str2 else {
            fatalError("Test precondition failure")
        }
        if let realm = array.realm {
            array.append(objectsIn: [str1, str2])

            let otherArray = realm.objects(SwiftArrayPropertyObject.self).first!.array
            XCTAssertEqual(Int(2), otherArray.count)
        }
    }

    func testPopulateEmptyArray() {
        guard let array = array else {
            fatalError("Test precondition failure")
        }

        XCTAssertEqual(array.count, 0, "Should start with no array elements.")

        let obj = SwiftStringObject()
        obj.stringCol = "a"
        array.append(obj)
        array.append(realmWithTestPath().create(SwiftStringObject.self, value: ["b"]))
        array.append(obj)

        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0].stringCol, "a")
        XCTAssertEqual(array[1].stringCol, "b")
        XCTAssertEqual(array[2].stringCol, "a")

        // Make sure we can enumerate
        for obj in array {
            XCTAssertTrue(obj.description.utf16.count > 0, "Object should have description")
        }
    }

    func testEnumeratingListWithListProperties() {
        let arrayObject = createArrayWithLinks()

        arrayObject.realm?.beginWrite()
        for _ in 0..<10 {
            arrayObject.array.append(SwiftObject())
        }
        try! arrayObject.realm?.commitWrite()

        XCTAssertEqual(10, arrayObject.array.count)

        for object in arrayObject.array {
            XCTAssertEqual(123, object.intCol)
            XCTAssertEqual(false, object.objectCol!.boolCol)
            XCTAssertEqual(0, object.arrayCol.count)
        }
    }

    func testValueForKey() {
        let realm = try! Realm()
        try! realm.write {
            for value in [1, 2] {
                let listObject = SwiftListOfSwiftObject()
                let object = SwiftObject()
                object.intCol = value
                object.doubleCol = Double(value)
                object.stringCol = String(value)
                object.decimalCol = Decimal128(number: value as NSNumber)
                object.objectIdCol = try! ObjectId(string: String(repeating: String(value), count: 24))
                listObject.array.append(object)
                realm.add(listObject)
            }
        }

        let listObjects = realm.objects(SwiftListOfSwiftObject.self)
        let listsOfObjects = listObjects.value(forKeyPath: "array") as! [List<SwiftObject>]
        let objects = realm.objects(SwiftObject.self)

        func testProperty<T: Equatable>(line: UInt = #line, fn: @escaping (SwiftObject) -> T) {
            let properties: [T] = Array(listObjects.flatMap { $0.array.map(fn) })
            let kvcProperties: [T] = Array(listsOfObjects.flatMap { $0.map(fn) })
            XCTAssertEqual(properties, kvcProperties, line: line)
        }
        func testProperty<T: Equatable>(_ name: String, line: UInt = #line, fn: @escaping (SwiftObject) -> T) {
            let properties = Array(objects.compactMap(fn))
            let listsOfObjects = objects.value(forKeyPath: name) as! [T]
            let kvcProperties = Array(listsOfObjects.compactMap { $0 })

            XCTAssertEqual(properties, kvcProperties, line: line)
        }

        testProperty { $0.intCol }
        testProperty { $0.doubleCol }
        testProperty { $0.stringCol }
        testProperty { $0.decimalCol }
        testProperty { $0.objectIdCol }

        testProperty("intCol") { $0.intCol }
        testProperty("doubleCol") { $0.doubleCol }
        testProperty("stringCol") { $0.stringCol }
        testProperty("decimalCol") { $0.decimalCol }
        testProperty("objectIdCol") { $0.objectIdCol }
    }

    @available(*, deprecated) // Silence deprecation warnings for RealmOptional
    func testValueForKeyOptional() {
        let realm = try! Realm()
        try! realm.write {
            for value in [1, 2] {
                let listObject = SwiftListOfSwiftOptionalObject()
                let object = SwiftOptionalObject()
                object.optIntCol.value = value
                object.optInt8Col.value = Int8(value)
                object.optDoubleCol.value = Double(value)
                object.optStringCol = String(value)
                object.optNSStringCol = NSString(format: "%d", value)
                object.optDecimalCol = Decimal128(number: value as NSNumber)
                object.optObjectIdCol = try! ObjectId(string: String(repeating: String(value), count: 24))
                listObject.array.append(object)
                realm.add(listObject)
            }
        }

        let listObjects = realm.objects(SwiftListOfSwiftOptionalObject.self)
        let listsOfObjects = listObjects.value(forKeyPath: "array") as! [List<SwiftOptionalObject>]
        let objects = realm.objects(SwiftOptionalObject.self)

        func testProperty<T: Equatable>(line: UInt = #line, fn: @escaping (SwiftOptionalObject) -> T) {
            let properties: [T] = Array(listObjects.flatMap { $0.array.map(fn) })
            let kvcProperties: [T] = Array(listsOfObjects.flatMap { $0.map(fn) })
            XCTAssertEqual(properties, kvcProperties, line: line)
        }
        func testProperty<T: Equatable>(_ name: String, line: UInt = #line, fn: @escaping (SwiftOptionalObject) -> T) {
            let properties = Array(objects.compactMap(fn))
            let listsOfObjects = objects.value(forKeyPath: name) as! [T]
            let kvcProperties = Array(listsOfObjects.compactMap { $0 })

            XCTAssertEqual(properties, kvcProperties, line: line)
        }

        testProperty { $0.optIntCol.value }
        testProperty { $0.optInt8Col.value }
        testProperty { $0.optDoubleCol.value }
        testProperty { $0.optStringCol }
        testProperty { $0.optNSStringCol }
        testProperty { $0.optDecimalCol }
        testProperty { $0.optObjectCol }

        testProperty("optIntCol") { $0.optIntCol.value }
        testProperty("optInt8Col") { $0.optInt8Col.value }
        testProperty("optDoubleCol") { $0.optDoubleCol.value }
        testProperty("optStringCol") { $0.optStringCol }
        testProperty("optNSStringCol") { $0.optNSStringCol }
        testProperty("optDecimalCol") { $0.optDecimalCol }
        testProperty("optObjectCol") { $0.optObjectCol }
    }

    func testAppendEmbedded() {
        let list = createEmbeddedArray()

        list.realm?.beginWrite()
        for i in 0..<10 {
            list.append(EmbeddedTreeObject1(value: [i]))
        }
        XCTAssertEqual(10, list.count)

        for (i, object) in list.enumerated() {
            XCTAssertEqual(i, object.value)
            XCTAssertEqual(list.realm, object.realm)
        }

        if list.realm != nil {
            assertThrows(list.append(list[0]),
                         reason: "Cannot add an existing managed embedded object to a List.")
        }

        list.realm?.cancelWrite()
    }

    func testSetEmbedded() {
        let list = createEmbeddedArray()

        list.realm?.beginWrite()
        list.append(EmbeddedTreeObject1(value: [0]))

        let oldObj = list[0]
        let obj = EmbeddedTreeObject1(value: [1])
        list[0] = obj
        XCTAssertTrue(list[0].isSameObject(as: obj))
        XCTAssertEqual(obj.value, 1)
        XCTAssertEqual(obj.realm, list.realm)

        if list.realm != nil {
            XCTAssertTrue(oldObj.isInvalidated)
            assertThrows(list[0] = obj,
                         reason: "Cannot add an existing managed embedded object to a List.")
        }

        list.realm?.cancelWrite()
    }

    func testUnmanagedListComparison() {
        let obj = SwiftIntObject()
        obj.intCol = 5
        let obj2 = SwiftIntObject()
        obj2.intCol = 6
        let obj3 = SwiftIntObject()
        obj3.intCol = 8

        let objects = [obj, obj2, obj3]
        let objects2 = [obj, obj2]

        let list1 = List<SwiftIntObject>()
        let list2 = List<SwiftIntObject>()
        XCTAssertEqual(list1, list2, "Empty instances should be equal by `==` operator")

        list1.append(objectsIn: objects)
        list2.append(objectsIn: objects)

        let list3 = List<SwiftIntObject>()
        list3.append(objectsIn: objects2)

        XCTAssertTrue(list1 !== list2, "instances should not be identical")

        XCTAssertEqual(list1, list2, "instances should be equal by `==` operator")
        XCTAssertNotEqual(list1, list3, "instances should be equal by `==` operator")

        XCTAssertTrue(list1.isEqual(list2), "instances should be equal by `isEqual` method")
        XCTAssertTrue(!list1.isEqual(list3), "instances should be equal by `isEqual` method")

        XCTAssertEqual(Array(list1), Array(list2), "instances converted to Swift.Array should be equal")
        XCTAssertNotEqual(Array(list1), Array(list3), "instances converted to Swift.Array should be equal")
        list3.append(obj3)
        XCTAssertEqual(list1, list3, "instances should be equal by `==` operator")
    }
}

class ListStandaloneTests: ListTests {
    override func createArray() -> SwiftArrayPropertyObject {
        let array = SwiftArrayPropertyObject()
        XCTAssertNil(array.realm)
        return array
    }

    override func createArrayWithLinks() -> SwiftListOfSwiftObject {
        let array = SwiftListOfSwiftObject()
        XCTAssertNil(array.realm)
        return array
    }

    override func createEmbeddedArray() -> List<EmbeddedTreeObject1> {
        return List<EmbeddedTreeObject1>()
    }
}

class ListNewlyAddedTests: ListTests {
    override func createArray() -> SwiftArrayPropertyObject {
        let array = SwiftArrayPropertyObject()
        array.name = "name"
        let realm = realmWithTestPath()
        try! realm.write { realm.add(array) }

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createArrayWithLinks() -> SwiftListOfSwiftObject {
        let array = SwiftListOfSwiftObject()
        let realm = try! Realm()
        try! realm.write { realm.add(array) }

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createEmbeddedArray() -> List<EmbeddedTreeObject1> {
        let parent = EmbeddedParentObject()
        let list = parent.array
        let realm = try! Realm()
        try! realm.write { realm.add(parent) }
        return list
    }
}

class ListNewlyCreatedTests: ListTests {
    override func createArray() -> SwiftArrayPropertyObject {
        let realm = realmWithTestPath()
        realm.beginWrite()
        let array = realm.create(SwiftArrayPropertyObject.self, value: ["name", [], []])
        try! realm.commitWrite()

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createArrayWithLinks() -> SwiftListOfSwiftObject {
        let realm = try! Realm()
        realm.beginWrite()
        let array = realm.create(SwiftListOfSwiftObject.self)
        try! realm.commitWrite()

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createEmbeddedArray() -> List<EmbeddedTreeObject1> {
        let realm = try! Realm()
        return try! realm.write {
            realm.create(EmbeddedParentObject.self, value: []).array
        }
    }
}

class ListRetrievedTests: ListTests {
    override func createArray() -> SwiftArrayPropertyObject {
        let realm = realmWithTestPath()
        realm.beginWrite()
        realm.create(SwiftArrayPropertyObject.self, value: ["name", [], []])
        try! realm.commitWrite()
        let array = realm.objects(SwiftArrayPropertyObject.self).first!

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createArrayWithLinks() -> SwiftListOfSwiftObject {
        let realm = try! Realm()
        realm.beginWrite()
        realm.create(SwiftListOfSwiftObject.self)
        try! realm.commitWrite()
        let array = realm.objects(SwiftListOfSwiftObject.self).first!

        XCTAssertNotNil(array.realm)
        return array
    }

    override func createEmbeddedArray() -> List<EmbeddedTreeObject1> {
        let realm = try! Realm()
        try! realm.write {
            realm.create(EmbeddedParentObject.self, value: [])
        }
        return realm.objects(EmbeddedParentObject.self).first!.array
    }
}

/// Ensure the range replaceable collection methods behave correctly when emulated for Swift 4 and later.
class ListRRCMethodsTests: TestCase {
    private func compare(array: [Int], with list: List<SwiftIntObject>) {
        guard array.count == list.count else {
            XCTFail("Array and list have different sizes (\(array.count) and \(list.count), respectively).")
            return
        }
        for i in 0..<array.count {
            XCTAssertEqual(array[i], list[i].intCol,
                           "Mistmatched array value (\(array[i])) and list value (\(list[i].intCol)) at index \(i)")
        }
    }

    private func makeArray(from list: List<SwiftIntObject>) -> [Int] {
        return list.map { $0.intCol }
    }

    private func makeSwiftIntObjects(from array: [Int]) -> [SwiftIntObject] {
        return array.map { SwiftIntObject(value: [$0]) }
    }

    private func createListObject(_ values: [Int] = [0, 1, 2, 3, 4, 5, 6]) -> SwiftArrayPropertyObject {
        let object = SwiftArrayPropertyObject()
        XCTAssertNil(object.realm)
        object.intArray.append(objectsIn: makeSwiftIntObjects(from: values))
        return object
    }

    private var array: [Int]!
    private var list: List<SwiftIntObject>!

    override func setUp() {
        super.setUp()
        list = createListObject().intArray
        array = makeArray(from: list)
    }

    func testSubscript() {
        list[0] = SwiftIntObject(value: [5])
        list[1..<4] = createListObject([10, 11, 12]).intArray[0..<2]
        array[0] = 5
        array[1..<4] = [10, 11]
        compare(array: array, with: list)
    }

    func testReplaceWithCollectionIndices() {
        let newElements = [1, 2, 3]
        list.replaceSubrange(list.indices, with: makeSwiftIntObjects(from: newElements))
        array.replaceSubrange(array.indices, with: newElements)
        compare(array: array, with: list)
    }

    func testRemoveWithCollectionIndices() {
        list.removeSubrange(list.indices)
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveFirst() {
        list.removeFirst()
        array.removeFirst()
        compare(array: array, with: list)
    }

    func testRemoveFirstFew() {
        list.removeFirst(3)
        array.removeFirst(3)
        compare(array: array, with: list)
    }

    func testRemoveFirstInvalid() {
        assertThrows(list.removeFirst(-1))
        assertThrows(list.removeFirst(100))
    }

    func testRemoveLastFew() {
        list.removeLast(3)
        array.removeLast(3)
        compare(array: array, with: list)
    }

    func testInsert() {
        let newElements = [10, 11, 12, 13]
        list.insert(contentsOf: makeSwiftIntObjects(from: newElements), at: 2)
        array.insert(contentsOf: newElements, at: 2)
        compare(array: array, with: list)
    }

    func testRemoveClosedSubrange() {
        let subrange: ClosedRange<Int> = 1...3
        list.removeSubrange(subrange)
        array.removeSubrange(subrange)
        compare(array: array, with: list)
    }

    func testRemoveOpenSubrange() {
        let subrange: Range<Int> = 1..<3
        list.removeSubrange(subrange)
        array.removeSubrange(subrange)
        compare(array: array, with: list)
    }

    func testReplaceClosedSubrange() {
        let subrange: ClosedRange<Int> = 2...5
        let newElements = [10, 11, 12, 13, 14, 15, 16]
        list.replaceSubrange(subrange, with: makeSwiftIntObjects(from: newElements))
        array.replaceSubrange(subrange, with: newElements)
        compare(array: array, with: list)
    }

    func testReplaceOpenSubrange() {
        let subrange: Range<Int> = 2..<5
        let newElements = [10, 11, 12, 13, 14, 15, 16]
        list.replaceSubrange(subrange, with: makeSwiftIntObjects(from: newElements))
        array.replaceSubrange(subrange, with: newElements)
        compare(array: array, with: list)
    }
    
    func testRealmListOfStringsComparison() {
        // Lists made from identical arrays should be equal:
        let strings = ["a", "b", "c"]
        let list1 = List<String>()
        list1.append(objectsIn: strings)
        
        let list2 = List<String>()
        list2.append(objectsIn: strings)
        
        XCTAssertTrue(list1 !== list2, "instances should not be identical")
        XCTAssertTrue(list1 == list2, "instances should be equal by `==` operator")
        XCTAssertTrue(list1.isEqual(list2), "instances should be equal by `isEqual` method")
        XCTAssertTrue(Array(list1) == Array(list2), "instances converted to Swift.Array should be equal")
        
        // Lists made from different-length arrays should not be equal,
        // even if the common elements are equal.
        let strings2 = ["a", "b", "c", "d"]
        let list3 = List<String>()
        list3.append(objectsIn: strings2)
        
        XCTAssertTrue(list1 !== list3, "instances should not be identical")
        XCTAssertFalse(list1 == list3, "instances should not be equal by `==` operator")
        XCTAssertFalse(list1.isEqual(list3), "instances should not be equal by `isEqual` method")
        XCTAssertFalse(Array(list1) == Array(list3), "instances converted to Swift.Array should not be equal")
    }
}
