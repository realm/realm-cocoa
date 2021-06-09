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

import Foundation
import RealmSwift
import XCTest

@objcMembers class Dog: Object {
    dynamic var name = ""
    dynamic var age = 5
}

@objcMembers class SimpleObject: Object {
    dynamic var stringCol = "foo"
    dynamic var doubleCol = 42.42
    let dogs = List<Dog>()
}

class QueryTests: TestCase {
    func testSimpleQuery() throws {
        let realm = try! Realm()
        try realm.write {
            let s1 = SimpleObject()
            realm.add(s1)
            let s2 = SimpleObject()
            s2.stringCol = "🤓👍"
            s2.dogs.append(Dog())
            realm.add(s2)
        }

        let results1 = realm.objects(SimpleObject.self).query {
            $0.doubleCol == 42.42
        }
        let results2 = realm.objects(SimpleObject.self).query {
            $0.doubleCol == 42.42 &&
                $0.stringCol.contains("👍")
        }
        let results3 = realm.objects(SimpleObject.self).query {
           $0.dogs.age == 5
        }
        let results4 = realm.objects(SimpleObject.self).query {
            $0.doubleCol == 42.42 &&
                $0.stringCol.contains("👍") &&
                $0.dogs.age == 5
         }
        XCTAssertEqual(results1.count, 2)
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results3.count, 1)
        XCTAssertEqual(results4.count, 1)
    }
}
