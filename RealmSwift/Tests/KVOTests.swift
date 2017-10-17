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

var pkCounter = 0
func nextPrimaryKey() -> Int {
    pkCounter += 1
    return pkCounter
}

class KVOObject: Object {
    @objc dynamic var pk = nextPrimaryKey() // primary key for equality
    @objc dynamic var ignored: Int = 0

    @objc dynamic var boolCol: Bool = false
    @objc dynamic var int8Col: Int8 = 1
    @objc dynamic var int16Col: Int16 = 2
    @objc dynamic var int32Col: Int32 = 3
    @objc dynamic var int64Col: Int64 = 4
    @objc dynamic var floatCol: Float = 5
    @objc dynamic var doubleCol: Double = 6
    @objc dynamic var stringCol: String = ""
    @objc dynamic var binaryCol: Data = Data()
    @objc dynamic var dateCol: Date = Date(timeIntervalSince1970: 0)
    @objc dynamic var objectCol: KVOObject?
    let arrayCol = List<KVOObject>()
    let optIntCol = RealmOptional<Int>()
    let optFloatCol = RealmOptional<Float>()
    let optDoubleCol = RealmOptional<Double>()
    let optBoolCol = RealmOptional<Bool>()
    @objc dynamic var optStringCol: String?
    @objc dynamic var optBinaryCol: Data?
    @objc dynamic var optDateCol: Date?

    let arrayBool = List<Bool>()
    let arrayInt8 = List<Int8>()
    let arrayInt16 = List<Int16>()
    let arrayInt32 = List<Int32>()
    let arrayInt64 = List<Int64>()
    let arrayFloat = List<Float>()
    let arrayDouble = List<Double>()
    let arrayString = List<String>()
    let arrayBinary = List<Data>()
    let arrayDate = List<Date>()

    let arrayOptBool = List<Bool?>()
    let arrayOptInt8 = List<Int8?>()
    let arrayOptInt16 = List<Int16?>()
    let arrayOptInt32 = List<Int32?>()
    let arrayOptInt64 = List<Int64?>()
    let arrayOptFloat = List<Float?>()
    let arrayOptDouble = List<Double?>()
    let arrayOptString = List<String?>()
    let arrayOptBinary = List<Data?>()
    let arrayOptDate = List<Date?>()

    @objc dynamic var realmIntCol = RealmInteger()
    @objc dynamic var optRealmIntCol: RealmInteger?

    override class func primaryKey() -> String { return "pk" }
    override class func ignoredProperties() -> [String] { return ["ignored"] }
}

// Most of the testing of KVO functionality is done in the obj-c tests
// These tests just verify that it also works on Swift types
class KVOTests: TestCase {
    var realm: Realm! = nil

    override func setUp() {
        super.setUp()
        realm = try! Realm()
        realm.beginWrite()
    }

    override func tearDown() {
        realm.cancelWrite()
        realm = nil
        super.tearDown()
    }

    var changeDictionary: [NSKeyValueChangeKey: Any]?

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        changeDictionary = change
    }

    // swiftlint:disable:next cyclomatic_complexity
    func observeChange<T: Equatable>(_ obj: KVOObject, _ key: String, _ old: T?, _ new: T?,
                                     fileName: StaticString = #file, lineNumber: UInt = #line, _ block: () -> Void) {
        let kvoOptions: NSKeyValueObservingOptions = [.old, .new]
#if swift(>=3.2)
        func observe<Value>(_ keyPath: KeyPath<KVOObject, Value>) -> NSKeyValueObservation {
            return obj.observe(keyPath, options: kvoOptions) { _, change in
                self.changeDictionary = [
                    .oldKey: change.oldValue as? T as Any,
                    .newKey: change.newValue as? T as Any
                ]
            }
        }

        let observation: NSKeyValueObservation?
        switch key {
        case "boolCol":      observation = observe(\.boolCol)
        case "int8Col":      observation = observe(\.int8Col)
        case "int16Col":     observation = observe(\.int16Col)
        case "int32Col":     observation = observe(\.int32Col)
        case "int64Col":     observation = observe(\.int64Col)
        case "floatCol":     observation = observe(\.floatCol)
        case "doubleCol":    observation = observe(\.doubleCol)
        case "stringCol":    observation = observe(\.stringCol)
        case "binaryCol":    observation = observe(\.binaryCol)
        case "dateCol":      observation = observe(\.dateCol)
        case "objectCol":    observation = observe(\.objectCol)
        case "optStringCol": observation = observe(\.optStringCol)
        case "optBinaryCol": observation = observe(\.optBinaryCol)
        case "optDateCol":   observation = observe(\.optDateCol)
        case "invalidated":  observation = observe(\.invalidated)
        default:
            // some properties don't support Swift Smart KeyPaths, fall back to legacy KVO API
            observation = nil
            obj.addObserver(self, forKeyPath: key, options: kvoOptions, context: nil)
        }

        block()
        if let observation = observation {
            observation.invalidate()
        } else {
            obj.removeObserver(self, forKeyPath: key)
        }
#else
        obj.addObserver(self, forKeyPath: key, options: kvoOptions, context: nil)
        block()
        obj.removeObserver(self, forKeyPath: key)
#endif

        XCTAssert(changeDictionary != nil, "Did not get a notification", file: fileName, line: lineNumber)
        guard changeDictionary != nil else { return }

        let actualOld = changeDictionary![.oldKey]! as? T
        let actualNew = changeDictionary![.newKey]! as? T

        XCTAssert(old == actualOld,
                  "Old value: expected \(String(describing: old)), got \(String(describing: actualOld))",
                  file: fileName, line: lineNumber)
        XCTAssert(new == actualNew,
                  "New value: expected \(String(describing: new)), got \(String(describing: actualNew))",
                  file: fileName, line: lineNumber)

        changeDictionary = nil
    }

    func observeListChange(_ obj: NSObject, _ key: String, _ kind: NSKeyValueChange, _ indexes: NSIndexSet = NSIndexSet(index: 0),
                           fileName: StaticString = #file, lineNumber: UInt = #line, _ block: () -> Void) {
        obj.addObserver(self, forKeyPath: key, options: [.old, .new], context: nil)
        block()
        obj.removeObserver(self, forKeyPath: key)
        XCTAssert(changeDictionary != nil, "Did not get a notification", file: fileName, line: lineNumber)
        guard changeDictionary != nil else { return }

        let actualKind = NSKeyValueChange(rawValue: (changeDictionary![NSKeyValueChangeKey.kindKey] as! NSNumber).uintValue)!
        let actualIndexes = changeDictionary![NSKeyValueChangeKey.indexesKey]! as! NSIndexSet
        XCTAssert(actualKind == kind, "Change kind: expected \(kind), got \(actualKind)", file: fileName,
            line: lineNumber)
        XCTAssert(actualIndexes.isEqual(indexes), "Changed indexes: expected \(indexes), got \(actualIndexes)",
            file: fileName, line: lineNumber)

        changeDictionary = nil
    }

    func getObject(_ obj: KVOObject) -> (KVOObject, KVOObject) {
        return (obj, obj)
    }

    // Actual tests follow

    func testAllPropertyTypes() {
        let (obj, obs) = getObject(KVOObject())

        observeChange(obs, "boolCol", false, true) { obj.boolCol = true }
#if swift(>=3.2)
        observeChange(obs, "int8Col", 1 as Int8, 10) { obj.int8Col = 10 }
        observeChange(obs, "int16Col", 2 as Int16, 10) { obj.int16Col = 10 }
        observeChange(obs, "int32Col", 3 as Int32, 10) { obj.int32Col = 10 }
        observeChange(obs, "int64Col", 4 as Int64, 10) { obj.int64Col = 10 }
#else
        observeChange(obs, "int8Col", 1, 10) { obj.int8Col = 10 }
        observeChange(obs, "int16Col", 2, 10) { obj.int16Col = 10 }
        observeChange(obs, "int32Col", 3, 10) { obj.int32Col = 10 }
        observeChange(obs, "int64Col", 4, 10) { obj.int64Col = 10 }
#endif
        observeChange(obs, "floatCol", 5 as Float, 10) { obj.floatCol = 10 }
        observeChange(obs, "doubleCol", 6 as Double, 10) { obj.doubleCol = 10 }
        observeChange(obs, "stringCol", "", "abc") { obj.stringCol = "abc" }
        observeChange(obs, "objectCol", nil, obj) { obj.objectCol = obj }
        observeChange(obj, "realmIntCol", 0, 100) { obj.realmIntCol.value = 100 }
        observeChange(obj, "realmIntCol", 100, 200) { obj.realmIntCol = RealmInteger(value: 200) }
        observeChange(obj, "realmIntCol", 200, 201) { obj.realmIntCol.incrementValue(by: 1) }

        let data = "abc".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        observeChange(obs, "binaryCol", Data(), data) { obj.binaryCol = data }

        let date = Date(timeIntervalSince1970: 1)
        observeChange(obs, "dateCol", Date(timeIntervalSince1970: 0), date) { obj.dateCol = date }

        observeListChange(obs, "arrayCol", .insertion) { obj.arrayCol.append(obj) }
        observeListChange(obs, "arrayCol", .removal) { obj.arrayCol.removeAll() }

        observeChange(obs, "optIntCol", nil, 10) { obj.optIntCol.value = 10 }
        observeChange(obs, "optFloatCol", nil, 10.0) { obj.optFloatCol.value = 10 }
        observeChange(obs, "optDoubleCol", nil, 10.0) { obj.optDoubleCol.value = 10 }
        observeChange(obs, "optBoolCol", nil, true) { obj.optBoolCol.value = true }
        observeChange(obs, "optStringCol", nil, "abc") { obj.optStringCol = "abc" }
        observeChange(obs, "optBinaryCol", nil, data) { obj.optBinaryCol = data }
        observeChange(obs, "optDateCol", nil, date) { obj.optDateCol = date }
        observeChange(obj, "optRealmIntCol", nil, 100) { obj.optRealmIntCol = RealmInteger(value: 100) }
        observeChange(obj, "optRealmIntCol", 100, 200) { obj.optRealmIntCol!.value = 200 }
        observeChange(obj, "optRealmIntCol", 200, 201) { obj.optRealmIntCol!.incrementValue(by: 1) }

        observeChange(obs, "optIntCol", 10, nil) { obj.optIntCol.value = nil }
        observeChange(obs, "optFloatCol", 10.0, nil) { obj.optFloatCol.value = nil }
        observeChange(obs, "optDoubleCol", 10.0, nil) { obj.optDoubleCol.value = nil }
        observeChange(obs, "optBoolCol", true, nil) { obj.optBoolCol.value = nil }
        observeChange(obs, "optStringCol", "abc", nil) { obj.optStringCol = nil }
        observeChange(obs, "optBinaryCol", data, nil) { obj.optBinaryCol = nil }
        observeChange(obs, "optDateCol", date, nil) { obj.optDateCol = nil }
        observeChange(obj, "optRealmIntCol", 201, nil) { obj.optRealmIntCol!.value = nil }

        observeListChange(obs, "arrayBool", .insertion) { obj.arrayBool.append(true); }
        observeListChange(obs, "arrayInt8", .insertion) { obj.arrayInt8.append(10); }
        observeListChange(obs, "arrayInt16", .insertion) { obj.arrayInt16.append(10); }
        observeListChange(obs, "arrayInt32", .insertion) { obj.arrayInt32.append(10); }
        observeListChange(obs, "arrayInt64", .insertion) { obj.arrayInt64.append(10); }
        observeListChange(obs, "arrayFloat", .insertion) { obj.arrayFloat.append(10); }
        observeListChange(obs, "arrayDouble", .insertion) { obj.arrayDouble.append(10); }
        observeListChange(obs, "arrayString", .insertion) { obj.arrayString.append("abc"); }

        observeListChange(obs, "arrayOptBool", .insertion) { obj.arrayOptBool.append(true); }
        observeListChange(obs, "arrayOptInt8", .insertion) { obj.arrayOptInt8.append(10); }
        observeListChange(obs, "arrayOptInt16", .insertion) { obj.arrayOptInt16.append(10); }
        observeListChange(obs, "arrayOptInt32", .insertion) { obj.arrayOptInt32.append(10); }
        observeListChange(obs, "arrayOptInt64", .insertion) { obj.arrayOptInt64.append(10); }
        observeListChange(obs, "arrayOptFloat", .insertion) { obj.arrayOptFloat.append(10); }
        observeListChange(obs, "arrayOptDouble", .insertion) { obj.arrayOptDouble.append(10); }
        observeListChange(obs, "arrayOptString", .insertion) { obj.arrayOptString.append("abc"); }
        observeListChange(obs, "arrayOptBinary", .insertion) { obj.arrayOptBinary.append(data); }
        observeListChange(obs, "arrayOptDate", .insertion) { obj.arrayOptDate.append(date); }

        observeListChange(obs, "arrayOptBool", .insertion) { obj.arrayOptBool.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptInt8", .insertion) { obj.arrayOptInt8.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptInt16", .insertion) { obj.arrayOptInt16.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptInt32", .insertion) { obj.arrayOptInt32.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptInt64", .insertion) { obj.arrayOptInt64.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptFloat", .insertion) { obj.arrayOptFloat.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptDouble", .insertion) { obj.arrayOptDouble.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptString", .insertion) { obj.arrayOptString.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptDate", .insertion) { obj.arrayOptDate.insert(nil, at: 0); }
        observeListChange(obs, "arrayOptBinary", .insertion) { obj.arrayOptBinary.insert(nil, at: 0); }

        if obs.realm == nil {
            return
        }

        observeChange(obs, "invalidated", false, true) {
            self.realm.delete(obj)
        }

        let (obj2, obs2) = getObject(KVOObject())
        observeChange(obs2, "arrayCol.invalidated", false, true) {
            self.realm.delete(obj2)
        }
    }

    func testReadSharedSchemaFromObservedObject() {
        let obj = KVOObject()
        obj.addObserver(self, forKeyPath: "boolCol", options: [.old, .new], context: nil)
        XCTAssertEqual(type(of: obj).sharedSchema(), KVOObject.sharedSchema())
        obj.removeObserver(self, forKeyPath: "boolCol")
    }
}

class KVOPersistedTests: KVOTests {
    override func getObject(_ obj: KVOObject) -> (KVOObject, KVOObject) {
        realm.add(obj)
        return (obj, obj)
    }
}

class KVOMultipleAccessorsTests: KVOTests {
    override func getObject(_ obj: KVOObject) -> (KVOObject, KVOObject) {
        realm.add(obj)
        return (obj, realm.object(ofType: KVOObject.self, forPrimaryKey: obj.pk)!)
    }
}
