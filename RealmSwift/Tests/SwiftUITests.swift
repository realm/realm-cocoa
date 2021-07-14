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

#if canImport(SwiftUI) && canImport(Combine)
import XCTest
import RealmSwift
import SwiftUI
import Combine

@objcMembers class SwiftUIObject: Object, ObjectKeyIdentifiable {
    var list = RealmSwift.List<SwiftBoolObject>()
    var map = Map<String, SwiftBoolObject?>()
    var primitiveList = RealmSwift.List<Int>()
    var primitiveMap = Map<String, Int>()
    dynamic var str = "foo"
    dynamic var int = 0

    convenience init(str: String = "foo") {
        self.init()
        self.str = str
    }
}

class EmbeddedTreeSwiftUIObject1: EmbeddedObject, EmbeddedTreeObject, ObjectKeyIdentifiable {
    @objc dynamic var value = 0
    @objc dynamic var child: EmbeddedTreeObject2?
    let children = RealmSwift.List<EmbeddedTreeObject2>()
}

private let inMemoryIdentifier = "swiftui-tests"

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
class SwiftUITests: TestCase {

    // MARK: - List Operations

    func testManagedUnmanagedListAppendPrimitive() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.primitiveList)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(1)
        XCTAssertEqual(state.wrappedValue.count, 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.append(2)
        XCTAssertEqual(state.wrappedValue.count, 2)
    }
    func testManagedUnmanagedListAppendUnmanagedObject() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.list)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(SwiftBoolObject())
        XCTAssertEqual(state.wrappedValue.count, 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.append(SwiftBoolObject())
        XCTAssertEqual(state.wrappedValue.count, 2)
    }
    func testManagedListAppendUnmanagedObservedObject() throws {
        let object = SwiftUIObject()
        var state = StateRealmObject(wrappedValue: object.list)
        XCTAssertEqual(state.wrappedValue.count, 0)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.update()
        state.projectedValue.append(SwiftBoolObject())
        XCTAssertEqual(state.wrappedValue.count, 1)
    }
    func testManagedUnmanagedListRemovePrimitive() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.primitiveList)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(1)
        XCTAssertEqual(state.wrappedValue.count, 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.append(2)
        XCTAssertEqual(state.wrappedValue.count, 2)

        state.projectedValue.remove(at: 0)
        XCTAssertEqual(state.wrappedValue[0], 2)
        XCTAssertEqual(state.wrappedValue.count, 1)
    }
    func testManagedUnmanagedListRemoveUnmanagedObject() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.list)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(SwiftBoolObject())
        XCTAssertEqual(state.wrappedValue.count, 1)
        state.projectedValue.remove(at: 0)
        XCTAssertEqual(state.wrappedValue.count, 0)
    }

    func testManagedListAppendRemoveObservedObject() throws {
        let object = SwiftUIObject()
        var state = StateRealmObject(wrappedValue: object.list)
        XCTAssertEqual(state.wrappedValue.count, 0)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.update()
        state.projectedValue.append(SwiftBoolObject())
        XCTAssertEqual(state.wrappedValue.count, 1)

        XCTAssertEqual(state.wrappedValue.count, 1)

        state.projectedValue.remove(at: 0)
        XCTAssertEqual(state.wrappedValue.count, 0)
    }

    // MARK: - Map Operations

    func testManagedUnmanagedMapAppendPrimitive() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.primitiveMap)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.set(object: 1, for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)
        XCTAssertEqual(state.projectedValue["one"], 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.set(object: 2, for: "two")
        state.projectedValue.set(object: 3, for: "two")
        XCTAssertEqual(state.wrappedValue.count, 2)
        XCTAssertEqual(state.projectedValue["two"], 3)
    }

    func testManagedUnmanagedMapAppendUnmanagedObject() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.map)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.set(object: SwiftBoolObject(), for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.set(object: SwiftBoolObject(), for: "two")
        XCTAssertEqual(state.wrappedValue.count, 2)
    }

    func testManagedMapAppendUnmanagedObservedObject() throws {
        let object = SwiftUIObject()
        var state = StateRealmObject(wrappedValue: object.map)
        XCTAssertEqual(state.wrappedValue.count, 0)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.update()
        state.projectedValue.set(object: SwiftBoolObject(), for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)
    }

    func testManagedUnmanagedMapRemovePrimitive() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.primitiveMap)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.set(object: 1, for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.projectedValue.set(object: 2, for: "two")
        XCTAssertEqual(state.wrappedValue.count, 2)

        state.projectedValue.set(object: nil, for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)
        XCTAssertEqual(state.wrappedValue.keys, ["two"])
    }

    func testManagedUnmanagedMapRemoveUnmanagedObject() throws {
        let object = SwiftUIObject()
        let state = StateRealmObject(wrappedValue: object.map)
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.set(object: SwiftBoolObject(), for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)
        state.projectedValue.set(object: nil, for: "one")
        XCTAssertEqual(state.wrappedValue.count, 0)
    }

    func testManagedMapAppendRemoveObservedObject() throws {
        let object = SwiftUIObject()
        var state = StateRealmObject(wrappedValue: object.map)
        XCTAssertEqual(state.wrappedValue.count, 0)

        let realm = inMemoryRealm(inMemoryIdentifier)
        try realm.write { realm.add(object) }

        state.update()
        state.projectedValue.set(object: SwiftBoolObject(), for: "one")
        XCTAssertEqual(state.wrappedValue.count, 1)

        XCTAssertEqual(state.wrappedValue.count, 1)

        state.projectedValue.set(object: nil, for: "one")
        XCTAssertEqual(state.wrappedValue.count, 0)
    }

    // MARK: - ObservedResults Operations
    func testResultsAppendUnmanagedObject() throws {
        let object = SwiftUIObject()
        let fullResults = ObservedResults(SwiftUIObject.self,
                                          configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        XCTAssertEqual(fullResults.wrappedValue.count, 0)
        fullResults.projectedValue.append(object)
        XCTAssertEqual(fullResults.wrappedValue.count, 1)
        let realm = inMemoryRealm(inMemoryIdentifier)
        realm.beginWrite()
        object.str = "abc"
        object.int = 1
        // add another default inited object for filter comparison
        realm.add(SwiftUIObject())
        try realm.commitWrite()
        let filteredResults = ObservedResults(SwiftUIObject.self,
                                              configuration: inMemoryRealm(inMemoryIdentifier).configuration,
                                              filter: NSPredicate(format: "str = %@", "abc"))
        XCTAssertEqual(fullResults.wrappedValue.count, 2)
        XCTAssertEqual(filteredResults.wrappedValue.count, 1)
        var sortedResults = ObservedResults(SwiftUIObject.self,
                                            configuration: inMemoryRealm(inMemoryIdentifier).configuration,
                                            filter: NSPredicate(format: "int >= 0"),
                                            sortDescriptor: SortDescriptor(keyPath: "int", ascending: true))
        XCTAssertEqual(sortedResults.wrappedValue.count, 2)
        XCTAssertEqual(sortedResults.wrappedValue[0].int, 0)
        XCTAssertEqual(sortedResults.wrappedValue[1].int, 1)
        sortedResults = ObservedResults(SwiftUIObject.self,
                                        configuration: inMemoryRealm(inMemoryIdentifier).configuration,
                                        filter: NSPredicate(format: "int >= 0"),
                                        sortDescriptor: SortDescriptor(keyPath: "int", ascending: false))
        XCTAssertEqual(sortedResults.wrappedValue.count, 2)
        XCTAssertEqual(sortedResults.wrappedValue[0].int, 1)
        XCTAssertEqual(sortedResults.wrappedValue[1].int, 0)
    }
    func testResultsAppendManagedObject() throws {
        let state = ObservedResults(SwiftUIObject.self, configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        let object = SwiftUIObject()
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(object)
        XCTAssertEqual(state.wrappedValue.count, 1)
        state.projectedValue.append(object)
        XCTAssertEqual(state.wrappedValue.count, 1)
    }
    func testResultsRemoveUnmanagedObject() throws {
        let state = ObservedResults(SwiftUIObject.self,
                                    configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        let object = SwiftUIObject()
        XCTAssertEqual(state.wrappedValue.count, 0)
        assertThrows(state.projectedValue.remove(object))
        XCTAssertEqual(state.wrappedValue.count, 0)
    }
    func testResultsRemoveManagedObject() throws {
        let state = ObservedResults(SwiftUIObject.self,
                                    configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        let object = SwiftUIObject()
        XCTAssertEqual(state.wrappedValue.count, 0)
        state.projectedValue.append(object)
        XCTAssertEqual(state.wrappedValue.count, 1)
        state.projectedValue.remove(object)
        XCTAssertEqual(state.wrappedValue.count, 0)
    }
    // MARK: Object Operations
    func testUnmanagedObjectModification() throws {
        let state = StateRealmObject(wrappedValue: SwiftUIObject())
        state.wrappedValue.str = "bar"
        XCTAssertEqual(state.wrappedValue.str, "bar")
        XCTAssertEqual(state.projectedValue.wrappedValue.str, "bar")
    }
    func testManagedObjectModification() throws {
        let state = StateRealmObject(wrappedValue: SwiftUIObject())
        ObservedResults(SwiftUIObject.self,
                        configuration: inMemoryRealm(inMemoryIdentifier).configuration)
            .projectedValue.append(state.wrappedValue)
        assertThrows(state.wrappedValue.str = "bar")
        state.projectedValue.str.wrappedValue = "bar"
        XCTAssertEqual(state.projectedValue.wrappedValue.str, "bar")
    }
    func testManagedObjectDelete() throws {
        let results = ObservedResults(SwiftUIObject.self,
                                      configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        let state = StateRealmObject(wrappedValue: SwiftUIObject())
        XCTAssertEqual(results.wrappedValue.count, 0)
        state.projectedValue.delete()
        XCTAssertEqual(results.wrappedValue.count, 0)
        results.projectedValue.append(state.wrappedValue)
        XCTAssertEqual(results.wrappedValue.count, 1)
        state.projectedValue.delete()
    }
    // MARK: - ObservedResults Search
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testSearchObservedResults() {
        let fullResults = ObservedResults(SwiftUIObject.self,
                                          configuration: inMemoryRealm(inMemoryIdentifier).configuration)
        XCTAssertEqual(fullResults.wrappedValue.count, 0)
        (1...20).forEach { index in
            let object = SwiftUIObject()
            object.str = "str_\(index)"
            fullResults.projectedValue.append(object)
        }
        XCTAssertEqual(fullResults.wrappedValue.count, 20)

        let searchBinding = fullResults.searchByKeypathString(["str"])

        searchBinding.wrappedValue = "str"
        XCTAssertEqual(fullResults.wrappedValue.count, 20)

        searchBinding.wrappedValue = "str_5"
        XCTAssertEqual(fullResults.wrappedValue.count, 1)

        searchBinding.wrappedValue = "str_1"
        XCTAssertEqual(fullResults.wrappedValue.count, 11)

        searchBinding.wrappedValue = ""
        XCTAssertEqual(fullResults.wrappedValue.count, 20)
    }
    // MARK: Bind
    func testUnmanagedManagedObjectBind() {
        let object = SwiftUIObject()
        let binding = object.bind(\.str)
        XCTAssertEqual(object.str, "foo")
        XCTAssertEqual(binding.wrappedValue, "foo")
        binding.wrappedValue = "bar"
        XCTAssertEqual(binding.wrappedValue, "bar")

        let realm = inMemoryRealm(inMemoryIdentifier)
        try? realm.write { realm.add(object) }

        let managedBinding = object.bind(\.str)
        XCTAssertEqual(object.str, "bar")
        XCTAssertEqual(binding.wrappedValue, "bar")
        managedBinding.wrappedValue = "baz"
        XCTAssertEqual(object.str, "baz")
        XCTAssertEqual(binding.wrappedValue, "baz")
    }
}
#endif
