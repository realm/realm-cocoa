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

class CTTAggregateObject: Object {
    dynamic var intCol = 0
    dynamic var floatCol = 0 as Float
    dynamic var doubleCol = 0.0
    dynamic var boolCol = false
    dynamic var dateCol = NSDate()
    dynamic var trueCol = true
    let stringListCol = List<CTTStringObjectWithLink>()
    dynamic var linkCol: CTTLinkTarget?
}

class CTTAggregateObjectList: Object {
    let list = List<CTTAggregateObject>()
}

class CTTStringObjectWithLink: Object {
    dynamic var stringCol = ""
    dynamic var linkCol: CTTLinkTarget?
}

class CTTLinkTarget: Object {
    dynamic var id = 0
    let stringObjects = LinkingObjects(fromType: CTTStringObjectWithLink.self, property: "linkCol")
    let aggregateObjects = LinkingObjects(fromType: CTTAggregateObject.self, property: "linkCol")
}

class CTTStringList: Object {
    let array = List<CTTStringObjectWithLink>()
}

class RealmCollectionTypeTests: TestCase {
    var str1: CTTStringObjectWithLink?
    var str2: CTTStringObjectWithLink?
    var collection: AnyRealmCollection<CTTStringObjectWithLink>?

    func getCollection() -> AnyRealmCollection<CTTStringObjectWithLink> {
        fatalError("Abstract method. Try running tests using Control-U.")
    }

    func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        fatalError("Abstract method. Try running tests using Control-U.")
    }

    func makeAggregateableObjectsInWriteTransaction() -> [CTTAggregateObject] {
        let obj1 = CTTAggregateObject()
        obj1.intCol = 1
        obj1.floatCol = 1.1
        obj1.doubleCol = 1.11
        obj1.dateCol = NSDate(timeIntervalSince1970: 1)
        obj1.boolCol = false

        let obj2 = CTTAggregateObject()
        obj2.intCol = 2
        obj2.floatCol = 2.2
        obj2.doubleCol = 2.22
        obj2.dateCol = NSDate(timeIntervalSince1970: 2)
        obj2.boolCol = false

        let obj3 = CTTAggregateObject()
        obj3.intCol = 3
        obj3.floatCol = 2.2
        obj3.doubleCol = 2.22
        obj3.dateCol = NSDate(timeIntervalSince1970: 2)
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

        let str1 = CTTStringObjectWithLink()
        str1.stringCol = "1"
        self.str1 = str1

        let str2 = CTTStringObjectWithLink()
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

    override class func defaultTestSuite() -> XCTestSuite {
        // Don't run tests for the base class
        if isEqual(RealmCollectionTypeTests) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite()
    }

    func testRealm() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(collection.realm!.configuration.fileURL, realmWithTestPath().configuration.fileURL)
    }

    func testDescription() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        // swiftlint:disable:next line_length
        XCTAssertEqual(collection.description, "Results<CTTStringObjectWithLink> (\n\t[0] CTTStringObjectWithLink {\n\t\tstringCol = 1;\n\t\tlinkCol = (null);\n\t},\n\t[1] CTTStringObjectWithLink {\n\t\tstringCol = 2;\n\t\tlinkCol = (null);\n\t}\n)")
    }

    func testCount() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(2, collection.count)
        XCTAssertEqual(1, collection.filter(using: "stringCol = '1'").count)
        XCTAssertEqual(1, collection.filter(using: "stringCol = '2'").count)
        XCTAssertEqual(0, collection.filter(using: "stringCol = '0'").count)
    }

    func testIndexOfObject() {
        guard let collection = collection, str1 = str1, str2 = str2 else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(0, collection.index(of: str1)!)
        XCTAssertEqual(1, collection.index(of: str2)!)

        let str1Only = collection.filter(using: "stringCol = '1'")
        XCTAssertEqual(0, str1Only.index(of: str1)!)
        XCTAssertNil(str1Only.index(of: str2))
    }

    func testIndexOfPredicate() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        let pred1 = Predicate(format: "stringCol = '1'")
        let pred2 = Predicate(format: "stringCol = '2'")
        let pred3 = Predicate(format: "stringCol = '3'")

        XCTAssertEqual(0, collection.indexOfObject(for: pred1)!)
        XCTAssertEqual(1, collection.indexOfObject(for: pred2)!)
        XCTAssertNil(collection.indexOfObject(for: pred3))
    }

    func testIndexOfFormat() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(0, collection.indexOfObject(for: "stringCol = '1'")!)
        XCTAssertEqual(0, collection.indexOfObject(for: "stringCol = %@", "1")!)
        XCTAssertEqual(1, collection.indexOfObject(for: "stringCol = %@", "2")!)
        XCTAssertNil(collection.indexOfObject(for: "stringCol = %@", "3"))
    }

    func testSubscript() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(str1, collection[0])
        XCTAssertEqual(str2, collection[1])

        assertThrows(collection[200])
        assertThrows(collection[-200])
    }

    func testFirst() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(str1, collection.first!)
        XCTAssertEqual(str2, collection.filter(using: "stringCol = '2'").first!)
        XCTAssertNil(collection.filter(using: "stringCol = '3'").first)
    }

    func testLast() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(str2, collection.last!)
        XCTAssertEqual(str2, collection.filter(using: "stringCol = '2'").last!)
        XCTAssertNil(collection.filter(using: "stringCol = '3'").last)
    }

    func testValueForKey() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        let expected = collection.map { $0.stringCol }
        let actual = collection.value(forKey: "stringCol") as! [String]!
        XCTAssertEqual(expected, actual!)

        XCTAssertEqual(collection.map { $0 }, collection.value(forKey: "self") as! [CTTStringObjectWithLink])
    }

    func testSetValueForKey() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        try! realmWithTestPath().write {
            collection.setValue("hi there!", forKey: "stringCol")
        }
        let expected = (0..<collection.count).map { _ in "hi there!" }
        let actual = collection.map { $0.stringCol }
        XCTAssertEqual(expected, actual)
    }

    func testFilterFormat() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(1, collection.filter(using: "stringCol = '1'").count)
        XCTAssertEqual(1, collection.filter(using: "stringCol = %@", "1").count)
        XCTAssertEqual(1, collection.filter(using: "stringCol = %@", "2").count)
        XCTAssertEqual(0, collection.filter(using: "stringCol = %@", "3").count)
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
        XCTAssertEqual(1, outerArray.array.filter(using: "ANY array IN %@", realm.allObjects(ofType: SwiftObject.self)).count)
    }

    func testFilterResults() {
        let array = SwiftListOfSwiftObject()
        let realm = realmWithTestPath()
        array.array.append(SwiftObject())
        try! realm.write {
            realm.add(array)
        }
        XCTAssertEqual(1, realm.allObjects(ofType: SwiftListOfSwiftObject.self).filter(using: "ANY array IN %@", realm.allObjects(ofType: SwiftObject.self)).count)
    }

    func testFilterPredicate() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        let pred1 = Predicate(format: "stringCol = '1'")
        let pred2 = Predicate(format: "stringCol = '2'")
        let pred3 = Predicate(format: "stringCol = '3'")

        XCTAssertEqual(1, collection.filter(using: pred1).count)
        XCTAssertEqual(1, collection.filter(using: pred2).count)
        XCTAssertEqual(0, collection.filter(using: pred3).count)
    }

    func testSortWithProperty() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        var sorted = collection.sorted(onProperty: "stringCol", ascending: true)
        XCTAssertEqual("1", sorted[0].stringCol)
        XCTAssertEqual("2", sorted[1].stringCol)

        sorted = collection.sorted(onProperty: "stringCol", ascending: false)
        XCTAssertEqual("2", sorted[0].stringCol)
        XCTAssertEqual("1", sorted[1].stringCol)

        assertThrows(collection.sorted(onProperty: "noSuchCol", ascending: true), named: "Invalid sort property")
    }

    func testSortWithDescriptor() {
        let collection = getAggregateableCollection()

        var sorted = collection.sorted(with: [SortDescriptor(property: "intCol", ascending: true)])
        XCTAssertEqual(1, sorted[0].intCol)
        XCTAssertEqual(2, sorted[1].intCol)

        sorted = collection.sorted(with: [SortDescriptor(property: "doubleCol", ascending: false),
            SortDescriptor(property: "intCol", ascending: false)])
        XCTAssertEqual(2.22, sorted[0].doubleCol)
        XCTAssertEqual(3, sorted[0].intCol)
        XCTAssertEqual(2.22, sorted[1].doubleCol)
        XCTAssertEqual(2, sorted[1].intCol)
        XCTAssertEqual(1.11, sorted[2].doubleCol)

        assertThrows(collection.sorted(with: [SortDescriptor(property: "noSuchCol")]), named: "Invalid sort property")
    }

    func testMin() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(1, collection.minimumValue(ofProperty: "intCol") as Int!)
        XCTAssertEqual(Float(1.1), collection.minimumValue(ofProperty: "floatCol") as Float!)
        XCTAssertEqual(Double(1.11), collection.minimumValue(ofProperty: "doubleCol") as Double!)
        XCTAssertEqual(NSDate(timeIntervalSince1970: 1), collection.minimumValue(ofProperty: "dateCol") as NSDate!)

        assertThrows(collection.minimumValue(ofProperty: "noSuchCol") as Float!, named: "Invalid property name")
    }

    func testMax() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(3, collection.maximumValue(ofProperty: "intCol") as Int!)
        XCTAssertEqual(Float(2.2), collection.maximumValue(ofProperty: "floatCol") as Float!)
        XCTAssertEqual(Double(2.22), collection.maximumValue(ofProperty: "doubleCol") as Double!)
        XCTAssertEqual(NSDate(timeIntervalSince1970: 2), collection.maximumValue(ofProperty: "dateCol") as NSDate!)

        assertThrows(collection.maximumValue(ofProperty: "noSuchCol") as Float!, named: "Invalid property name")
    }

    func testSum() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(6, collection.sum(ofProperty: "intCol") as Int)
        XCTAssertEqualWithAccuracy(Float(5.5), collection.sum(ofProperty: "floatCol") as Float, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(Double(5.55), collection.sum(ofProperty: "doubleCol") as Double, accuracy: 0.001)

        assertThrows(collection.sum(ofProperty: "noSuchCol") as Float, named: "Invalid property name")
    }

    func testAverage() {
        let collection = getAggregateableCollection()
        XCTAssertEqual(2, collection.average(ofProperty: "intCol") as Int!)
        XCTAssertEqualWithAccuracy(Float(1.8333), collection.average(ofProperty: "floatCol") as Float!, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(Double(1.85), collection.average(ofProperty: "doubleCol") as Double!, accuracy: 0.001)

        assertThrows(collection.average(ofProperty: "noSuchCol")! as Float, named: "Invalid property name")
    }

    func testFastEnumeration() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }

        var str = ""
        for obj in collection {
            str += obj.stringCol
        }

        XCTAssertEqual(str, "12")
    }

    func testFastEnumerationWithMutation() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }

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

    func testArrayAggregateWithSwiftObjectDoesntThrow() {
        let collection = getAggregateableCollection()

        // Should not throw a type error.
        _ = collection.filter(using: "ANY stringListCol == %@", CTTStringObjectWithLink())
    }

    func testAddNotificationBlock() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }

        let theExpectation = expectation(withDescription: "")
        let token = collection.addNotificationBlock { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let collection):
                XCTAssertEqual(collection.count, 2)
                break
            case .update:
                XCTFail("Shouldn't happen")
                break
            case .error:
                XCTFail("Shouldn't happen")
                break
            }

            theExpectation.fulfill()
        }
        waitForExpectations(withTimeout: 1, handler: nil)

        token.stop()
    }

    func testValueForKeyPath() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }

        XCTAssertEqual(["1", "2"], collection.value(forKeyPath: "@unionOfObjects.stringCol") as! NSArray?)

        let theCollection = getAggregateableCollection()
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@count") as! NSNumber?)?.int64Value)
        XCTAssertEqual(3, (theCollection.value(forKeyPath: "@max.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(1, (theCollection.value(forKeyPath: "@min.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(6, (theCollection.value(forKeyPath: "@sum.intCol") as! NSNumber?)?.int64Value)
        XCTAssertEqual(2.0, (theCollection.value(forKeyPath: "@avg.intCol") as! NSNumber?)?.doubleValue)
    }

    func testInvalidate() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }

        XCTAssertFalse(collection.isInvalidated)
        realmWithTestPath().invalidate()
        XCTAssertTrue(collection.realm == nil || collection.isInvalidated)
    }
}

// MARK: Results

class ResultsTests: RealmCollectionTypeTests {
    override class func defaultTestSuite() -> XCTestSuite {
        // Don't run tests for the base class
        if isEqual(ResultsTests) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite()
    }

    func collectionBaseInWriteTransaction() -> Results<CTTStringObjectWithLink> {
        fatalError("abstract")
    }

    final func collectionBase() -> Results<CTTStringObjectWithLink> {
        var result: Results<CTTStringObjectWithLink>?
        try! realmWithTestPath().write {
            result = collectionBaseInWriteTransaction()
        }
        return result!
    }

    override func getCollection() -> AnyRealmCollection<CTTStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func testAssignListProperty() {
        try! realmWithTestPath().write {
            let array = CTTStringList()
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }

    func addObjectToResults() {
        let realm = realmWithTestPath()
        try! realm.write {
            realm.createObject(ofType: CTTStringObjectWithLink.self, populatedWith: ["a"])
        }
    }

    func testNotificationBlockUpdating() {
        let collection = collectionBase()

        var theExpectation = expectation(withDescription: "")
        var calls = 0
        let token = collection.addNotificationBlock { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let results):
                XCTAssertEqual(results.count, calls + 2)
                XCTAssertEqual(results, collection)
                break
            case .update(let results, _, _, _):
                XCTAssertEqual(results.count, calls + 2)
                XCTAssertEqual(results, collection)
                break
            case .error:
                XCTFail("Shouldn't happen")
                break
            }
            calls += 1
            theExpectation.fulfill()
        }
        waitForExpectations(withTimeout: 1, handler: nil)

        theExpectation = expectation(withDescription: "")
        addObjectToResults()
        waitForExpectations(withTimeout: 1, handler: nil)

        token.stop()
    }

    func testNotificationBlockChangeIndices() {
        let collection = collectionBase()

        var theExpectation = expectation(withDescription: "")
        var calls = 0
        let token = collection.addNotificationBlock { (change: RealmCollectionChange) in
            switch change {
            case .initial(let results):
                XCTAssertEqual(calls, 0)
                XCTAssertEqual(results.count, 2)
                break
            case .update(let results, let deletions, let insertions, let modifications):
                XCTAssertEqual(calls, 1)
                XCTAssertEqual(results.count, 3)
                XCTAssertEqual(deletions, [])
                XCTAssertEqual(insertions, [2])
                XCTAssertEqual(modifications, [])
                break
            case .error(let err):
                XCTFail(err.description)
                break
            }

            calls += 1
            theExpectation.fulfill()
        }
        waitForExpectations(withTimeout: 1, handler: nil)

        theExpectation = expectation(withDescription: "")
        addObjectToResults()
        waitForExpectations(withTimeout: 1, handler: nil)

        token.stop()
    }
}

class ResultsWithCustomInitializerTest: TestCase {
    func testValueForKey() {
        let realm = realmWithTestPath()
        try! realm.write {
            realm.add(SwiftCustomInitializerObject(stringVal: "A"))
        }

        let collection = realm.allObjects(ofType: SwiftCustomInitializerObject.self)
        let expected = collection.map { $0.stringCol }
        let actual = collection.value(forKey: "stringCol") as! [String]!
        XCTAssertEqual(expected, actual!)
        XCTAssertEqual(collection.map { $0 }, collection.value(forKey: "self") as! [CTTStringObjectWithLink])
    }
}

class ResultsFromTableTests: ResultsTests {

    override func collectionBaseInWriteTransaction() -> Results<CTTStringObjectWithLink> {
        return realmWithTestPath().allObjects(ofType: CTTStringObjectWithLink.self)
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        _ = makeAggregateableObjects()
        return AnyRealmCollection(realmWithTestPath().allObjects(ofType: CTTAggregateObject.self))
    }
}

class ResultsFromTableViewTests: ResultsTests {

    override func collectionBaseInWriteTransaction() -> Results<CTTStringObjectWithLink> {
        return realmWithTestPath().allObjects(ofType: CTTStringObjectWithLink.self).filter(using: "stringCol != ''")
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        _ = makeAggregateableObjects()
        return AnyRealmCollection(realmWithTestPath().allObjects(ofType: CTTAggregateObject.self).filter(using: "trueCol == true"))
    }
}

class ResultsFromLinkViewTests: ResultsTests {

    override func collectionBaseInWriteTransaction() -> Results<CTTStringObjectWithLink> {
        guard let str1 = str1, str2 = str2 else {
            fatalError("Test precondition failed")
        }
        let array = realmWithTestPath().createObject(ofType: CTTStringList.self, populatedWith: [[str1, str2]])
        return array.array.filter(using: Predicate(value: true))
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = CTTAggregateObjectList()
            realmWithTestPath().add(list!)
            list!.list.append(objectsIn: makeAggregateableObjectsInWriteTransaction())
        }
        return AnyRealmCollection(list!.list.filter(using: Predicate(value: true)))
    }

    override func addObjectToResults() {
        let realm = realmWithTestPath()
        try! realm.write {
            let array = realm.allObjects(ofType: CTTStringList.self).last!
            array.array.append(realm.createObject(ofType: CTTStringObjectWithLink.self, populatedWith: ["a"]))
        }
    }
}

// MARK: List

class ListRealmCollectionTypeTests: RealmCollectionTypeTests {
    override class func defaultTestSuite() -> XCTestSuite {
        // Don't run tests for the base class
        if isEqual(ListRealmCollectionTypeTests) {
            return XCTestSuite(name: "empty")
        }
        return super.defaultTestSuite()
    }

    func collectionBaseInWriteTransaction() -> List<CTTStringObjectWithLink> {
        fatalError("abstract")
    }

    final func collectionBase() -> List<CTTStringObjectWithLink> {
        var collection: List<CTTStringObjectWithLink>?
        try! realmWithTestPath().write {
            collection = collectionBaseInWriteTransaction()
        }
        return collection!
    }

    override func getCollection() -> AnyRealmCollection<CTTStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func testAssignListProperty() {
        try! realmWithTestPath().write {
            let array = CTTStringList()
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }

    override func testDescription() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        // swiftlint:disable:next line_length
        XCTAssertEqual(collection.description, "List<CTTStringObjectWithLink> (\n\t[0] CTTStringObjectWithLink {\n\t\tstringCol = 1;\n\t\tlinkCol = (null);\n\t},\n\t[1] CTTStringObjectWithLink {\n\t\tstringCol = 2;\n\t\tlinkCol = (null);\n\t}\n)")
    }

    func testAddNotificationBlockDirect() {
        let collection = collectionBase()

        let theExpectation = expectation(withDescription: "")
        let token = collection.addNotificationBlock { (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let list):
                XCTAssertEqual(list.count, 2)
                break
            case .update:
                XCTFail("Shouldn't happen")
                break
            case .error:
                XCTFail("Shouldn't happen")
                break
            }
            theExpectation.fulfill()
        }
        waitForExpectations(withTimeout: 1, handler: nil)

        token.stop()
    }
}

class ListStandaloneRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTStringObjectWithLink> {
        guard let str1 = str1, str2 = str2 else {
            fatalError("Test precondition failed")
        }
        return CTTStringList(value: [[str1, str2]]).array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        return AnyRealmCollection(CTTAggregateObjectList(value: [makeAggregateableObjects() as AnyObject]).list)
    }

    override func testRealm() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertNil(collection.realm)
    }

    override func testCount() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(2, collection.count)
    }

    override func testIndexOfObject() {
        guard let collection = collection, str1 = str1, str2 = str2 else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(0, collection.index(of: str1)!)
        XCTAssertEqual(1, collection.index(of: str2)!)
    }

    override func testSortWithDescriptor() {
        let collection = getAggregateableCollection()
        assertThrows(collection.sorted(with: [SortDescriptor(property: "intCol", ascending: true)]))
        assertThrows(collection.sorted(with: [SortDescriptor(property: "doubleCol", ascending: false),
            SortDescriptor(property: "intCol", ascending: false)]))
    }

    override func testFastEnumerationWithMutation() {
        // No standalone removal interface provided on RealmCollectionType
    }

    override func testFirst() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(str1, collection.first!)
    }

    override func testLast() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        XCTAssertEqual(str2, collection.last!)
    }

    // MARK: Things not implemented in standalone

    override func testSortWithProperty() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.sorted(onProperty: "stringCol", ascending: true))
        assertThrows(collection.sorted(onProperty: "noSuchCol", ascending: true))
    }

    override func testFilterFormat() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.filter(using: "stringCol = '1'"))
        assertThrows(collection.filter(using: "noSuchCol = '1'"))
    }

    override func testFilterPredicate() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        let pred1 = Predicate(format: "stringCol = '1'")
        let pred2 = Predicate(format: "noSuchCol = '2'")

        assertThrows(collection.filter(using: pred1))
        assertThrows(collection.filter(using: pred2))
    }

    override func testArrayAggregateWithSwiftObjectDoesntThrow() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.filter(using: "ANY stringListCol == %@", CTTStringObjectWithLink()))
    }

    override func testMin() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.minimumValue(ofProperty: "intCol") as Int!)
        assertThrows(collection.minimumValue(ofProperty: "floatCol") as Float!)
        assertThrows(collection.minimumValue(ofProperty: "doubleCol") as Double!)
        assertThrows(collection.minimumValue(ofProperty: "dateCol") as NSDate!)
    }

    override func testMax() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.maximumValue(ofProperty: "intCol") as Int!)
        assertThrows(collection.maximumValue(ofProperty: "floatCol") as Float!)
        assertThrows(collection.maximumValue(ofProperty: "doubleCol") as Double!)
        assertThrows(collection.maximumValue(ofProperty: "dateCol") as NSDate!)
    }

    override func testSum() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.sum(ofProperty: "intCol") as Int)
        assertThrows(collection.sum(ofProperty: "floatCol") as Float)
        assertThrows(collection.sum(ofProperty: "doubleCol") as Double)
    }

    override func testAverage() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.average(ofProperty: "intCol") as Int!)
        assertThrows(collection.average(ofProperty: "floatCol") as Float!)
        assertThrows(collection.average(ofProperty: "doubleCol") as Double!)
    }

    override func testAddNotificationBlock() {
        guard let collection = collection else {
            fatalError("Test precondition failed")
        }
        assertThrows(collection.addNotificationBlock { (changes: RealmCollectionChange) in })
    }

    override func testAddNotificationBlockDirect() {
        let collection = collectionBase()
        assertThrows(collection.addNotificationBlock { (changes: RealmCollectionChange) in })
    }
}

class ListNewlyAddedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTStringObjectWithLink> {
        guard let str1 = str1, str2 = str2 else {
            fatalError("Test precondition failure - a property was unexpectedly nil")
        }
        let array = CTTStringList(value: [[str1, str2] as AnyObject])
        realmWithTestPath().add(array)
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = CTTAggregateObjectList(value: [makeAggregateableObjectsInWriteTransaction() as AnyObject])
            realmWithTestPath().add(list!)
        }
        return AnyRealmCollection(list!.list)
    }
}

class ListNewlyCreatedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTStringObjectWithLink> {
        guard let str1 = str1, str2 = str2 else {
            fatalError("Test precondition failure - a property was unexpectedly nil")
        }
        let array = realmWithTestPath().createObject(ofType: CTTStringList.self, populatedWith: [[str1, str2] as AnyObject])
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            list = realmWithTestPath().createObject(ofType: CTTAggregateObjectList.self,
                                                    populatedWith: [makeAggregateableObjectsInWriteTransaction()])
        }
        return AnyRealmCollection(list!.list)
    }
}

class ListRetrievedRealmCollectionTypeTests: ListRealmCollectionTypeTests {
    override func collectionBaseInWriteTransaction() -> List<CTTStringObjectWithLink> {
        guard let str1 = str1, str2 = str2 else {
            fatalError("Test precondition failure - a property was unexpectedly nil")
        }
        _ = realmWithTestPath().createObject(ofType: CTTStringList.self, populatedWith: [[str1, str2] as AnyObject])
        let array = realmWithTestPath().allObjects(ofType: CTTStringList.self).first!
        return array.array
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var list: CTTAggregateObjectList?
        try! realmWithTestPath().write {
            _ = realmWithTestPath().createObject(ofType: CTTAggregateObjectList.self,
                                                 populatedWith: [makeAggregateableObjectsInWriteTransaction()])
            list = realmWithTestPath().allObjects(ofType: CTTAggregateObjectList.self).first
        }
        return AnyRealmCollection(list!.list)
    }
}

class LinkingObjectsCollectionTypeTests: RealmCollectionTypeTests {
    func collectionBaseInWriteTransaction() -> LinkingObjects<CTTStringObjectWithLink> {
        let target = realmWithTestPath().createObject(ofType: CTTLinkTarget.self, populatedWith: [0])
        for object in realmWithTestPath().allObjects(ofType: CTTStringObjectWithLink.self) {
            object.linkCol = target
        }
        return target.stringObjects
    }

    final func collectionBase() -> LinkingObjects<CTTStringObjectWithLink> {
        var result: LinkingObjects<CTTStringObjectWithLink>?
        try! realmWithTestPath().write {
            result = collectionBaseInWriteTransaction()
        }
        return result!
    }

    override func getCollection() -> AnyRealmCollection<CTTStringObjectWithLink> {
        return AnyRealmCollection(collectionBase())
    }

    override func getAggregateableCollection() -> AnyRealmCollection<CTTAggregateObject> {
        var target: CTTLinkTarget?
        try! realmWithTestPath().write {
            let objects = makeAggregateableObjectsInWriteTransaction()
            target = realmWithTestPath().createObject(ofType: CTTLinkTarget.self, populatedWith: [0])
            for object in objects {
                object.linkCol = target
            }
        }
        return AnyRealmCollection(target!.aggregateObjects)
    }

    override func testDescription() {
        guard let collection = collection else {
            fatalError("Test precondition failure - a property was unexpectedly nil")
        }
        // swiftlint:disable:next line_length
        XCTAssertEqual(collection.description, "LinkingObjects<CTTStringObjectWithLink> (\n\t[0] CTTStringObjectWithLink {\n\t\tstringCol = 1;\n\t\tlinkCol = CTTLinkTarget {\n\t\t\tid = 0;\n\t\t};\n\t},\n\t[1] CTTStringObjectWithLink {\n\t\tstringCol = 2;\n\t\tlinkCol = CTTLinkTarget {\n\t\t\tid = 0;\n\t\t};\n\t}\n)")
    }

    override func testAssignListProperty() {
        let array = CTTStringList()
        try! realmWithTestPath().write {
            realmWithTestPath().add(array)
            array["array"] = collectionBaseInWriteTransaction()
        }
    }
}
