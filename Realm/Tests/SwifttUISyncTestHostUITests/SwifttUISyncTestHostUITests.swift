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
    // MARK: - AsyncOpen
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

        // Test that the user is already logged
        let loggingView = app.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = app.buttons["sync-button-view"]
        syncButtonView.tap()

        // Test progress is greater than 0
        let progressView = app.staticTexts["progress-text-view"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 2))
        let progressValue = progressView.value as! String
        XCTAssertTrue(Int64(progressValue)! > 0)

        // Query for button to navigate to next view
        let nextViewView = app.buttons["show-list-button-view"]
        nextViewView.tap()

        // Test show ListView after syncing realm
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, self.bigObjectCount)
    }

    // MARK: - AutoOpen
    func testDownloadRealmAutocOpenApp() throws {
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

        // Test that the user is already logged
        let loggingView = app.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = app.buttons["sync-button-view"]
        syncButtonView.tap()

        // Test progress is greater than 0
        let progressView = app.staticTexts["progress-text-view"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 2))
        let progressValue = progressView.value as! String
        XCTAssertTrue(Int64(progressValue)! > 0)

        // Query for button to navigate to next view
        let nextViewView = app.buttons["show-list-button-view"]
        nextViewView.tap()

        // Test show ListView after syncing realm
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, self.bigObjectCount)
    }
}
