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

class ObjectSchemaTests: TestCase {
    var objectSchema: ObjectSchema!

    override func setUp() {
        super.setUp()
        objectSchema = Realm().schema["AllTypesObject"]
    }

    func testProperties() {
        let propertyNames = objectSchema.properties.map { $0.name }
        XCTAssertEqual(propertyNames, ["boolCol", "intCol", "floatCol", "doubleCol", "stringCol", "binaryCol", "dateCol", "objectCol", "arrayCol"])
    }

    // Cannot name testClassName() because it interferes with the method on XCTest
    func testClassNameProperty() {
        XCTAssertEqual(objectSchema.className, "AllTypesObject")
    }

    func testPrimaryKeyProperty() {
        XCTAssertNil(objectSchema.primaryKeyProperty)
        XCTAssertEqual(Realm().schema["PrimaryStringObject"]!.primaryKeyProperty!.name, "stringCol")
    }

    func testDescription() {
        XCTAssertEqual(objectSchema.description, "AllTypesObject {\n\tboolCol {\n\t\ttype = bool;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tintCol {\n\t\ttype = int;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tfloatCol {\n\t\ttype = float;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tdoubleCol {\n\t\ttype = double;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tstringCol {\n\t\ttype = string;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tbinaryCol {\n\t\ttype = data;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tdateCol {\n\t\ttype = date;\n\t\tobjectClassName = (null);\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tobjectCol {\n\t\ttype = object;\n\t\tobjectClassName = BoolObject;\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n\tarrayCol {\n\t\ttype = array;\n\t\tobjectClassName = BoolObject;\n\t\tindexed = NO;\n\t\tisPrimary = NO;\n\t}\n}")
    }

    func testSubscript() {
        XCTAssertNil(objectSchema["noSuchProperty"])
        XCTAssertEqual(objectSchema["boolCol"]!.name, "boolCol")
    }

    func testEquals() {
        XCTAssert(objectSchema == Realm().schema["AllTypesObject"]!)
        XCTAssert(objectSchema != Realm().schema["StringObject"]!)
    }
}
