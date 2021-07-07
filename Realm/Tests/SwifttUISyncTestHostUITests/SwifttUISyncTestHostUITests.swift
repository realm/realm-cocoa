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
import RealmSwift

class SwifttUISyncTestHostUITests: SwiftSyncTestCase {
    func testDownloadRealmAsyncOpenApp() throws {
        let user = logInUser(for: basicCredentials(withName: #function, register: isParent))
        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let app = XCUIApplication()
        app.launchEnvironment["test_type"] = "async_open"
        app.launchEnvironment["app_id"] = appId
        app.launchEnvironment["function_name"] = #function
        app.launch()

        // Test Show table view after syncing realm
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertEqual(table.cells.count, self.bigObjectCount)
    }

    func testDownloadRealmAutoOpenApp() throws {
        let user = logInUser(for: basicCredentials(withName: #function, register: isParent))
        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let app = XCUIApplication()
        app.launchEnvironment["test_type"] = "auto_open"
        app.launchEnvironment["app_id"] = appId
        app.launchEnvironment["function_name"] = #function
        app.launch()

        // Test Show table view after syncing realm
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertEqual(table.cells.count, self.bigObjectCount)
    }
}
