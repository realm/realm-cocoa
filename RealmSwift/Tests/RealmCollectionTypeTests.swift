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

// swiftlint:disable type_name

import XCTest
import RealmSwift

class CTTAggregateObject: Object {
    @objc dynamic var intCol = 0
    @objc dynamic var int8Col = 0
    @objc dynamic var int16Col = 0
    @objc dynamic var int32Col = 0
    @objc dynamic var int64Col = 0
    @objc dynamic var floatCol = 0 as Float
    @objc dynamic var doubleCol = 0.0
    @objc dynamic var boolCol = false
    @objc dynamic var dateCol = Date()
    @objc dynamic var trueCol = true
    let stringListCol = List<CTTNullableStringObjectWithLink>()
    let stringSetCol = MutableSet<CTTNullableStringObjectWithLink>()
    @objc dynamic var linkCol: CTTLinkTarget?
    @objc dynamic var childIntCol: CTTIntegerObject?
}

class CTTIntegerObject: Object {
    @objc dynamic var intCol = 0
}

class CTTAggregateObjectList: Object {
    let list = List<CTTAggregateObject>()
}

class CTTAggregateObjectSet: Object {
    let set = MutableSet<CTTAggregateObject>()
}

class CTTNullableStringObjectWithLink: Object {
    @objc dynamic var stringCol: String? = ""
    @objc dynamic var linkCol: CTTLinkTarget?
}

class CTTLinkTarget: Object {
    @objc dynamic var id = 0
    let stringObjects = LinkingObjects(fromType: CTTNullableStringObjectWithLink.self, property: "linkCol")
    let aggregateObjects = LinkingObjects(fromType: CTTAggregateObject.self, property: "linkCol")
}

class CTTStringList: Object {
    let array = List<CTTNullableStringObjectWithLink>()
}

class CTTStringSet: Object {
    let set = MutableSet<CTTNullableStringObjectWithLink>()
}

class RealmCollectionTypeTests: TestCase {
    var str1: CTTNullableStringObjectWithLink!
    var str2: CTTNullableStringObjectWithLink!
    var collection: AnyRealmCollection<CTTNullableStringObjectWithLink>!

    func getCollection() -> AnyRealmCollection<CTTNullableStringObjectWithLink> {
        fatalError("Abstract method. Try running tests using Control-U.")
    }

    func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        fatalError("Abstract method. Try running tests using Control-U.")
    }

    func makeAggregateableObjectsInWriteTransaction() -> [CTTAggregateObject] {
        let obj1 = CTTAggregateObject()
        obj1.intCol = 1
        obj1.int8Col = 1
        obj1.int16Col = 1
        obj1.int32Col = 1
        obj1.int64Col = 1
        obj1.floatCol = 1.1
        obj1.doubleCol = 1.11
        obj1.dateCol = Date(timeIntervalSince1970: 1)
        obj1.boolCol = false

        let obj2 = CTTAggregateObject()
        obj2.intCol = 2
        obj2.int8Col = 2
        obj2.int16Col = 2
        obj2.int32Col = 2
        obj2.int64Col = 2
        obj2.floatCol = 2.2
        obj2.doubleCol = 2.22
        obj2.dateCol = Date(timeIntervalSince1970: 2)
        obj2.boolCol = false

        let obj3 = CTTAggregateObject()
        obj3.intCol = 3
        obj3.int8Col = 3
        obj3.int16Col = 3
        obj3.int32Col = 3
        obj3.int64Col = 3
        obj3.floatCol = 2.2
        obj3.doubleCol = 2.22
        obj3.dateCol = Date(timeIntervalSince1970: 2)
        obj3.boolCol = false

        realmWithTestPath().add([obj1, obj2, obj3])
        return [obj1, obj2, obj3]
    }

    func makeAggregateableObjects() -> [CTTAggregateObject] {
        var result: [CTTAggregateObject]?
        try! realmWithTestPath().write {
            result = makeAggregateableObjectsInWriteTransaction()
        }
        return result!
    }

    override func setUp() {
        super.setUp()

        let str1 = CTTNullableStringObjectWithLink()
        str1.stringCol = "1"
        self.str1 = str1

        let str2 = CTTNullableStringObjectWithLink()
        str2.stringCol = "2"
        self.str2 = str2

        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(str1)
            realm.add(str2)
        }

        collection = AnyRealmCollection(getCollection())
    }

    override func tearDown() {
        str1 = nil
        str2 = nil
        collection = nil

        super.tearDown()
    }

    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(RealmCollectionTypeTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func testRealm() {
        XCTAssertEqual(collection.realm!.configuration.fileURL, realmWithTestPath().configuration.fileURL)
    }

    func testDescription() {
        // swiftlint:disable:next line_length
        assertMatches(collection.description, "Results<CTTNullableStringObjectWithLink> <0x[0-9a-f]+> \\(\n\t\\[0\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 1;\n\t\tlinkCol = \\(null\\);\n\t\\},\n\t\\[1\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 2;\n\t\tlinkCol = \\(null\\);\n\t\\}\n\\)")
    }

    func testCount() {
        XCTAssertEqual(2, collection.count)
        XCTAssertEqual(1, collection.filter("stringCol = '1'").count)
        XCTAssertEqual(1, collection.filter("stringCol = '2'").count)
        XCTAssertEqual(0, collection.filter("stringCol = '0'").count)
    }

    func testIndexOfObject() {
        XCTAssertEqual(0, collection.index(of: str1)!)
        XCTAssertEqual(1, collection.index(of: str2)!)

        let str1Only = collection.filter("stringCol = '1'")
        XCTAssertEqual(0, str1Only.index(of: str1)!)
        XCTAssertNil(str1Only.index(of: str2))
    }

    func testIndexOfPredicate() {
        let pred1 = NSPredicate(format: "stringCol = '1'")
        let pred2 = NSPredicate(format: "stringCol = '2'")
        let pred3 = NSPredicate(format: "stringCol = '3'")

        XCTAssertEqual(0, collection.index(matching: pred1)!)
        XCTAssertEqual(1, collection.index(matching: pred2)!)
        XCTAssertNil(collection.index(matching: pred3))
    }

    func testIndexOfFormat() {
        XCTAssertEqual(0, collection.index(matching: "stringCol = '1'")!)
        XCTAssertEqual(0, collection.index(matching: "stringCol = %@", "1")!)
        XCTAssertEqual(1, collection.index(matching: "stringCol = %@", "2")!)
        XCTAssertNil(collection.index(matching: "stringCol = %@", "3"))
    }

    func testSubscript() {
        assertEqual(str1, collection[0])
        assertEqual(str2, collection[1])

        assertThrows(collection[200])
        assertThrows(collection[-200])
    }

    func testFirst() {
        assertEqual(str1, collection.first!)
        assertEqual(str2, collection.filter("stringCol = '2'").first!)
        XCTAssertNil(collection.filter("stringCol = '3'").first)
    }

    func testLast() {
        assertEqual(str2, collection.last!)
        assertEqual(str2, collection.filter("stringCol = '2'").last!)
        XCTAssertNil(collection.filter("stringCol = '3'").last)
    }

    func testValueForKey() {
        let expected = Array(collection.map { $0.stringCol })
        let actual = collection.value(forKey: "stringCol") as! [String]?
        XCTAssertEqual(expected as! [String], actual!)

        assertEqual(collection.map { $0 }, collection.value(forKey: "self") as! [CTTNullableStringObjectWithLink])
    }

    func testSetValueForKey() {
        try! realmWithTestPath().write {
            collection.setValue("hi there!", forKey: "stringCol")
        }
        let expected = Array((0..<collection.count).map { _ in "hi there!" })
        let actual = Array(collection.map { $0.stringCol })
        XCTAssertEqual(expected, actual as! [String])
    }

    func testFilterFormat() {
        XCTAssertEqual(1, collection.filter("stringCol = '1'").count)
        XCTAssertEqual(1, collection.filter("stringCol = %@", "1").count)
        XCTAssertEqual(1, collection.filter("stringCol = %@", "2").count)
        XCTAssertEqual(0, collection.filter("stringCol = %@", "3").count)
    }

    func testFilterWithAnyVarags() {
        let firstCriterion: String? = "1"
        let secondCriterion: String = "2"
        let thirdCriterion: String? = nil
        let result = collection.filter("stringCol = %@ OR stringCol = %@ OR stringCol = %@",
                                       firstCriterion as Any, secondCriterion as Any, thirdCriterion as Any)
        XCTAssertEqual(2, result.count)
    }

    func testFilterList() {
        let outerArray = SwiftDoubleListOfSwiftObject()
        let realm = realmWithTestPath()
        let innerArray = SwiftListOfSwiftObject()
        innerArray.array.append(SwiftObject())
        outerArray.array.append(innerArray)
        try! realm.write {
            realm.add(outerArray)
        }
        XCTAssertEqual(1, outerArray.array.filter("ANY array IN %@", realm.objects(SwiftObject.self)).count)
    }

    func testFilterResults() {
        let array = SwiftListOfSwiftObject()
        let realm = realmWithTestPath()
        array.array.append(SwiftObject())
        try! realm.write {
            realm.add(array)
        }
        XCTAssertEqual(1, realm.objects(SwiftListOfSwiftObject.self).filter("ANY array IN %@", realm.objects(SwiftObject.self)).count)
    }

    func testFilterPredicate() {
        let pred1 = NSPredicate(format: "stringCol = '1'")
        let pred2 = NSPredicate(format: "stringCol = '2'")
        let pred3 = NSPredicate(format: "stringCol = '3'")

        XCTAssertEqual(1, collection.filter(pred1).count)
        XCTAssertEqual(1, collection.filter(pred2).count)
        XCTAssertEqual(0, collection.filter(pred3).count)
    }

    func testSortWithProperty() {
        var sorted = collection.sorted(byKeyPath: "stringCol", ascending: true)
        XCTAssertEqual("1", sorted[0].stringCol)
        XCTAssertEqual("2", sorted[1].stringCol)

        sorted = collection.sorted(byKeyPath: "stringCol", ascending: false)
        XCTAssertEqual("2", sorted[0].stringCol)
        XCTAssertEqual("1", sorted[1].stringCol)

        sorted = collection.sorted(byKeyPath: "linkCol.id", ascending: true)
        XCTAssertEqual("1", sorted[0].stringCol)
        XCTAssertEqual("2", sorted[1].stringCol)

        assertThrows(collection.sorted(byKeyPath: "noSuchCol", ascending: true),
                     reason: "Cannot sort on key path 'noSuchCol': property 'CTTNullableStringObjectWithLink.noSuchCol' does not exist")
    }

    func testSortWithSwiftKeyPath() {
        var sorted = collection.sorted(by: \.stringCol, ascending: true)
        XCTAssertEqual("1", sorted[0].stringCol)
        XCTAssertEqual("2", sorted[1].stringCol)

        sorted = collection.sorted(by: \.stringCol, ascending: false)
        XCTAssertEqual("2", sorted[0].stringCol)
        XCTAssertEqual("1", sorted[1].stringCol)

        sorted = collection.sorted(by: \.linkCol?.id, ascending: true)
        XCTAssertEqual("1", sorted[0].stringCol)
        XCTAssertEqual("2", sorted[1].stringCol)
    }

    func testSortWithDescriptor() {
        let collection = getAggregateableCollection()

        let notActuallySorted = collection.sorted(by: [])
        collection.enumerated().forEach { (e) in
            assertEqual(e.element, notActuallySorted[e.offset])
        }

        let sorted = collection.sorted(by: [SortDescriptor(keyPath: "intCol", ascending: true)])
        sorted.enumerated().forEach { (e) in
            XCTAssertEqual(e.offset+1, sorted[e.offset].intCol)
        }
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: "noSuchCol")]),
                     reason: "Cannot sort on key path 'noSuchCol': property 'CTTAggregateObject.noSuchCol' does not exist")
    }

    func testSortWithDescriptorBySwiftKeyPath() {
        let collection = getAggregateableCollection()

        let notActuallySorted = collection.sorted(by: [])
        collection.enumerated().forEach { (e) in
            assertEqual(e.element, notActuallySorted[e.offset])
        }

        let sorted = collection.sorted(by: [SortDescriptor(keyPath: \CTTAggregateObject.intCol,
                                                           ascending: true)])
        sorted.enumerated().forEach { (e) in
            XCTAssertEqual(e.offset+1, sorted[e.offset].intCol)
        }
    }

    func testMin() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(1, collection.min(ofProperty: "intCol") as NSNumber?)
        XCTAssertEqual(1, collection.min(ofProperty: "intCol") as Int?)
        XCTAssertEqual(1, collection.min(ofProperty: "int8Col") as NSNumber?)
        XCTAssertEqual(1, collection.min(ofProperty: "int8Col") as Int8?)
        XCTAssertEqual(1, collection.min(ofProperty: "int16Col") as NSNumber?)
        XCTAssertEqual(1, collection.min(ofProperty: "int16Col") as Int16?)
        XCTAssertEqual(1, collection.min(ofProperty: "int32Col") as NSNumber?)
        XCTAssertEqual(1, collection.min(ofProperty: "int32Col") as Int32?)
        XCTAssertEqual(1, collection.min(ofProperty: "int64Col") as NSNumber?)
        XCTAssertEqual(1, collection.min(ofProperty: "int64Col") as Int64?)
        XCTAssertEqual(1.1 as Float as NSNumber, collection.min(ofProperty: "floatCol") as NSNumber?)
        XCTAssertEqual(1.1, collection.min(ofProperty: "floatCol") as Float?)
        XCTAssertEqual(1.11, collection.min(ofProperty: "doubleCol") as NSNumber?)
        XCTAssertEqual(1.11, collection.min(ofProperty: "doubleCol") as Double?)
        XCTAssertEqual(NSDate(timeIntervalSince1970: 1), collection.min(ofProperty: "dateCol") as NSDate?)
        XCTAssertEqual(Date(timeIntervalSince1970: 1), collection.min(ofProperty: "dateCol") as Date?)

        assertThrows(collection.min(ofProperty: "noSuchCol") as NSNumber?, named: "Invalid property name")
        assertThrows(collection.min(ofProperty: "noSuchCol") as Float?, named: "Invalid property name")
    }

    func testMinBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(1, collection.min(of: \.intCol))
        XCTAssertEqual(1, collection.min(of: \.int8Col))
        XCTAssertEqual(1, collection.min(of: \.int16Col))
        XCTAssertEqual(1, collection.min(of: \.int32Col))
        XCTAssertEqual(1, collection.min(of: \.int64Col))
        XCTAssertEqual(1.1, collection.min(of: \.floatCol))
        XCTAssertEqual(1.11, collection.min(of: \.doubleCol))
        XCTAssertEqual(Date(timeIntervalSince1970: 1), collection.min(of: \.dateCol))
    }

    func testMax() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(3, collection.max(ofProperty: "intCol") as NSNumber?)
        XCTAssertEqual(3, collection.max(ofProperty: "intCol") as Int?)
        XCTAssertEqual(3, collection.max(ofProperty: "int8Col") as NSNumber?)
        XCTAssertEqual(3, collection.max(ofProperty: "int8Col") as Int8?)
        XCTAssertEqual(3, collection.max(ofProperty: "int16Col") as NSNumber?)
        XCTAssertEqual(3, collection.max(ofProperty: "int16Col") as Int16?)
        XCTAssertEqual(3, collection.max(ofProperty: "int32Col") as NSNumber?)
        XCTAssertEqual(3, collection.max(ofProperty: "int32Col") as Int32?)
        XCTAssertEqual(3, collection.max(ofProperty: "int64Col") as NSNumber?)
        XCTAssertEqual(3, collection.max(ofProperty: "int64Col") as Int64?)
        XCTAssertEqual(2.2 as Float as NSNumber, collection.max(ofProperty: "floatCol") as NSNumber?)
        XCTAssertEqual(2.2, collection.max(ofProperty: "floatCol") as Float?)
        XCTAssertEqual(2.22, collection.max(ofProperty: "doubleCol") as NSNumber?)
        XCTAssertEqual(2.22, collection.max(ofProperty: "doubleCol") as Double?)
        XCTAssertEqual(NSDate(timeIntervalSince1970: 2), collection.max(ofProperty: "dateCol") as NSDate?)
        XCTAssertEqual(Date(timeIntervalSince1970: 2), collection.max(ofProperty: "dateCol") as Date?)

        assertThrows(collection.max(ofProperty: "noSuchCol") as NSNumber?, named: "Invalid property name")
        assertThrows(collection.max(ofProperty: "noSuchCol") as Float?, named: "Invalid property name")
    }

    func testMaxBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(3, collection.max(of: \.intCol))
        XCTAssertEqual(3, collection.max(of: \.int8Col))
        XCTAssertEqual(3, collection.max(of: \.int16Col))
        XCTAssertEqual(3, collection.max(of: \.int32Col))
        XCTAssertEqual(3, collection.max(of: \.int64Col))
        XCTAssertEqual(2.2, collection.max(of: \.floatCol))
        XCTAssertEqual(2.22, collection.max(of: \.doubleCol))
        XCTAssertEqual(2.22, collection.max(of: \.doubleCol))
        XCTAssertEqual(Date(timeIntervalSince1970: 2), collection.max(of: \.dateCol))
    }

    func testSum() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(6, collection.sum(ofProperty: "intCol") as NSNumber)
        XCTAssertEqual(6, collection.sum(ofProperty: "intCol") as Int)
        XCTAssertEqual(6, collection.sum(ofProperty: "int8Col") as NSNumber)
        XCTAssertEqual(6, collection.sum(ofProperty: "int8Col") as Int8)
        XCTAssertEqual(6, collection.sum(ofProperty: "int16Col") as NSNumber)
        XCTAssertEqual(6, collection.sum(ofProperty: "int16Col") as Int16)
        XCTAssertEqual(6, collection.sum(ofProperty: "int32Col") as NSNumber)
        XCTAssertEqual(6, collection.sum(ofProperty: "int32Col") as Int32)
        XCTAssertEqual(6, collection.sum(ofProperty: "int64Col") as NSNumber)
        XCTAssertEqual(6, collection.sum(ofProperty: "int64Col") as Int64)
        XCTAssertEqual(5.5, (collection.sum(ofProperty: "floatCol") as NSNumber).floatValue,
                                   accuracy: 0.001)
        XCTAssertEqual(5.5, collection.sum(ofProperty: "floatCol") as Float, accuracy: 0.001)
        XCTAssertEqual(5.55, (collection.sum(ofProperty: "doubleCol") as NSNumber).doubleValue,
                                   accuracy: 0.001)
        XCTAssertEqual(5.55, collection.sum(ofProperty: "doubleCol") as Double, accuracy: 0.001)

        assertThrows(collection.sum(ofProperty: "noSuchCol") as NSNumber, named: "Invalid property name")
        assertThrows(collection.sum(ofProperty: "noSuchCol") as Float, named: "Invalid property name")
    }

    func testSumBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(6, collection.sum(of: \.intCol))
        XCTAssertEqual(6, collection.sum(of: \.int8Col))
        XCTAssertEqual(6, collection.sum(of: \.int16Col))
        XCTAssertEqual(6, collection.sum(of: \.int32Col))
        XCTAssertEqual(6, collection.sum(of: \.int64Col))
        XCTAssertEqual(5.5, (collection.sum(of: \.floatCol)),
                                   accuracy: 0.001)
        XCTAssertEqual(5.55, (collection.sum(of: \.doubleCol)),
                                   accuracy: 0.001)
    }

    func testAverage() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(2, collection.average(ofProperty: "intCol"))
        XCTAssertEqual(2, collection.average(ofProperty: "int8Col"))
        XCTAssertEqual(2, collection.average(ofProperty: "int16Col"))
        XCTAssertEqual(2, collection.average(ofProperty: "int32Col"))
        XCTAssertEqual(2, collection.average(ofProperty: "int64Col"))
        XCTAssertEqual(1.8333, collection.average(ofProperty: "floatCol")!, accuracy: 0.001)
        XCTAssertEqual(1.85, collection.average(ofProperty: "doubleCol")!, accuracy: 0.001)

        assertThrows(collection.average(ofProperty: "noSuchCol") as Double?, named: "Invalid property name")
    }

    func testAverageBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(2, collection.average(of: \.intCol))
        XCTAssertEqual(2, collection.average(of: \.int8Col))
        XCTAssertEqual(2, collection.average(of: \.int16Col))
        XCTAssertEqual(2, collection.average(of: \.int32Col))
        XCTAssertEqual(2, collection.average(of: \.int64Col))
        XCTAssertEqual(1.8333, collection.average(of: \.floatCol)!, accuracy: 0.001)
        XCTAssertEqual(1.85, collection.average(of: \.doubleCol)!, accuracy: 0.001)
    }

    func testFastEnumeration() {
        var str = ""
        for obj in collection {
            str += obj.stringCol!
        }

        XCTAssertEqual(str, "12")
    }

    func testFastEnumerationWithMutation() {
        let realm = realmWithTestPath()
        try! realm.write {
            for obj in collection {
                realm.delete(obj)
            }
        }
        XCTAssertEqual(0, collection.count)
    }

    func testAssignListProperty() {
        // no way to make RealmCollectionType conform to NSFastEnumeration
        // so test the concrete collections directly.
        fatalError("abstract")
    }

    func testAssignSetProperty() {
        // no way to make RealmCollectionType conform to NSFastEnumeration
        // so test the concrete collections directly.
        fatalError("abstract")
    }

    func testArrayAggregateWithSwiftObjectDoesntThrow() {
        let collection = getAggregateableCollection()

        // Should not throw a type error.
        XCTAssertEqual(0, collection.filter("ANY stringListCol == %@", CTTNullableStringObjectWithLink()).count)
    }

    func testObserve() {
        let ex = expectation(description: "initial notification")
        let token = collection.observe { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let collection):
                XCTAssertEqual(collection.count, 2)
            case .update:
                XCTFail("Shouldn't happen")
            case .error:
                XCTFail("Shouldn't happen")
            }

            ex.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // add a second notification and wait for it
        var ex2 = expectation(description: "second initial notification")
        let token2 = collection.observe { _ in
            ex2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // make a write and implicitly verify that only the unskipped
        // notification is called (the first would error on .update)
        ex2 = expectation(description: "change notification")
        let realm = realmWithTestPath()
        realm.beginWrite()
        realm.delete(collection)
        try! realm.commitWrite(withoutNotifying: [token])
        waitForExpectations(timeout: 1, handler: nil)

        token.invalidate()
        token2.invalidate()
    }

    func observeOnQueue<Collection: RealmCollection>(_ collection: Collection) where Collection.Element: Object {
        let sema = DispatchSemaphore(value: 0)
        let token = collection.observe(on: queue) { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let collection):
                XCTAssertEqual(collection.count, 2)
            case .update(let collection, let deletions, _, _):
                XCTAssertEqual(collection.count, 0)
                XCTAssertEqual(deletions, [0, 1])
            case .error:
                XCTFail("Shouldn't happen")
            }

            sema.signal()
        }
        sema.wait()

        let realm = realmWithTestPath()
        try! realm.write {
            realm.delete(collection)
        }
        sema.wait()

        token.invalidate()
    }

    func testObserveOnQueue() {
        observeOnQueue(collection)
    }

    func testValueForKeyPath() {
        XCTAssertEqual(["1", "2"], collection.value(forKeyPath: "@unionOfObjects.stringCol") as! NSArray?)

        let theCollection = getAggregateableCollection()
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@count") as! NSNumber?)?.int64Value)
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@max.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(1, (theCollection.value(forKeyPath: "@min.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(6, (theCollection.value(forKeyPath: "@sum.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(2.0, (theCollection.value(forKeyPath: "@avg.intCol") as! NSNumber?)?.doubleValue)
    }

    func testInvalidate() {
        XCTAssertFalse(collection.isInvalidated)
        realmWithTestPath().invalidate()
        XCTAssertTrue(collection.realm == nil || collection.isInvalidated)
    }

    func testIsFrozen() {
        XCTAssertFalse(collection.isFrozen)
        XCTAssertTrue(collection.freeze().isFrozen)
    }

    func testThaw() {
        let frozen = collection.freeze()
        XCTAssertTrue(frozen.isFrozen)

        let frozenRealm = frozen.realm!
        assertThrows(try! frozenRealm.write {}, reason: "Can't perform transactions on a frozen Realm")

        let live = frozen.thaw()
        XCTAssertFalse(live!.isFrozen)

        let liveRealm = live!.realm!
        try! liveRealm.write { liveRealm.delete(live!) }
        XCTAssertTrue(live!.isEmpty)
        XCTAssertFalse(frozen.isEmpty)
    }

    func testThawFromDifferentThread() {
        let frozen = collection.freeze()
        XCTAssertTrue(frozen.isFrozen)

        dispatchSyncNewThread {
            let live = frozen.thaw()
            XCTAssertFalse(live!.isFrozen)

            let liveRealm = live!.realm!
            try! liveRealm.write { liveRealm.delete(live!) }
            XCTAssertTrue(live!.isEmpty)
            XCTAssertFalse(frozen.isEmpty)
        }
    }


    func testThawPreviousVersion() {
        let frozen = collection.freeze()
        XCTAssertTrue(frozen.isFrozen)
        XCTAssertEqual(collection.count, frozen.count)

        let realm = collection.realm!
        try! realm.write({ realm.delete(collection) })
        XCTAssertNotEqual(frozen.count, collection.count, "Frozen collections should not change")

        let live = frozen.thaw()
        XCTAssertTrue(live!.isEmpty, "Thawed collection should reflect transactions since the original reference was frozen")
        XCTAssertFalse(frozen.isEmpty)
        XCTAssertEqual(live!.count, self.collection.count)
    }

    func testThawUpdatedOnDifferentThread() {
        let tsr = ThreadSafeReference(to: collection)
        var frozen: AnyRealmCollection<CTTNullableStringObjectWithLink>?
        var frozenQuery: Results<CTTNullableStringObjectWithLink>?

        XCTAssertEqual(collection.count, 2) // stringCol "1" and "2"
        XCTAssertEqual(collection.filter("stringCol == %@", "3").count, 0)

        dispatchSyncNewThread {
            let realm = try! Realm(configuration: self.collection.realm!.configuration)
            let collection = realm.resolve(tsr)!
            try! realm.write({ collection.first!.stringCol = "3" })
            try! realm.write({ realm.delete(collection.last!) })

            let query = collection.filter("stringCol == %@", "1")
            frozen = collection.freeze() // Results::Mode::TableView
            frozenQuery = query.freeze() // Results::Mode::Query

        }

        let thawed = frozen!.thaw()
        XCTAssertEqual(frozen!.count, 1)
        XCTAssertEqual(frozen!.first?.stringCol, "3")
        XCTAssertEqual(frozen!.filter("stringCol == %@", "1").count, 0)
        XCTAssertEqual(frozen!.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(frozen!.filter("stringCol == %@", "3").count, 1)

        XCTAssertEqual(thawed!.count, 2)
        XCTAssertEqual(thawed!.first?.stringCol, "1")
        XCTAssertEqual(thawed!.filter("stringCol == %@", "1").count, 1)
        XCTAssertEqual(thawed!.filter("stringCol == %@", "2").count, 1)
        XCTAssertEqual(thawed!.filter("stringCol == %@", "3").count, 0)

        XCTAssertEqual(collection.count, 2)
        XCTAssertEqual(collection.first?.stringCol, "1")
        XCTAssertEqual(collection.filter("stringCol == %@", "1").count, 1)
        XCTAssertEqual(collection.filter("stringCol == %@", "2").count, 1)
        XCTAssertEqual(collection.filter("stringCol == %@", "3").count, 0)

        let thawedQuery = frozenQuery!.thaw()
        XCTAssertEqual(frozenQuery!.count, 0)
        XCTAssertEqual(frozenQuery!.first?.stringCol, nil)
        XCTAssertEqual(frozenQuery!.filter("stringCol == %@", "1").count, 0)
        XCTAssertEqual(frozenQuery!.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(frozenQuery!.filter("stringCol == %@", "3").count, 0)

        XCTAssertEqual(thawedQuery!.count, 1)
        XCTAssertEqual(thawedQuery!.first?.stringCol, "1")
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "1").count, 1)
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "3").count, 0)

        collection.realm!.refresh()

        XCTAssertEqual(thawed!.count, 1)
        XCTAssertEqual(thawed!.first?.stringCol, "3")
        XCTAssertEqual(thawed!.filter("stringCol == %@", "1").count, 0)
        XCTAssertEqual(thawed!.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(thawed!.filter("stringCol == %@", "3").count, 1)

        XCTAssertEqual(thawedQuery!.count, 0)
        XCTAssertEqual(thawedQuery!.first?.stringCol, nil)
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "1").count, 0)
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(thawedQuery!.filter("stringCol == %@", "3").count, 0)

        XCTAssertEqual(collection.count, 1)
        XCTAssertEqual(collection.first?.stringCol, "3")
        XCTAssertEqual(collection.filter("stringCol == %@", "1").count, 0)
        XCTAssertEqual(collection.filter("stringCol == %@", "2").count, 0)
        XCTAssertEqual(collection.filter("stringCol == %@", "3").count, 1)
    }

    func testThawDeletedParent() {
        let frozenElement = collection.first!.freeze()
        XCTAssertTrue(frozenElement.isFrozen)

        let realm = collection.realm!
        try! realm.write({ realm.delete(collection) })
        XCTAssertNil(collection.first)
        XCTAssertNotNil(frozenElement)

        let thawed = frozenElement.thaw()
        XCTAssertNil(thawed)
    }

    func testFreezeFromWrongThread() {
        dispatchSyncNewThread {
            self.assertThrows(self.collection.freeze(), reason: "Realm accessed from incorrect thread")
        }
    }

    func testAccessFrozenCollectionFromDifferentThread() {
        let frozen = collection.freeze()
        dispatchSyncNewThread {
            XCTAssertEqual(frozen[0].stringCol, "1")
            XCTAssertEqual(frozen[1].stringCol, "2")
        }
    }

    func testObserveFrozenCollection() {
        let frozen = collection.freeze()
        assertThrows(frozen.observe({ _ in }),
                     reason: "Frozen Realms do not change and do not have change notifications.")
    }

    func testQueryFrozenCollection() {
        let frozen = collection.freeze()
        XCTAssertEqual(frozen.filter("stringCol = '1'").count, 1)
        XCTAssertEqual(frozen.filter("stringCol = '2'").count, 1)
        XCTAssertEqual(frozen.filter("stringCol = '3'").count, 0)
        XCTAssertTrue(frozen.filter("stringCol = '3'").isFrozen)
    }

    func testFilterWithInt8Property() {
        _ = makeAggregateableObjects()
        var results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int8Col = %d", Int8(0))
        XCTAssertEqual(results.count, 0)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int8Col = %d", Int8(1))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int8Col = %d", Int8(2))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int8Col = %d", Int8(3))
        XCTAssertEqual(results.count, 1)
    }

    func testFilterWithInt16Property() {
        _ = makeAggregateableObjects()
        var results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int16Col = %d", Int16(0))
        XCTAssertEqual(results.count, 0)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int16Col = %d", Int16(1))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int16Col = %d", Int16(2))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int16Col = %d", Int16(3))
        XCTAssertEqual(results.count, 1)
    }

    func testFilterWithInt32Property() {
        _ = makeAggregateableObjects()
        var results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int32Col = %d", Int32(0))
        XCTAssertEqual(results.count, 0)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int32Col = %d", Int32(1))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int32Col = %d", Int32(2))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int32Col = %d", Int32(3))
        XCTAssertEqual(results.count, 1)
    }

    func testFilterWithInt64Property() {
        _ = makeAggregateableObjects()
        var results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int64Col = %d", Int64(0))
        XCTAssertEqual(results.count, 0)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int64Col = %d", Int64(1))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int64Col = %d", Int64(2))
        XCTAssertEqual(results.count, 1)
        results = realmWithTestPath().objects(CTTAggregateObject.self).filter("int64Col = %d", Int64(3))
        XCTAssertEqual(results.count, 1)
    }
}

// MARK: Results

class ResultsTests: RealmCollectionTypeTests {
    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(ResultsTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func collectionBaseInWriteTransaction() -> Results<CTTNullableStringObjectWithLink> {
        fatalError("abstract")
    }

    final func collectionBase() -> Results<CTTNullableStringObjectWithLink> {
        var result: Results<CTTNullableStringObjectWithLink>?
        try! realmWithTestPath().write {
            result = collectionBaseInWriteTransaction()
        }
        return result!
    }

    override func getCollection() -> AnyRealmCollection<CTTNullableStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func testAssignListProperty() {
        try! realmWithTestPath().write {
            let array = CTTStringList()
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }

    override func testAssignSetProperty() {
        try! realmWithTestPath().write {
            let set = CTTStringSet()
            realmWithTestPath().add(set)
            set["set"] = collectionBaseInWriteTransaction()
        }
    }

    func addObjectToResults() {
        let realm = realmWithTestPath()
        try! realm.write {
            realm.create(CTTNullableStringObjectWithLink.self, value: ["a"])
        }
    }

    func testNotificationBlockUpdating() {
        let collection = collectionBase()

        var theExpectation = expectation(description: "")
        var calls = 0
        let token = collection.observe { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let results):
                XCTAssertEqual(results.count, calls + 2)
                XCTAssertEqual(results, collection)
            case .update(let results, _, _, _):
                XCTAssertEqual(results.count, calls + 2)
                XCTAssertEqual(results, collection)
            case .error:
                XCTFail("Shouldn't happen")
            }
            calls += 1
            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        theExpectation = expectation(description: "")
        addObjectToResults()
        waitForExpectations(timeout: 1, handler: nil)

        token.invalidate()
    }

    func testNotificationBlockChangeIndices() {
        let collection = collectionBase()

        var theExpectation = expectation(description: "")
        var calls = 0
        let token = collection.observe { (change: RealmCollectionChange) in
            switch change {
            case .initial(let results):
                XCTAssertEqual(calls, 0)
                XCTAssertEqual(results.count, 2)
            case .update(let results, let deletions, let insertions, let modifications):
                XCTAssertEqual(calls, 1)
                XCTAssertEqual(results.count, 3)
                XCTAssertEqual(deletions, [])
                XCTAssertEqual(insertions, [2])
                XCTAssertEqual(modifications, [])
            case .error(let error):
                XCTFail(String(describing: error))
            }

            calls += 1
            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        theExpectation = expectation(description: "")
        addObjectToResults()
        waitForExpectations(timeout: 1, handler: nil)

        token.invalidate()
    }

    func testObserveDirectOnQueue() {
        observeOnQueue(collectionBase())
    }
}

class ResultsWithCustomInitializerTests: TestCase {
    func testValueForKey() {
        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(SwiftCustomInitializerObject(stringVal: "A"))
        }

        let collection = realm.objects(SwiftCustomInitializerObject.self)
        let expected = Array(collection.map { $0.stringCol })
        let actual = collection.value(forKey: "stringCol") as! [String]?
        XCTAssertEqual(expected, actual!)
        assertEqual(collection.map { $0 }, collection.value(forKey: "self") as! [SwiftCustomInitializerObject])
    }
}

class ResultsDistinctTests: TestCase {
    func testDistinctResultsUsingKeyPaths() {
        let realm = realmWithTestPath()

        let obj1 = CTTAggregateObject()
        obj1.intCol = 1
        obj1.trueCol = true
        let obj2 = CTTAggregateObject()
        obj2.intCol = 1
        obj2.trueCol = true
        let obj3 = CTTAggregateObject()
        obj3.intCol = 1
        obj3.trueCol = false
        let obj4 = CTTAggregateObject()
        obj4.intCol = 2
        obj4.trueCol = false

        let childObj1 = CTTIntegerObject()
        childObj1.intCol = 1
        obj1.childIntCol = childObj1

        let childObj2 = CTTIntegerObject()
        childObj2.intCol = 1
        obj2.childIntCol = childObj2

        let childObj3 = CTTIntegerObject()
        childObj3.intCol = 2
        obj3.childIntCol = childObj3

        try! realm.write {
            realm.add(obj1)
            realm.add(obj2)
            realm.add(obj3)
            realm.add(obj4)
        }

        let collection = realm.objects(CTTAggregateObject.self)
        var distinctResults = collection.distinct(by: ["intCol"])
        var expected = [["int": 1], ["int": 2]]
        var actual = Array(distinctResults.map { ["int": $0.intCol] })
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])

        distinctResults = collection.distinct(by: ["intCol", "trueCol"])
        expected = [["int": 1, "true": 1], ["int": 1, "true": 0], ["int": 2, "true": 0]]
        actual = distinctResults.map { ["int": $0.intCol, "true": $0.trueCol ? 1 : 0] }
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])

        distinctResults = collection.distinct(by: ["childIntCol.intCol"])
        expected = [["int": 1], ["int": 2]]
        actual = distinctResults.map { ["int": $0.childIntCol!.intCol] }
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])

        assertThrows(collection.distinct(by: ["childCol"]))
        assertThrows(collection.distinct(by: ["@sum.intCol"]))
        assertThrows(collection.distinct(by: ["stringListCol"]))
    }

    func testDistinctResultsUsingSwiftKeyPaths() {
        let realm = realmWithTestPath()

        let obj1 = CTTAggregateObject()
        obj1.intCol = 1
        obj1.trueCol = true
        let obj2 = CTTAggregateObject()
        obj2.intCol = 1
        obj2.trueCol = true
        let obj3 = CTTAggregateObject()
        obj3.intCol = 1
        obj3.trueCol = false
        let obj4 = CTTAggregateObject()
        obj4.intCol = 2
        obj4.trueCol = false

        let childObj1 = CTTIntegerObject()
        childObj1.intCol = 1
        obj1.childIntCol = childObj1

        let childObj2 = CTTIntegerObject()
        childObj2.intCol = 1
        obj2.childIntCol = childObj2

        let childObj3 = CTTIntegerObject()
        childObj3.intCol = 2
        obj3.childIntCol = childObj3

        try! realm.write {
            realm.add(obj1)
            realm.add(obj2)
            realm.add(obj3)
            realm.add(obj4)
        }

        let collection = realm.objects(CTTAggregateObject.self)
        var distinctResults = collection.distinct(by: [\CTTAggregateObject.intCol])
        var expected = [["int": 1], ["int": 2]]
        var actual = Array(distinctResults.map { ["int": $0.intCol] })
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])

        distinctResults = collection.distinct(by: [\CTTAggregateObject.intCol, \CTTAggregateObject.trueCol])
        expected = [["int": 1, "true": 1], ["int": 1, "true": 0], ["int": 2, "true": 0]]
        actual = distinctResults.map { ["int": $0.intCol, "true": $0.trueCol ? 1 : 0] }
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])

        distinctResults = collection.distinct(by: [\CTTAggregateObject.childIntCol?.intCol])
        expected = [["int": 1], ["int": 2]]
        actual = distinctResults.map { ["int": $0.childIntCol!.intCol] }
        XCTAssertEqual(expected as NSObject, actual as NSObject)
        assertEqual(distinctResults.map { $0 }, distinctResults.value(forKey: "self") as! [CTTAggregateObject])
    }
}

class ResultsFromTableTests: ResultsTests {
    override func collectionBaseInWriteTransaction() -> Results<CTTNullableStringObjectWithLink> {
        return realmWithTestPath().objects(CTTNullableStringObjectWithLink.self)
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        _ = makeAggregateableObjects()
        return AnyRealmCollection(realmWithTestPath().objects(CTTAggregateObject.self))
    }
}

class ResultsFromTableViewTests: ResultsTests {
    override func collectionBaseInWriteTransaction() -> Results<CTTNullableStringObjectWithLink> {
        return realmWithTestPath().objects(CTTNullableStringObjectWithLink.self).filter("stringCol != ''")
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        _ = makeAggregateableObjects()
        return AnyRealmCollection(realmWithTestPath().objects(CTTAggregateObject.self).filter("trueCol == true"))
    }
}

class ResultsFromLinkViewTests: ResultsTests {
    override func collectionBaseInWriteTransaction() -> Results<CTTNullableStringObjectWithLink> {
        let array = realmWithTestPath().create(CTTStringList.self, value: [[str1, str2]])
        return array.array.filter(NSPredicate(value: true))
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = CTTAggregateObjectList()
            realmWithTestPath().add(list!)
            list!.list.append(objectsIn: makeAggregateableObjectsInWriteTransaction())
        }
        return AnyRealmCollection(list!.list.filter(NSPredicate(value: true)))
    }

    override func addObjectToResults() {
        let realm = realmWithTestPath()
        try! realm.write {
            let array = realm.objects(CTTStringList.self).last!
            array.array.append(realm.create(CTTNullableStringObjectWithLink.self, value: ["a"]))
        }
    }
}

// MARK: List

class ListRealmCollectionTypeTests: RealmCollectionTypeTests {
    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(ListRealmCollectionTypeTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func collectionBaseInWriteTransaction() -> List<CTTNullableStringObjectWithLink> {
        fatalError("abstract")
    }

    final func collectionBase() -> List<CTTNullableStringObjectWithLink> {
        var collection: List<CTTNullableStringObjectWithLink>?
        try! realmWithTestPath().write {
            collection = collectionBaseInWriteTransaction()
        }
        return collection!
    }

    override func getCollection() -> AnyRealmCollection<CTTNullableStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func testAssignListProperty() {
        try! realmWithTestPath().write {
            let array = CTTStringList()
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }

    override func testAssignSetProperty() { }

    override func testDescription() {
        // swiftlint:disable:next line_length
        assertMatches(collection.description, "List<CTTNullableStringObjectWithLink> <0x[0-9a-f]+> \\(\n\t\\[0\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 1;\n\t\tlinkCol = \\(null\\);\n\t\\},\n\t\\[1\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 2;\n\t\tlinkCol = \\(null\\);\n\t\\}\n\\)")
    }

    func testObserveDirect() {
        let collection = collectionBase()

        var theExpectation = expectation(description: "")
        let token = collection.observe { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let collection):
                XCTAssertEqual(collection.count, 2)
            case .update:
                XCTFail("Shouldn't happen")
            case .error:
                XCTFail("Shouldn't happen")
            }

            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // add a second notification and wait for it
        theExpectation = expectation(description: "")
        let token2 = collection.observe { _ in
            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // make a write and implicitly verify that only the unskipped
        // notification is called (the first would error on .update)
        theExpectation = expectation(description: "")
        let realm = realmWithTestPath()
        realm.beginWrite()
        realm.delete(collection)
        try! realm.commitWrite(withoutNotifying: [token])
        waitForExpectations(timeout: 1, handler: nil)

        token.invalidate()
        token2.invalidate()
    }

    func testObserveDirectOnQueue() {
        observeOnQueue(collectionBase())
    }
}

class ListUnmanagedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTNullableStringObjectWithLink> {
        return CTTStringList(value: [[str1, str2]]).array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        return AnyRealmCollection(CTTAggregateObjectList(value: [makeAggregateableObjects()]).list)
    }

    override func testRealm() {
        XCTAssertNil(collection.realm)
    }

    override func testCount() {
        XCTAssertEqual(2, collection.count)
    }

    override func testIndexOfObject() {
        XCTAssertEqual(0, collection.index(of: str1)!)
        XCTAssertEqual(1, collection.index(of: str2)!)
    }

    override func testSortWithDescriptor() {
        let collection = getAggregateableCollection()
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: "intCol", ascending: true)]))
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: "doubleCol", ascending: false),
            SortDescriptor(keyPath: "intCol", ascending: false)]))
    }

    override func testSortWithDescriptorBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: \CTTAggregateObject.intCol, ascending: true)]))
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: \CTTAggregateObject.doubleCol, ascending: false),
            SortDescriptor(keyPath: "intCol", ascending: false)]))
    }

    override func testFastEnumerationWithMutation() {
        // No standalone removal interface provided on RealmCollectionType
    }

    override func testFirst() {
        XCTAssertEqual(str1, collection.first!)
    }

    override func testLast() {
        XCTAssertEqual(str2, collection.last!)
    }

    // MARK: Things not implemented in standalone

    override func testSortWithProperty() {
        assertThrows(collection.sorted(byKeyPath: "stringCol", ascending: true))
        assertThrows(collection.sorted(byKeyPath: "noSuchCol", ascending: true))
    }

    override func testSortWithSwiftKeyPath() {
        assertThrows(collection.sorted(by: \.stringCol, ascending: true))
    }

    override func testFilterFormat() {
        assertThrows(collection.filter("stringCol = '1'"))
        assertThrows(collection.filter("noSuchCol = '1'"))
    }

    override func testFilterPredicate() {
        let pred1 = NSPredicate(format: "stringCol = '1'")
        let pred2 = NSPredicate(format: "noSuchCol = '2'")

        assertThrows(collection.filter(pred1))
        assertThrows(collection.filter(pred2))
    }

    override func testFilterWithAnyVarags() {
        // Functionality not supported for standalone lists; don't test.
    }

    override func testArrayAggregateWithSwiftObjectDoesntThrow() {
        assertThrows(collection.filter("ANY stringListCol == %@", CTTNullableStringObjectWithLink()))
    }

    override func testObserve() {
        assertThrows(collection.observe { _ in })
    }

    override func testObserveOnQueue() {
        assertThrows(collection.observe(on: DispatchQueue(label: "bg")) { _ in })
    }

    override func testObserveDirect() {
        let collection = collectionBase()
        assertThrows(collection.observe { _ in })
    }

    override func testObserveDirectOnQueue() {
        let collection = collectionBase()
        assertThrows(collection.observe(on: DispatchQueue(label: "bg")) { _ in })
    }

    func testFreeze() {
        assertThrows(collection.freeze(),
                     reason: "This method may only be called on RLMArray instances retrieved from an RLMRealm")
    }

    override func testIsFrozen() {
        XCTAssertFalse(collection.isFrozen)
    }

    override func testThaw() {
    }

    override func testThawFromDifferentThread() {
    }

    override func testThawPreviousVersion() {
    }

    override func testThawDeletedParent() {
    }

    override func testThawUpdatedOnDifferentThread() {
    }

    override func testFreezeFromWrongThread() {
    }

    override func testAccessFrozenCollectionFromDifferentThread() {
    }

    override func testObserveFrozenCollection() {
    }

    override func testQueryFrozenCollection() {
    }
}

class ListNewlyAddedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTNullableStringObjectWithLink> {
        let array = CTTStringList(value: [[str1, str2]])
        realmWithTestPath().add(array)
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = CTTAggregateObjectList(value: [makeAggregateableObjectsInWriteTransaction()])
            realmWithTestPath().add(list!)
        }
        return AnyRealmCollection(list!.list)
    }
}

class ListNewlyCreatedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTNullableStringObjectWithLink> {
        let array = realmWithTestPath().create(CTTStringList.self, value: [[str1, str2]])
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = realmWithTestPath().create(CTTAggregateObjectList.self,
                                                    value: [makeAggregateableObjectsInWriteTransaction()])
        }
        return AnyRealmCollection(list!.list)
    }
}

class ListRetrievedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTNullableStringObjectWithLink> {
        _ = realmWithTestPath().create(CTTStringList.self, value: [[str1, str2]])
        let array = realmWithTestPath().objects(CTTStringList.self).first!
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            _ = realmWithTestPath().create(CTTAggregateObjectList.self,
                                                 value: [makeAggregateableObjectsInWriteTransaction()])
            list = realmWithTestPath().objects(CTTAggregateObjectList.self).first
        }
        return AnyRealmCollection(list!.list)
    }
}

// MARK: MutableSet

class MutableSetRealmCollectionTypeTests: RealmCollectionTypeTests {
    override class var defaultTestSuite: XCTestSuite {
        // Don't run tests for the base class
        if isEqual(MutableSetRealmCollectionTypeTests.self) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite
    }

    func collectionBaseInWriteTransaction() -> MutableSet<CTTNullableStringObjectWithLink> {
        fatalError("abstract")
    }

    final func collectionBase() -> MutableSet<CTTNullableStringObjectWithLink> {
        var collection: MutableSet<CTTNullableStringObjectWithLink>?
        try! realmWithTestPath().write {
            collection = collectionBaseInWriteTransaction()
        }
        return collection!
    }

    override func getCollection() -> AnyRealmCollection<CTTNullableStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func testAssignListProperty() { }

    override func testIndexOfObject() { }

    override func testIndexOfFormat() { }

    override func testIndexOfPredicate() { }

    override func testSubscript() { }

    override func testFirst() { }

    override func testLast() { }

    override func testValueForKey() {
        let expected = Set(collection.map { $0.stringCol })
        let actual = collection.value(forKey: "stringCol") as! Set<String>?
        XCTAssertEqual(expected, actual!)
        // comparing value(forKey: "self") won't work because an NSSet will be produced, we don't know
        // the order of the objects and using [NSSet contains] won't work for a linked object.
    }

    override func testValueForKeyPath() {
        let theCollection = getAggregateableCollection()
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@count") as! NSNumber?)?.int64Value)
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@max.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(1, (theCollection.value(forKeyPath: "@min.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(6, (theCollection.value(forKeyPath: "@sum.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(2.0, (theCollection.value(forKeyPath: "@avg.intCol") as! NSNumber?)?.doubleValue)
    }

    override func testAssignSetProperty() {
        try! realmWithTestPath().write {
            let set = CTTStringSet()
            realmWithTestPath().add(set)
            set["set"] = collectionBaseInWriteTransaction()
        }
    }

    override func testAccessFrozenCollectionFromDifferentThread() {
        let frozen = collection.freeze()
        dispatchSyncNewThread {
            let o = frozen.map { $0.stringCol }
            XCTAssertTrue(o.contains("1"))
            XCTAssertTrue(o.contains("2"))
        }
    }

    override func testFastEnumeration() {
        var str = ""
        for obj in collection {
            str += obj.stringCol!
        }

        XCTAssertTrue((str == "12") || (str == "21"))
    }

    override func testDescription() {
        // ordering is not guaranteed, so handle that the objects could be in any position
        // swiftlint:disable:next line_length
        assertMatches(collection.description, "MutableSet<CTTNullableStringObjectWithLink> <0x[0-9a-f]+> \\(\n\t\\[0\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = [0-9]+;\n\t\tlinkCol = \\(null\\);\n\t\\},\n\t\\[1\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = [0-9]+;\n\t\tlinkCol = \\(null\\);\n\t\\}\n\\)")
    }

    func testObserveDirect() {
        let collection = collectionBase()

        var theExpectation = expectation(description: "")
        let token = collection.observe { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let collection):
                XCTAssertEqual(collection.count, 2)
            case .update:
                XCTFail("Shouldn't happen")
            case .error:
                XCTFail("Shouldn't happen")
            }

            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // add a second notification and wait for it
        theExpectation = expectation(description: "")
        let token2 = collection.observe { _ in
            theExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        // make a write and implicitly verify that only the unskipped
        // notification is called (the first would error on .update)
        theExpectation = expectation(description: "")
        let realm = realmWithTestPath()
        realm.beginWrite()
        realm.delete(collection)
        try! realm.commitWrite(withoutNotifying: [token])
        waitForExpectations(timeout: 1, handler: nil)

        token.invalidate()
        token2.invalidate()
    }

    func testObserveDirectOnQueue() {
        observeOnQueue(collectionBase())
    }
}

class MutableSetUnmanagedRealmCollectionTypeTests: MutableSetRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> MutableSet<CTTNullableStringObjectWithLink> {
        return CTTStringSet(value: [[str1, str2]]).set
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        return AnyRealmCollection(CTTAggregateObjectSet(value: [makeAggregateableObjects()]).set)
    }

    override func testRealm() {
        XCTAssertNil(collection.realm)
    }

    override func testCount() {
        XCTAssertEqual(2, collection.count)
    }

    override func testSortWithDescriptor() {
        let collection = getAggregateableCollection()
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: "intCol", ascending: true)]))
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: "doubleCol", ascending: false),
            SortDescriptor(keyPath: "intCol", ascending: false)]))
    }

    override func testSortWithDescriptorBySwiftKeyPath() {
        let collection = getAggregateableCollection()
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: \CTTAggregateObject.intCol, ascending: true)]))
        assertThrows(collection.sorted(by: [SortDescriptor(keyPath: \CTTAggregateObject.doubleCol, ascending: false),
            SortDescriptor(keyPath: \CTTAggregateObject.intCol, ascending: false)]))
    }

    override func testFastEnumerationWithMutation() {
        // No standalone removal interface provided on RealmCollectionType
    }

    // MARK: Things not implemented in standalone

    override func testSortWithProperty() {
        assertThrows(collection.sorted(byKeyPath: "stringCol", ascending: true))
        assertThrows(collection.sorted(byKeyPath: "noSuchCol", ascending: true))
    }

    override func testSortWithSwiftKeyPath() {
        assertThrows(collection.sorted(by: \.stringCol, ascending: true))
    }

    override func testFilterFormat() {
        assertThrows(collection.filter("stringCol = '1'"))
        assertThrows(collection.filter("noSuchCol = '1'"))
    }

    override func testFilterPredicate() {
        let pred1 = NSPredicate(format: "stringCol = '1'")
        let pred2 = NSPredicate(format: "noSuchCol = '2'")

        assertThrows(collection.filter(pred1))
        assertThrows(collection.filter(pred2))
    }

    override func testFilterWithAnyVarags() {
        // Functionality not supported for standalone lists; don't test.
    }

    override func testArrayAggregateWithSwiftObjectDoesntThrow() {
        assertThrows(collection.filter("ANY stringListCol == %@", CTTNullableStringObjectWithLink()))
    }

    override func testObserve() {
        assertThrows(collection.observe { _ in })
    }

    override func testObserveOnQueue() {
        assertThrows(collection.observe(on: DispatchQueue(label: "bg")) { _ in })
    }

    override func testObserveDirect() {
        let collection = collectionBase()
        assertThrows(collection.observe { _ in })
    }

    override func testObserveDirectOnQueue() {
        let collection = collectionBase()
        assertThrows(collection.observe(on: DispatchQueue(label: "bg")) { _ in })
    }

    func testFreeze() {
        assertThrows(collection.freeze(),
                     reason: "This method may only be called on RLMSet instances retrieved from an RLMRealm")
    }

    override func testIsFrozen() {
        XCTAssertFalse(collection.isFrozen)
    }

    override func testThaw() {
    }

    override func testThawFromDifferentThread() {
    }

    override func testThawPreviousVersion() {
    }

    override func testThawDeletedParent() {
    }

    override func testThawUpdatedOnDifferentThread() {
    }

    override func testFreezeFromWrongThread() {
    }

    override func testAccessFrozenCollectionFromDifferentThread() {
    }

    override func testObserveFrozenCollection() {
    }

    override func testQueryFrozenCollection() {
    }
}

class MutableSetNewlyAddedRealmCollectionTypeTests: MutableSetRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> MutableSet<CTTNullableStringObjectWithLink> {
        let set = CTTStringSet(value: [[str1, str2]])
        realmWithTestPath().add(set)
        return set.set
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var set: CTTAggregateObjectSet?
        try! realmWithTestPath().write {
            set = CTTAggregateObjectSet(value: [makeAggregateableObjectsInWriteTransaction()])
            realmWithTestPath().add(set!)
        }
        return AnyRealmCollection(set!.set)
    }
}

class MutableSetNewlyCreatedRealmCollectionTypeTests: MutableSetRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> MutableSet<CTTNullableStringObjectWithLink> {
        let set = realmWithTestPath().create(CTTStringSet.self, value: [[str1, str2]])
        return set.set
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var set: CTTAggregateObjectSet?
        try! realmWithTestPath().write {
            set = realmWithTestPath().create(CTTAggregateObjectSet.self,
                                                    value: [makeAggregateableObjectsInWriteTransaction()])
        }
        return AnyRealmCollection(set!.set)
    }
}

class MutableSetRetrievedRealmCollectionTypeTests: MutableSetRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> MutableSet<CTTNullableStringObjectWithLink> {
        _ = realmWithTestPath().create(CTTStringSet.self, value: [[str1, str2]])
        let set = realmWithTestPath().objects(CTTStringSet.self).first!
        return set.set
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var set: CTTAggregateObjectSet?
        try! realmWithTestPath().write {
            _ = realmWithTestPath().create(CTTAggregateObjectSet.self,
                                                 value: [makeAggregateableObjectsInWriteTransaction()])
            set = realmWithTestPath().objects(CTTAggregateObjectSet.self).first
        }
        return AnyRealmCollection(set!.set)
    }
}
class LinkingObjectsCollectionTypeTests: RealmCollectionTypeTests {
    func collectionBaseInWriteTransaction() -> LinkingObjects<CTTNullableStringObjectWithLink> {
        let target = realmWithTestPath().create(CTTLinkTarget.self, value: [0])
        for object in realmWithTestPath().objects(CTTNullableStringObjectWithLink.self) {
            object.linkCol = target
        }
        return target.stringObjects
    }

    final func collectionBase() -> LinkingObjects<CTTNullableStringObjectWithLink> {
        var result: LinkingObjects<CTTNullableStringObjectWithLink>?
        try! realmWithTestPath().write {
            result = collectionBaseInWriteTransaction()
        }
        return result!
    }

    override func getCollection() -> AnyRealmCollection<CTTNullableStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var target: CTTLinkTarget?
        try! realmWithTestPath().write {
            let objects = makeAggregateableObjectsInWriteTransaction()
            target = realmWithTestPath().create(CTTLinkTarget.self, value: [0])
            for object in objects {
                object.linkCol = target
            }
        }
        return AnyRealmCollection(target!.aggregateObjects)
    }

    override func testDescription() {
        // swiftlint:disable:next line_length
        assertMatches(collection.description, "LinkingObjects<CTTNullableStringObjectWithLink> <0x[0-9a-f]+> \\(\n\t\\[0\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 1;\n\t\tlinkCol = CTTLinkTarget \\{\n\t\t\tid = 0;\n\t\t\\};\n\t\\},\n\t\\[1\\] CTTNullableStringObjectWithLink \\{\n\t\tstringCol = 2;\n\t\tlinkCol = CTTLinkTarget \\{\n\t\t\tid = 0;\n\t\t\\};\n\t\\}\n\\)")
    }

    override func testAssignListProperty() {
        let array = CTTStringList()
        try! realmWithTestPath().write {
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }

    override func testAssignSetProperty() {
        let set = CTTStringSet()
        try! realmWithTestPath().write {
            realmWithTestPath().add(set)
            set["set"] = collectionBaseInWriteTransaction()
        }
    }

    func testObserveDirectOnQueue() {
        observeOnQueue(collectionBase())
    }
}
