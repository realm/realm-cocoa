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
import Realm
import RealmSwift

class AnyRealmTypeObject: Object {
    var anyValue = RealmProperty<AnyRealmValue>()
    // required for schema validation, but not used in tests.
    @objc dynamic var int = 0
}

class AnyRealmValueTests<T: Equatable, V: ValueFactory>: TestCase {

    var values: [V.T] {
        V.values()
    }

    var wrappedValues: [T?] {
        func cast(_ value: AnyRealmValue) -> T? {
            switch T.self {
            case is Int.Type:
                    return value.intValue as? T
            case is Bool.Type:
                    return value.boolValue as? T
            case is Float.Type:
                    return value.floatValue as? T
            case is Double.Type:
                    return value.floatValue as? T
            case is String.Type:
                    return value.stringValue as? T
            case is Data.Type:
                    return value.dataValue as? T
            case is Date.Type:
                    return value.dateValue as? T
            case is ObjectId.Type:
                    return value.objectIdValue as? T
            case is Decimal128.Type:
                    return value.decimal128Value as? T
            case is UUID.Type:
                    return value.uuidValue as? T
            default:
                    return nil
            }
        }
        return (V.values() as! [AnyRealmValue]).map(cast)
    }

    var keyPath: KeyPath<AnyRealmValue, T?> {
        switch T.self {
        case is Int.Type:
                return \AnyRealmValue.intValue as! KeyPath<AnyRealmValue, T?>
        case is Bool.Type:
                return \AnyRealmValue.boolValue as! KeyPath<AnyRealmValue, T?>
        case is Float.Type:
                return \AnyRealmValue.floatValue as! KeyPath<AnyRealmValue, T?>
        case is Double.Type:
                return \AnyRealmValue.floatValue as! KeyPath<AnyRealmValue, T?>
        case is String.Type:
                return \AnyRealmValue.stringValue as! KeyPath<AnyRealmValue, T?>
        case is Data.Type:
                return \AnyRealmValue.dataValue as! KeyPath<AnyRealmValue, T?>
        case is Date.Type:
                return \AnyRealmValue.dateValue as! KeyPath<AnyRealmValue, T?>
        case is ObjectId.Type:
                return \AnyRealmValue.objectIdValue as! KeyPath<AnyRealmValue, T?>
        case is Decimal128.Type:
                return \AnyRealmValue.decimal128Value as! KeyPath<AnyRealmValue, T?>
        case is UUID.Type:
                return \AnyRealmValue.uuidValue as! KeyPath<AnyRealmValue, T?>
        default:
                fatalError()
                break
        }
    }

    func testAnyRealmValue() {
        let o = AnyRealmTypeObject()
        o.anyValue.value = values[0] as! AnyRealmValue
        XCTAssertEqual(o.anyValue.value[keyPath: keyPath], wrappedValues[0])
        o.anyValue.value = values[1] as! AnyRealmValue
        XCTAssertEqual(o.anyValue.value[keyPath: keyPath], wrappedValues[1])
        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(o)
        }
        XCTAssertEqual(o.anyValue.value[keyPath: keyPath], wrappedValues[1])
        try! realm.write {
            o.anyValue.value = values[2] as! AnyRealmValue
        }
        XCTAssertEqual(o.anyValue.value[keyPath: keyPath], wrappedValues[2])
    }
}
class AnyRealmValuePrimitiveTests: TestCase {
    override class var defaultTestSuite: XCTestSuite {
        let suite = XCTestSuite(name: "Any Realm Value Tests")
        _ = AnyRealmValueTests<Int, AnyRealmValueIntFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<Bool, AnyRealmValueBoolFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<Float, AnyRealmValueFloatFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<String, AnyRealmValueStringFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<Data, AnyRealmValueDataFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<Date, AnyRealmValueDateFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<ObjectId, AnyRealmValueObjectIdFactory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<Decimal128, AnyRealmValueDecimal128Factory>.defaultTestSuite.tests.map(suite.addTest)
        _ = AnyRealmValueTests<UUID, AnyRealmValueUUIDFactory>.defaultTestSuite.tests.map(suite.addTest)
        return suite
    }
}

class AnyRealmValueObjectTests: TestCase {

    func testObject() {
        let o = AnyRealmTypeObject()
        let so = SwiftStringObject()
        so.stringCol = "hello"
        o.anyValue.value = .object(so)
        XCTAssertEqual(o.anyValue.value.object(SwiftStringObject.self)!.stringCol, "hello")
        o.anyValue.value.object(SwiftStringObject.self)!.stringCol = "there"
        XCTAssertEqual(o.anyValue.value.object(SwiftStringObject.self)!.stringCol, "there")
        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(o)
        }
        XCTAssertEqual(o.anyValue.value.object(SwiftStringObject.self)!.stringCol, "there")
        try! realm.write {
            o.anyValue.value.object(SwiftStringObject.self)!.stringCol = "bye!"
        }
        XCTAssertEqual(o.anyValue.value.object(SwiftStringObject.self)!.stringCol, "bye!")
    }

    func testAssortment() {
        // The purpose of this test is to reuse a mixed container
        // and ensure no issues exist in doing that.
        let o = AnyRealmTypeObject()
        let so = SwiftStringObject()
        so.stringCol = "hello"
        let data = Data(repeating: 1, count: 64)
        let date = Date()
        let objectId = ObjectId.generate()
        let decimal = Decimal128(floatLiteral: 12345.6789)

        let tests: ((Realm?) -> Void) = { (realm: Realm?) in
            self.testVariation(object: o, value: .int(123), keyPath: \.intValue, expected: 123, realm: realm)
            self.testVariation(object: o, value: .float(123.456), keyPath: \.floatValue, expected: 123.456, realm: realm)
            self.testVariation(object: o, value: .string("hello there"), keyPath: \.stringValue, expected: "hello there", realm: realm)
            self.testVariation(object: o, value: .data(data), keyPath: \.dataValue, expected: data, realm: realm)
            self.testVariation(object: o, value: .date(date), keyPath: \.dateValue, expected: date, realm: realm)
            self.testVariation(object: o, value: .objectId(objectId), keyPath: \.objectIdValue, expected: objectId, realm: realm)
            self.testVariation(object: o, value: .decimal128(decimal), keyPath: \.decimal128Value, expected: decimal, realm: realm)
        }

        // unmanaged
        tests(nil)
        o.anyValue.value = .none
        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(o)
        }
        // managed
        tests(realm)

        try! realm.write {
            o.anyValue.value = .object(so)
        }
        XCTAssertEqual(o.anyValue.value.object(SwiftStringObject.self)!.stringCol, "hello")
    }

    private func testVariation<T: Equatable>(object: AnyRealmTypeObject,
                                             value: AnyRealmValue,
                                             keyPath: KeyPath<AnyRealmValue, T?>,
                                             expected: T,
                                             realm: Realm?) {
        if let realm = realm {
            try! realm.write {
                object.anyValue.value = value
            }
        } else {
            object.anyValue.value = value
        }
        XCTAssertEqual(object.anyValue.value[keyPath: keyPath], expected)
    }
}

class BaseAnyRealmValueFactory {
    static func array(_ obj: SwiftListObject) -> List<AnyRealmValue> {
        return obj.any
    }

    static func mutableSet(_ obj: SwiftMutableSetObject) -> MutableSet<AnyRealmValue> {
        return obj.any
    }
}

class AnyRealmValueIntFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.int(123), .int(456), .int(789)]
    }
}

class AnyRealmValueBoolFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.bool(true), .bool(false), .none]
    }
}

class AnyRealmValueFloatFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.float(123.456), .float(456.789), .float(789.123456)]
    }
}

class AnyRealmValueDoubleFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.double(123.456), .double(456.789), .double(789.123456)]
    }
}

class AnyRealmValueStringFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.string("Hello There"), .string("This is"), .string("A test...")]
    }
}

class AnyRealmValueDataFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        func data(_ byte: UInt8) -> AnyRealmValue {
            .data(Data.init(repeating: byte, count: 64))
        }
        return [data(11), data(22), data(33)]
    }
}

class AnyRealmValueDateFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        func date(_ timestamp: TimeInterval) -> AnyRealmValue {
            .date(Date(timeIntervalSince1970: timestamp))
        }
        return [date(1614445927), date(1614555927), date(1614665927)]
    }
}

class AnyRealmValueObjectFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        func object(_ string: String) -> AnyRealmValue {
            let o = SwiftStringObject()
            o.stringCol = string
            return .object(o)
        }
        return [object("Hello"), object("I am"), object("an object")]
    }
}

class AnyRealmValueObjectIdFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.objectId(.init("6056670f1a2a5b103c9affda")),
         .objectId(.init("6056670f1a2a5b103c9affdd")),
         .objectId(.init("605667111a2a5b103c9affe1"))]
    }
}

class AnyRealmValueDecimal128Factory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        func decima128(_ double: Double) -> AnyRealmValue {
            .decimal128(.init(floatLiteral: double))
        }
        return [decima128(123.456), decima128(993.456789), decima128(9874546.65456489)]
    }
}

class AnyRealmValueUUIDFactory: BaseAnyRealmValueFactory, ValueFactory {
    static func values() -> [AnyRealmValue] {
        [.uuid(UUID(uuidString: "7729028A-FB89-4555-81C3-C55F7DDBA5CF")!),
         .uuid(UUID(uuidString: "0F0359D8-8D74-409D-8561-C8EBE3753635")!),
         .uuid(UUID(uuidString: "0F0359D8-8D74-409D-8561-C8EBE3753636")!)]
    }
}

class AnyRealmValueListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T == AnyRealmValue {

    private func assertEqual(_ obj: AnyRealmValue, _ anotherObj: AnyRealmValue) {
        if case let .object(a) = obj,
           case let .object(b) = anotherObj {
            XCTAssertEqual((a as! SwiftStringObject).stringCol, (b as! SwiftStringObject).stringCol)
        } else {
            XCTAssertEqual(obj, anotherObj)
        }
    }

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
            assertEqual(array[i], values[i])
        }
        assertThrows(array[values.count], reason: "Index 3 is out of bounds")
        assertThrows(array[-1], reason: "negative value")
    }

    func testFirst() {
        array.append(objectsIn: values)
        assertEqual(array.first!, values.first!)
        array.removeAll()
        XCTAssertNil(array.first)
    }

    func testLast() {
        array.append(objectsIn: values)
        assertEqual(array.last!, values.last!)
        array.removeAll()
        XCTAssertNil(array.last)

    }

    func testValueForKey() {
        array.append(objectsIn: values)

        for (expected, actual) in zip(values!, array.value(forKey: "self").map { dynamicBridgeCast(fromObjectiveC: $0) as V.T }) {
            assertEqual(expected, actual)
        }

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
        assertEqual(values[0], array[0])

        array.insert(values[1], at: 0)
        XCTAssertEqual(Int(2), array.count)
        assertEqual(values[1], array[0])
        assertEqual(values[0], array[1])

        array.insert(values[2], at: 2)
        XCTAssertEqual(Int(3), array.count)
        assertEqual(values[1], array[0])
        assertEqual(values[0], array[1])
        assertEqual(values[2], array[2])

        assertThrows(array.insert(values[0], at: 4))
        assertThrows(array.insert(values[0], at: -1))
    }

    func testRemove() {
        assertThrows(array.remove(at: 0))
        assertThrows(array.remove(at: -1))

        array.append(objectsIn: values)

        assertThrows(array.remove(at: -1))
        assertEqual(values[0], array[0])
        assertEqual(values[1], array[1])
        assertEqual(values[2], array[2])
        assertThrows(array[3])

        array.remove(at: 0)
        assertEqual(values[1], array[0])
        assertEqual(values[2], array[1])
        assertThrows(array[2])
        assertThrows(array.remove(at: 2))

        array.remove(at: 1)
        assertEqual(values[1], array[0])
        assertThrows(array[1])
    }

    func testRemoveLast() {
        assertThrows(array.removeLast())

        array.append(objectsIn: values)
        array.removeLast()

        XCTAssertEqual(array.count, 2)
        assertEqual(values[0], array[0])
        assertEqual(values[1], array[1])

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
        assertEqual(array[0], values[0])
        assertEqual(array[1], values[0])
        assertEqual(array[2], values[2])

        assertThrows(array.replace(index: 3, object: values[0]),
                     reason: "Index 3 is out of bounds")
        assertThrows(array.replace(index: -1, object: values[0]),
                     reason: "Cannot pass a negative value")
    }

    func testReplaceRange() {
        assertSucceeds { array.replaceSubrange(0..<0, with: []) }

        array.replaceSubrange(0..<0, with: [values[0]])
        XCTAssertEqual(array.count, 1)
        assertEqual(array[0], values[0])

        array.replaceSubrange(0..<1, with: values)
        XCTAssertEqual(array.count, 3)

        array.replaceSubrange(1..<2, with: [])
        XCTAssertEqual(array.count, 2)
        assertEqual(array[0], values[0])
        assertEqual(array[1], values[2])
    }

    func testMove() {
        assertThrows(array.move(from: 1, to: 0), reason: "out of bounds")

        array.append(objectsIn: values)
        array.move(from: 2, to: 0)
        assertEqual(array[0], values[2])
        assertEqual(array[1], values[0])
        assertEqual(array[2], values[1])

        assertThrows(array.move(from: 3, to: 0), reason: "Index 3 is out of bounds")
        assertThrows(array.move(from: 0, to: 3), reason: "Index 3 is out of bounds")
        assertThrows(array.move(from: -1, to: 0), reason: "negative value")
        assertThrows(array.move(from: 0, to: -1), reason: "negative value")
    }

    func testSwap() {
        assertThrows(array.swapAt(0, 1), reason: "out of bounds")

        array.append(objectsIn: values)
        array.swapAt(0, 2)
        assertEqual(array[0], values[2])
        assertEqual(array[1], values[1])
        assertEqual(array[2], values[0])

        assertThrows(array.swapAt(3, 0), reason: "Index 3 is out of bounds")
        assertThrows(array.swapAt(0, 3), reason: "Index 3 is out of bounds")
        assertThrows(array.swapAt(-1, 0), reason: "negative value")
        assertThrows(array.swapAt(0, -1), reason: "negative value")
    }

    func testAssign() {
        XCTAssertEqual(Int(0), array.count)

        array.insert(values[0], at: 0)
        XCTAssertEqual(Int(1), array.count)
        assertEqual(values[0], array[0])

        array[0] = values[1]
        XCTAssertEqual(Int(1), array.count)
        assertEqual(values[1], array[0])
    }
}

class MinMaxAnyRealmValueListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T == AnyRealmValue {
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

class AddableAnyRealmValueListTests<O: ObjectFactory, V: ValueFactory>: PrimitiveListTestsBase<O, V> where V.T == AnyRealmValue {
    func testSum() {
        XCTAssertEqual(array.sum().intValue, nil)
        array.append(objectsIn: values)

        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@sum.self")! as! NSNumber)

        // An unmanaged collection will return a double
        if case let .double(d) = array.sum() {
            XCTAssertEqual(d, expected.doubleValue)
        } else if case let .decimal128(d) = array.sum() {
            // A managed collection of AnyRealmValue will return a Decimal128 for `sum()`
            XCTAssertEqual(d.doubleValue, expected.doubleValue, accuracy: 0.1)
        }
    }

    func testAverage() {
        XCTAssertNil(array.average() as V.AverageType?)
        array.append(objectsIn: values)

        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@avg.self")! as! NSNumber)

        let v: AnyRealmValue? = array.average()
        // An unmanaged collection will return a double
        if case let .double(d) = v {
            XCTAssertEqual(d, expected.doubleValue)
        } else if case let .decimal128(d) = v {
            // A managed collection of AnyRealmValue will return a Decimal128 for `avg()`
            XCTAssertEqual(d.doubleValue, expected.doubleValue, accuracy: 0.1)
        }
    }
}

func addAnyRealmValueTests<OF: ObjectFactory>(_ suite: XCTestSuite, _ type: OF.Type) {
    _ = AnyRealmValueListTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueBoolFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueStringFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueDataFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueObjectFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueObjectIdFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueListTests<OF, AnyRealmValueUUIDFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = MinMaxAnyRealmValueListTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueListTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueListTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueListTests<OF, AnyRealmValueDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueListTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)

    _ = AddableAnyRealmValueListTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueListTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueListTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueListTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)
}

class UnmanagedAnyRealmValueListTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Unmanaged AnyRealmValue Lists")
        addAnyRealmValueTests(suite, UnmanagedObjectFactory.self)
        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}

class ManagedAnyRealmValueListTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Managed AnyRealmValue Lists")
        addAnyRealmValueTests(suite, ManagedObjectFactory.self)
        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}

class AnyRealmValueMutableSetTests<O: ObjectFactory, V: ValueFactory>: PrimitiveMutableSetTestsBase<O, V> where V.T == AnyRealmValue {

    private func assertEqual(_ obj: AnyRealmValue, _ anotherObj: AnyRealmValue) {
        if case let .object(a) = obj,
           case let .object(b) = anotherObj {
            XCTAssertEqual((a as! SwiftStringObject).stringCol, (b as! SwiftStringObject).stringCol)
        } else {
            XCTAssertEqual(obj, anotherObj)
        }
    }

    func testInvalidated() {
        XCTAssertFalse(mutableSet.isInvalidated)
        if let realm = obj.realm {
            realm.delete(obj)
            XCTAssertTrue(mutableSet.isInvalidated)
        }
    }

    func testValueForKey() {
        XCTAssertEqual(mutableSet.value(forKey: "self").count, 0)
        mutableSet.insert(values[0])
        let kvo = (mutableSet.value(forKey: "self") as [AnyObject]).first!
        if let obj = kvo as? SwiftStringObject, case let .object(o) = values[0] {
            XCTAssertEqual(obj.stringCol, (o as! SwiftStringObject).stringCol)
        } else {
            let v = RealmProperty<AnyRealmValue>()
            v.rlmValue = kvo as? RLMValue
            XCTAssertEqual(v.value, values[0])
        }
        assertThrows(mutableSet.value(forKey: "not self"), named: "NSUnknownKeyException")
    }

    func testInsert() {
        XCTAssertEqual(Int(0), mutableSet.count)

        mutableSet.insert(values[0])
        XCTAssertEqual(Int(1), mutableSet.count)
        XCTAssertTrue(mutableSet.contains(values[0]))

        mutableSet.insert(values[1])
        XCTAssertEqual(Int(2), mutableSet.count)
        XCTAssertTrue(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))

        mutableSet.insert(values[2])
        XCTAssertEqual(Int(3), mutableSet.count)
        XCTAssertTrue(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))

        mutableSet.insert(values[2])
        XCTAssertEqual(Int(3), mutableSet.count)
        XCTAssertTrue(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))
        XCTAssertTrue(mutableSet.contains(values[2]))
        // Insert duplicate
        mutableSet.insert(values[2])
        XCTAssertEqual(Int(3), mutableSet.count)
        XCTAssertTrue(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))
        XCTAssertTrue(mutableSet.contains(values[2]))
    }

    func testRemove() {
        mutableSet.removeAll()
        XCTAssertEqual(mutableSet.count, 0)
        mutableSet.insert(objectsIn: values)
        mutableSet.remove(values[0])
        XCTAssertFalse(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))
        XCTAssertTrue(mutableSet.contains(values[2]))
    }

    func testRemoveAll() {
        mutableSet.removeAll()
        mutableSet.insert(objectsIn: values)
        mutableSet.removeAll()
        XCTAssertEqual(mutableSet.count, 0)
    }

    func testIsSubset() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(objectsIn: values)
        otherMutableSet.insert(values[0])
        // Both sets contain values[0]
        XCTAssertTrue(otherMutableSet.isSubset(of: mutableSet))
        otherMutableSet.remove(values[0])
        XCTAssertFalse(mutableSet.isSubset(of: otherMutableSet))
    }

    func testContains() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(objectsIn: values)
        XCTAssertEqual(values.count, mutableSet.count)
        values.forEach {
            XCTAssertTrue(mutableSet.contains($0))
        }
    }

    func testIntersects() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(objectsIn: values)
        otherMutableSet.insert(values[0])
        // Both sets contain values[0]
        XCTAssertTrue(otherMutableSet.intersects(mutableSet))
        otherMutableSet.remove(values[0])
        XCTAssertFalse(mutableSet.intersects(otherMutableSet))
    }

    func testFormIntersection() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(objectsIn: values)
        otherMutableSet.insert(values[0])
        // Both sets contain values[0]
        mutableSet.formIntersection(otherMutableSet)
        XCTAssertEqual(Int(1), mutableSet.count)
        assertEqual(mutableSet[0], values[0])
    }

    func testFormUnion() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(values[0])
        mutableSet.insert(values[1])
        otherMutableSet.insert(values[0])
        otherMutableSet.insert(values[2])
        mutableSet.formUnion(otherMutableSet)
        XCTAssertEqual(Int(3), mutableSet.count)
        if values[0].object(SwiftStringObject.self) != nil {
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[0].object(SwiftStringObject.self)?.stringCol))
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[1].object(SwiftStringObject.self)?.stringCol))
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[2].object(SwiftStringObject.self)?.stringCol))
        } else {
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[0]))
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[1]))
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[2]))
        }
    }

    func testSubtract() {
        XCTAssertEqual(Int(0), mutableSet.count)
        XCTAssertEqual(Int(0), otherMutableSet.count)
        mutableSet.insert(values[0])
        mutableSet.insert(values[1])
        otherMutableSet.insert(values[0])
        otherMutableSet.insert(values[2])
        mutableSet.subtract(otherMutableSet)
        XCTAssertEqual(Int(1), mutableSet.count)
        XCTAssertFalse(mutableSet.contains(values[0]))
        XCTAssertTrue(mutableSet.contains(values[1]))
    }

    func testSubscript() {
        mutableSet.insert(objectsIn: values)
        if values[0].object(SwiftStringObject.self) != nil {
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[0].object(SwiftStringObject.self)?.stringCol))
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[1].object(SwiftStringObject.self)?.stringCol))
            XCTAssertTrue(values.map {
                $0.object(SwiftStringObject.self)?.stringCol
            }.contains(mutableSet[2].object(SwiftStringObject.self)?.stringCol))
        } else {
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[0]))
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[1]))
            XCTAssertTrue(values.map { $0 }.contains(mutableSet[2]))
        }
    }
}

class MinMaxAnyRealmValueMutableSetTests<O: ObjectFactory, V: ValueFactory>: PrimitiveMutableSetTestsBase<O, V> where V.T == AnyRealmValue {
    func testMin() {
        XCTAssertNil(mutableSet.min())
        mutableSet.insert(objectsIn: values)
        XCTAssertEqual(mutableSet.min(), values.first)
    }

    func testMax() {
        XCTAssertNil(mutableSet.max())
        mutableSet.insert(objectsIn: values)
        XCTAssertEqual(mutableSet.max(), values.last)
    }
}

class AddableAnyRealmValueMutableSetTests<O: ObjectFactory, V: ValueFactory>: PrimitiveMutableSetTestsBase<O, V> where V.T == AnyRealmValue {
    func testSum() {
        XCTAssertEqual(mutableSet.sum().intValue, nil)
        mutableSet.insert(objectsIn: values)

        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@sum.self")! as! NSNumber)

        // An unmanaged collection will return a double
        if case let .double(d) = mutableSet.sum() {
            XCTAssertEqual(d, expected.doubleValue)
        } else if case let .decimal128(d) = mutableSet.sum() {
            // A managed collection of AnyRealmValue will return a Decimal128 for `sum()`
            XCTAssertEqual(d.doubleValue, expected.doubleValue, accuracy: 0.1)
        }
    }

    func testAverage() {
        XCTAssertNil(mutableSet.average() as V.AverageType?)
        mutableSet.insert(objectsIn: values)

        let expected = ((values.map(dynamicBridgeCast) as NSArray).value(forKeyPath: "@avg.self")! as! NSNumber)

        let v: AnyRealmValue? = mutableSet.average()
        // An unmanaged collection will return a double
        if case let .double(d) = v {
            XCTAssertEqual(d, expected.doubleValue)
        } else if case let .decimal128(d) = v {
            // A managed collection of AnyRealmValue will return a Decimal128 for `avg()`
            XCTAssertEqual(d.doubleValue, expected.doubleValue, accuracy: 0.1)
        }
    }
}

func addAnyRealmValueMutableSetTests<OF: ObjectFactory>(_ suite: XCTestSuite, _ type: OF.Type) {
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueBoolFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueStringFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueDataFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueObjectFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueObjectIdFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AnyRealmValueMutableSetTests<OF, AnyRealmValueUUIDFactory>._defaultTestSuite().tests.map(suite.addTest)

    _ = MinMaxAnyRealmValueMutableSetTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueMutableSetTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueMutableSetTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueMutableSetTests<OF, AnyRealmValueDateFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = MinMaxAnyRealmValueMutableSetTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)

    _ = AddableAnyRealmValueMutableSetTests<OF, AnyRealmValueIntFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueMutableSetTests<OF, AnyRealmValueFloatFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueMutableSetTests<OF, AnyRealmValueDoubleFactory>._defaultTestSuite().tests.map(suite.addTest)
    _ = AddableAnyRealmValueMutableSetTests<OF, AnyRealmValueDecimal128Factory>._defaultTestSuite().tests.map(suite.addTest)
}

class UnmanagedAnyRealmValueMutableSetTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Unmanaged Primitive Sets")
        addAnyRealmValueMutableSetTests(suite, UnmanagedObjectFactory.self)
        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}

class ManagedAnyRealmValueMutableSetTests: TestCase {
    class func _defaultTestSuite() -> XCTestSuite {
        let suite = XCTestSuite(name: "Managed Primitive Sets")
        addAnyRealmValueMutableSetTests(suite, ManagedObjectFactory.self)
        return suite
    }

    override class var defaultTestSuite: XCTestSuite {
        return _defaultTestSuite()
    }
}
