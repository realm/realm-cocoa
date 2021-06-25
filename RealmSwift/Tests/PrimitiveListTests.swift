////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

// swiftlint:disable type_name identifier_name cyclomatic_complexity

import XCTest
import RealmSwift

protocol ObjectFactory {
    static func isManaged() -> Bool
}

struct ManagedObjectFactory: ObjectFactory {
    static func isManaged() -> Bool { return true }
}
struct UnmanagedObjectFactory: ObjectFactory {
    static func isManaged() -> Bool { return false }
}

protocol ValueFactory {
    associatedtype T: RealmCollectionValue
    associatedtype W: RealmCollectionValue = T
    associatedtype AverageType: AddableType = Double
    static func array(_ obj: SwiftListObject) -> List<T>
    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<T>
    static func values() -> [T]
    static func doubleValue(_ value: AverageType) -> Double
    static func doubleValue(t value: T) -> Double
    static func doubleValue(w value: W) -> Double
}
extension ValueFactory {
    static func doubleValue(_ value: Double) -> Double {
        return value
    }
    static func doubleValue(t value: T) -> Double {
        return (value as! NSNumber).doubleValue
    }
    static func doubleValue(w value: W) -> Double {
        return (value as! NSNumber).doubleValue
    }
}

struct IntFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Int> {
        return obj.int
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int> {
        return obj.int
    }

    static func values() -> [Int] {
        return [1, 2, 3]
    }
}

struct Int8Factory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Int8> {
        return obj.int8
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int8> {
        return obj.int8
    }

    static func values() -> [Int8] {
        return [1, 2, 3]
    }
}

struct Int16Factory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Int16> {
        return obj.int16
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int16> {
        return obj.int16
    }

    static func values() -> [Int16] {
        return [1, 2, 3]
    }
}

struct Int32Factory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Int32> {
        return obj.int32
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int32> {
        return obj.int32
    }

    static func values() -> [Int32] {
        return [1, 2, 3]
    }
}

struct Int64Factory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Int64> {
        return obj.int64
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int64> {
        return obj.int64
    }

    static func values() -> [Int64] {
        return [1, 2, 3]
    }
}

struct FloatFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Float> {
        return obj.float
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Float> {
        return obj.float
    }

    static func values() -> [Float] {
        return [1.1, 2.2, 3.3]
    }
}

struct DoubleFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Double> {
        return obj.double
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Double> {
        return obj.double
    }

    static func values() -> [Double] {
        return [1.1, 2.2, 3.3]
    }
}

struct StringFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<String> {
        return obj.string
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<String> {
        return obj.string
    }

    static func values() -> [String] {
        return ["a", "b", "c"]
    }
}

struct DataFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Data> {
        return obj.data
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Data> {
        return obj.data
    }

    static func values() -> [Data] {
        return ["a".data(using: .utf8)!, "b".data(using: .utf8)!, "c".data(using: .utf8)!]
    }
}

struct DateFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<Date> {
        return obj.date
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Date> {
        return obj.date
    }

    static func values() -> [Date] {
        return [Date(), Date().addingTimeInterval(10), Date().addingTimeInterval(20)]
    }
}

struct DecimalFactory: ValueFactory {
    typealias AverageType = Decimal128

    static func array(_ obj: SwiftListObject) -> List<Decimal128> {
        return obj.decimal
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Decimal128> {
        return obj.decimal
    }

    static func values() -> [Decimal128] {
        return [Decimal128(number: 1), Decimal128(number: 2), Decimal128(number: 3)]
    }

    static func doubleValue(_ value: Decimal128) -> Double {
        return value.doubleValue
    }
    static func doubleValue(t value: Decimal128) -> Double {
        return value.doubleValue
    }
    static func doubleValue(w value: Decimal128) -> Double {
        return value.doubleValue
    }
}

struct ObjectIdFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<ObjectId> {
        return obj.objectId
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<ObjectId> {
        return obj.objectId
    }

    static private let _values = [ObjectId.generate(), ObjectId.generate(), ObjectId.generate()]
    static func values() -> [ObjectId] {
        return _values
    }
}

struct UUIDFactory: ValueFactory {
    static func array(_ obj: SwiftListObject) -> List<UUID> {
        return obj.uuid
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<UUID> {
        return obj.uuid
    }

    static private let _values = [UUID(), UUID(), UUID()]
    static func values() -> [UUID] {
        return _values
    }
}

struct OptionalIntFactory: ValueFactory {
    typealias W = Int

    static func array(_ obj: SwiftListObject) -> List<Int?> {
        return obj.intOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int?> {
        return obj.intOpt
    }

    static func values() -> [Int?] {
        return [nil, 1, 3]
    }
}

struct OptionalInt8Factory: ValueFactory {
    typealias W = Int8

    static func array(_ obj: SwiftListObject) -> List<Int8?> {
        return obj.int8Opt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int8?> {
        return obj.int8Opt
    }

    static func values() -> [Int8?] {
        return [nil, 1, 3]
    }
}

struct OptionalInt16Factory: ValueFactory {
    typealias W = Int16

    static func array(_ obj: SwiftListObject) -> List<Int16?> {
        return obj.int16Opt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int16?> {
        return obj.int16Opt
    }

    static func values() -> [Int16?] {
        return [nil, 1, 3]
    }
}

struct OptionalInt32Factory: ValueFactory {
    typealias W = Int32

    static func array(_ obj: SwiftListObject) -> List<Int32?> {
        return obj.int32Opt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int32?> {
        return obj.int32Opt
    }

    static func values() -> [Int32?] {
        return [nil, 1, 3]
    }
}

struct OptionalInt64Factory: ValueFactory {
    typealias W = Int64

    static func array(_ obj: SwiftListObject) -> List<Int64?> {
        return obj.int64Opt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Int64?> {
        return obj.int64Opt
    }

    static func values() -> [Int64?] {
        return [nil, 1, 3]
    }
}

struct OptionalFloatFactory: ValueFactory {
    typealias W = Float

    static func array(_ obj: SwiftListObject) -> List<Float?> {
        return obj.floatOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Float?> {
        return obj.floatOpt
    }

    static func values() -> [Float?] {
        return [nil, 1.1, 3.3]
    }
}

struct OptionalDoubleFactory: ValueFactory {
    typealias W = Double

    static func array(_ obj: SwiftListObject) -> List<Double?> {
        return obj.doubleOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Double?> {
        return obj.doubleOpt
    }

    static func values() -> [Double?] {
        return [nil, 1.1, 3.3]
    }
}

struct OptionalStringFactory: ValueFactory {
    typealias W = String

    static func array(_ obj: SwiftListObject) -> List<String?> {
        return obj.stringOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<String?> {
        return obj.stringOpt
    }

    static func values() -> [String?] {
        return [nil, "a", "c"]
    }
}

struct OptionalDataFactory: ValueFactory {
    typealias W = Data

    static func array(_ obj: SwiftListObject) -> List<Data?> {
        return obj.dataOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Data?> {
        return obj.dataOpt
    }

    static func values() -> [Data?] {
        return [nil, "a".data(using: .utf8), "c".data(using: .utf8)]
    }
}

struct OptionalDateFactory: ValueFactory {
    typealias W = Date

    static func array(_ obj: SwiftListObject) -> List<Date?> {
        return obj.dateOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Date?> {
        return obj.dateOpt
    }

    static func values() -> [Date?] {
        return [nil, Date(), Date().addingTimeInterval(20)]
    }
}

struct OptionalDecimalFactory: ValueFactory {
    typealias W = Decimal128
    typealias AverageType = Decimal128

    static func array(_ obj: SwiftListObject) -> List<Decimal128?> {
        return obj.decimalOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<Decimal128?> {
        return obj.decimalOpt
    }

    static func values() -> [Decimal128?] {
        return [nil] + DecimalFactory.values().dropLast()
    }

    static func doubleValue(_ value: Decimal128) -> Double {
        return value.doubleValue
    }
    static func doubleValue(t value: Decimal128?) -> Double {
        return value!.doubleValue
    }
    static func doubleValue(w value: Decimal128) -> Double {
        return value.doubleValue
    }
}

struct OptionalObjectIdFactory: ValueFactory {
    typealias W = ObjectId

    static func array(_ obj: SwiftListObject) -> List<ObjectId?> {
        return obj.objectIdOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<ObjectId?> {
        return obj.objectIdOpt
    }

    static func values() -> [ObjectId?] {
        return [nil] + ObjectIdFactory.values().dropLast()
    }
}

struct OptionalUUIDFactory: ValueFactory {
    typealias W = UUID

    static func array(_ obj: SwiftListObject) -> List<UUID?> {
        return obj.uuidOpt
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<UUID?> {
        return obj.uuidOpt
    }

    static func values() -> [UUID?] {
        return [nil] + UUIDFactory.values().dropLast()
    }
}

class PrimitiveListTestsBase<O: ObjectFactory, V: ValueFactory>: TestCase {
    var realm: Realm?
    var obj: SwiftListObject!
    var array: List<V.T>!
    var values: [V.T]!

    class func _defaultTestSuite() -> XCTestSuite {
        return defaultTestSuite
    }

    override func setUp() {
        obj = SwiftListObject()
        if O.isManaged() {
            let config = Realm.Configuration(inMemoryIdentifier: "test",
                                             objectTypes: [SwiftListObject.self, SwiftStringObject.self])
            realm = try! Realm(configuration: config)
            realm!.beginWrite()
            realm!.add(obj)
        }
        array = V.array(obj)
        values = V.values()
    }

    override func tearDown() {
        realm?.cancelWrite()
        realm = nil
        array = nil
        obj = nil
    }
}

class PrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> {
    func testInvalidated() {
        XCTAssertFalse(array.isInvalidated)
        if let realm = obj.realm {
            realm.delete(obj)
            XCTAssertTrue(array.isInvalidated)
        }
    }

    func testIndexOf() {
        XCTAssertNil(array.index(of: values[0]))

        array.append(values[0])
        XCTAssertEqual(0, array.index(of: values[0]))

        array.append(values[1])
        XCTAssertEqual(0, array.index(of: values[0]))
        XCTAssertEqual(1, array.index(of: values[1]))
    }

    // FIXME: Not yet implemented
    func disabled_testIndexMatching() {
        XCTAssertNil(array.index(matching: "self = %@", values[0]))

        array.append(values[0])
        XCTAssertEqual(0, array.index(matching: "self = %@", values[0]))

        array.append(values[1])
        XCTAssertEqual(0, array.index(matching: "self = %@", values[0]))
        XCTAssertEqual(1, array.index(matching: "self = %@", values[1]))
    }

    func testSubscript() {
        array.append(objectsIn: values)
        for i in 0..<values.count {
            XCTAssertEqual(array[i], values[i])
        }
        assertThrows(array[values.count], reason: "Index 3 is out of bounds")
        assertThrows(array[-1], reason: "negative value")
    }

    func testFirst() {
        array.append(objectsIn: values)
        XCTAssertEqual(array.first, values.first)
        array.removeAll()
        XCTAssertNil(array.first)
    }

    func testLast() {
        array.append(objectsIn: values)
        XCTAssertEqual(array.last, values.last)
        array.removeAll()
        XCTAssertNil(array.last)

    }

    func testObjectsAtIndexes() {
        assertThrows(array.objects(at: [1, 2, 3]), reason: "Indexes for List are out of bounds.")
        array.append(objectsIn: values)
        let objs = array.objects(at: [2, 1])
        XCTAssertEqual(values[1], objs.first) // this is broke
        XCTAssertEqual(values[2], objs.last)
    }

    func testValueForKey() {
        XCTAssertEqual(array.value(forKey: "self").count, 0)
        array.append(objectsIn: values)
        XCTAssertEqual(values!, array.value(forKey: "self").map { dynamicBridgeCast(fromObjectiveC: $0) as V.T })

        assertThrows(array.value(forKey: "not self"), named: "NSUnknownKeyException")
    }

    func testSetValueForKey() {
        // does this even make any sense?

    }

    func testFilter() {
        // not implemented
    }

    func testInsert() {
        XCTAssertEqual(Int(0), array.count)

        array.insert(values[0], at: 0)
        XCTAssertEqual(Int(1), array.count)
        XCTAssertEqual(values[0], array[0])

        array.insert(values[1], at: 0)
        XCTAssertEqual(Int(2), array.count)
        XCTAssertEqual(values[1], array[0])
        XCTAssertEqual(values[0], array[1])

        array.insert(values[2], at: 2)
        XCTAssertEqual(Int(3), array.count)
        XCTAssertEqual(values[1], array[0])
        XCTAssertEqual(values[0], array[1])
        XCTAssertEqual(values[2], array[2])

        assertThrows(array.insert(values[0], at: 4))
        assertThrows(array.insert(values[0], at: -1))
    }

    func testRemove() {
        assertThrows(array.remove(at: 0))
        assertThrows(array.remove(at: -1))

        array.append(objectsIn: values)

        assertThrows(array.remove(at: -1))
        XCTAssertEqual(values[0], array[0])
        XCTAssertEqual(values[1], array[1])
        XCTAssertEqual(values[2], array[2])
        assertThrows(array[3])

        array.remove(at: 0)
        XCTAssertEqual(values[1], array[0])
        XCTAssertEqual(values[2], array[1])
        assertThrows(array[2])
        assertThrows(array.remove(at: 2))

        array.remove(at: 1)
        XCTAssertEqual(values[1], array[0])
        assertThrows(array[1])
    }

    func testRemoveLast() {
        assertThrows(array.removeLast())

        array.append(objectsIn: values)
        array.removeLast()

        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(values[0], array[0])
        XCTAssertEqual(values[1], array[1])

        array.removeLast(2)
        XCTAssertEqual(array.count, 0)
    }

    func testRemoveAll() {
        array.removeAll()
        array.append(objectsIn: values)
        array.removeAll()
        XCTAssertEqual(array.count, 0)
    }

    func testReplace() {
        assertThrows(array.replace(index: 0, object: values[0]),
                     reason: "Index 0 is out of bounds")

        array.append(objectsIn: values)
        array.replace(index: 1, object: values[0])
        XCTAssertEqual(array[0], values[0])
        XCTAssertEqual(array[1], values[0])
        XCTAssertEqual(array[2], values[2])

        assertThrows(array.replace(index: 3, object: values[0]),
                     reason: "Index 3 is out of bounds")
        assertThrows(array.replace(index: -1, object: values[0]),
                     reason: "Cannot pass a negative value")
    }

    func testReplaceRange() {
        assertSucceeds { array.replaceSubrange(0..<0, with: []) }

#if false
        // FIXME: The exception thrown here runs afoul of Swift's exclusive access checking.
        assertThrows(array.replaceSubrange(0..<1, with: []),
                     reason: "Index 0 is out of bounds")
#endif

        array.replaceSubrange(0..<0, with: [values[0]])
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array[0], values[0])

        array.replaceSubrange(0..<1, with: values)
        XCTAssertEqual(array.count, 3)

        array.replaceSubrange(1..<2, with: [])
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0], values[0])
        XCTAssertEqual(array[1], values[2])
    }

    func testMove() {
        assertThrows(array.move(from: 1, to: 0), reason: "out of bounds")

        array.append(objectsIn: values)
        array.move(from: 2, to: 0)
        XCTAssertEqual(array[0], values[2])
        XCTAssertEqual(array[1], values[0])
        XCTAssertEqual(array[2], values[1])

        assertThrows(array.move(from: 3, to: 0), reason: "Index 3 is out of bounds")
        assertThrows(array.move(from: 0, to: 3), reason: "Index 3 is out of bounds")
        assertThrows(array.move(from: -1, to: 0), reason: "negative value")
        assertThrows(array.move(from: 0, to: -1), reason: "negative value")
    }

    func testSwap() {
        assertThrows(array.swapAt(0, 1), reason: "out of bounds")

        array.append(objectsIn: values)
        array.swapAt(0, 2)
        XCTAssertEqual(array[0], values[2])
        XCTAssertEqual(array[1], values[1])
        XCTAssertEqual(array[2], values[0])

        assertThrows(array.swapAt(3, 0), reason: "Index 3 is out of bounds")
        assertThrows(array.swapAt(0, 3), reason: "Index 3 is out of bounds")
        assertThrows(array.swapAt(-1, 0), reason: "negative value")
        assertThrows(array.swapAt(0, -1), reason: "negative value")
    }
}

class MinMaxPrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T: MinMaxType {
    func testMin() {
        XCTAssertNil(array.min())
        array.append(objectsIn: values.reversed())
        XCTAssertEqual(array.min(), values.first)
    }

    func testMax() {
        XCTAssertNil(array.max())
        array.append(objectsIn: values.reversed())
        XCTAssertEqual(array.max(), values.last)
    }
}

class OptionalMinMaxPrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.W: MinMaxType {
    // V.T and V.W? are the same thing, but the type system doesn't know that
    // and the protocol constraint is on V.W
    var array2: List<V.W?> {
        return unsafeDowncast(array!, to: List<V.W?>.self)
    }

    func testMin() {
        XCTAssertNil(array2.min())
        array.append(objectsIn: values.reversed())
        let expected = values[1] as! V.W
        XCTAssertEqual(array2.min(), expected)
    }

    func testMax() {
        XCTAssertNil(array2.max())
        array.append(objectsIn: values.reversed())
        let expected = values[2] as! V.W
        XCTAssertEqual(array2.max(), expected)
    }
}

class AddablePrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T: AddableType {
    func testSum() {
        XCTAssertEqual(array.sum(), V.T())
        array.append(objectsIn: values)

        // Expressing "can be added and converted to a floating point type" as
        // a protocol requirement is awful, so sidestep it all with obj-c
        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@sum.self")! as! NSNumber).doubleValue
        XCTAssertEqual(V.doubleValue(t: array.sum()), expected, accuracy: 0.01)
    }

    func testAverage() {
        XCTAssertNil(array.average() as V.AverageType?)
        array.append(objectsIn: values)

        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@avg.self")! as! NSNumber).doubleValue
        XCTAssertEqual(V.doubleValue(array.average()!), expected, accuracy: 0.01)
    }
}

class OptionalAddablePrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.W: AddableType {
    // V.T and V.W? are the same thing, but the type system doesn't know that
    // and the protocol constraint is on V.W
    var array2: List<V.W?> {
        return unsafeDowncast(array!, to: List<V.W?>.self)
    }

    func testSum() {
        XCTAssertEqual(array2.sum(), V.W())
        array.append(objectsIn: values)

        var nonNil = values!
        nonNil.remove(at: 0)

        // Expressing "can be added and converted to a floating point type" as
        // a protocol requirement is awful, so sidestep it all with obj-c
        let expected = ((nonNil.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@sum.self")! as! NSNumber).doubleValue
        XCTAssertEqual(V.doubleValue(w: array2.sum()), expected, accuracy: 0.01)
    }

    func testAverage() {
        XCTAssertNil(array2.average() as Double?)
        array.append(objectsIn: values)

        var nonNil = values!
        nonNil.remove(at: 0)

        let expected = ((nonNil.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@avg.self")! as! NSNumber).doubleValue
        XCTAssertEqual(V.doubleValue(array2.average()!), expected, accuracy: 0.01)
    }
}

class SortablePrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T: Comparable {
    func testSorted() {
        var shuffled = values!
        shuffled.removeFirst()
        shuffled.append(values!.first!)
        array.append(objectsIn: shuffled)

        assertEqual(Array(array.sorted(ascending: true)), values)
        assertEqual(Array(array.sorted(ascending: false)), values.reversed())
    }
}

class OptionalSortablePrimitiveListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.W: Comparable {
    func testSorted() {
        var shuffled = values!
        shuffled.removeFirst()
        shuffled.append(values!.first!)
        array.append(objectsIn: shuffled)

        let array2 = unsafeDowncast(array!, to: List<V.W?>.self)
        let values2 = unsafeBitCast(values!, to: Array<V.W?>.self)
        assertEqual(Array(array2.sorted(ascending: true)), values2)
        assertEqual(Array(array2.sorted(ascending: false)), values2.reversed())
    }
}

func addTests<OF: ObjectFactory>(_ suite: XCTestSuite, _ type: OF.Type) {
    _ = PrimitiveListTests<OF, IntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, Int8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, Int16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, Int32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, Int64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, FloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, DoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, StringFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, DataFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, DateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, DecimalFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, ObjectIdFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, UUIDFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = MinMaxPrimitiveListTests<OF, IntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, Int8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, Int16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, Int32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, Int64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, FloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, DoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, DateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxPrimitiveListTests<OF, DecimalFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = AddablePrimitiveListTests<OF, IntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, Int8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, Int16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, Int32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, Int64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, FloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, DoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddablePrimitiveListTests<OF, DecimalFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = PrimitiveListTests<OF, OptionalIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalInt8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalInt16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalInt32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalInt64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalStringFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalDataFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalDecimalFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalObjectIdFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = PrimitiveListTests<OF, OptionalUUIDFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalInt8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalInt16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalInt32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalInt64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalMinMaxPrimitiveListTests<OF, OptionalDecimalFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = OptionalAddablePrimitiveListTests<OF, OptionalIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalInt8Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalInt16Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalInt32Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalInt64Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = OptionalAddablePrimitiveListTests<OF, OptionalDecimalFactory>._defaultTestSuite().tests.map(suite.addTest)
}

class UnmanagedPrimitiveListTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Unmanaged Primitive Lists")
        addTests(suite, UnmanagedObjectFactory.self)
        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}

class ManagedPrimitiveListTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Managed Primitive Lists")
        addTests(suite, ManagedObjectFactory.self)

        _ = SortablePrimitiveListTests<ManagedObjectFactory, IntFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, Int8Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, Int16Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, Int32Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, Int64Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, FloatFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, DoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, StringFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = SortablePrimitiveListTests<ManagedObjectFactory, DateFactory>._defaultTestSuite().tests.map(suite.addTest)

        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalIntFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalInt8Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalInt16Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalInt32Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalInt64Factory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalStringFactory>._defaultTestSuite().tests.map(suite.addTest)
        _ = OptionalSortablePrimitiveListTests<ManagedObjectFactory, OptionalDateFactory>._defaultTestSuite().tests.map(suite.addTest)

        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}
