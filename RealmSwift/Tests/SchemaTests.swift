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

class SchemaTests: TestCase {
    var schema: Schema!

    override func setUp() {
        super.setUp()
        schema = Realm().schema
    }
    
    func testObjectSchema() {
        let objectSchema = schema.objectSchema
        XCTAssertTrue(objectSchema.count > 0)
    }

    func testDescription() {
        XCTAssert(schema.description as Any is String)
    }

    func testSubscript() {
        XCTAssertEqual(schema["AllTypesObject"]!.className, "AllTypesObject")
        XCTAssertNil(schema["NoSuchClass"])
    }

    func testEquals() {
        XCTAssertTrue(schema == Realm().schema)
    }
}
