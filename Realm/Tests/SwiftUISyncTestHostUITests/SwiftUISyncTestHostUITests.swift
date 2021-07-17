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

class SwiftUISyncTestHostUITests: SwiftSyncTestCase {
    let application = XCUIApplication()
    static var isDataCreated = false
    override func setUp() {
        continueAfterFailure = false
        super.setUp()
        if !SwiftUISyncTestHostUITests.isDataCreated {
            let user = logInUser(for: basicCredentials(withName: #function, register: true))
            populateRealm(user: user, partitionValue: #function)
            SwiftUISyncTestHostUITests.isDataCreated = true
        }

        application.launchEnvironment["function_name"] = #function
        application.launchEnvironment["app_id"] = appId
    }

    override func tearDown() {
        application.terminate()
        deleteApplicationData()
        super.tearDown()
    }

    func deleteApplicationData() {
        do {
            let fileManager = FileManager.default
            let applicationSupportDir = try fileManager.url(for: .applicationSupportDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: nil,
                                                               create: false)
            let applicationsUrls = try fileManager.contentsOfDirectory(at: applicationSupportDir,
                                                                       includingPropertiesForKeys: nil)
            for applicationUrl in applicationsUrls {
                if applicationUrl.lastPathComponent == "io.realm.TestHost" {
                    try fileManager.removeItem(at: applicationUrl)
                }
            }
        } catch {
            XCTFail("Error reseting application data")
        }
    }

    // MARK: - AsyncOpen
    func testDownloadRealmAsyncOpenApp() throws {
        application.launchEnvironment["test_type"] = "async_open"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        syncButtonView.tap()

        // Test progress is greater than 0
        let progressView = application.staticTexts["progress-text-view"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 2))
        let progressValue = progressView.value as! String
        XCTAssertTrue(Int64(progressValue)! > 0)

        // Query for button to navigate to next view
        let nextViewView = application.buttons["show-list-button-view"]
        nextViewView.tap()

        // Test show ListView after syncing realm environment
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }

    func testDownloadRealmAsyncOpenAppWithEnvironmentPartitionValue() throws {
        application.launchEnvironment["test_type"] = "async_open_environment_partition_value"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        syncButtonView.tap()

        // Test show ListView after syncing realm
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }

    func testDownloadRealmAsyncOpenAppWithEnvironmentConfiguration() throws {
        application.launchEnvironment["test_type"] = "async_open_environment_configuration"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        syncButtonView.tap()

        // Test show ListView after syncing realm
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }

    // MARK: - AutoOpen
    func testDownloadRealmAutoOpenApp() throws {
        application.launchEnvironment["test_type"] = "auto_open"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        print(syncButtonView)
        syncButtonView.tap()

        // Test progress is greater than 0
        let progressView = application.staticTexts["progress-text-view"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 2))
        let progressValue = progressView.value as! String
        XCTAssertTrue(Int64(progressValue)! > 0)

        // Query for button to navigate to next view
        let nextViewView = application.buttons["show-list-button-view"]
        nextViewView.tap()

        // Test show ListView after syncing realm
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }

    func testDownloadRealmAutoOpenAppWithEnvironmentPartitionValue() throws {
        application.launchEnvironment["test_type"] = "auto_open_environment_partition_value"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        syncButtonView.tap()

        // Test show ListView after syncing realm
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }

    func testDownloadRealmAutoOpenAppWithEnvironmentConfiguration() throws {
        application.launchEnvironment["test_type"] = "auto_open_environment_configuration"
        application.launch()

        // Test that the user is already logged in
        let loggingView = application.staticTexts["logged-view"]
        XCTAssertTrue(loggingView.waitForExistence(timeout: 2))

        // Query for button to start syncing
        let syncButtonView = application.buttons["sync-button-view"]
        XCTAssertTrue(syncButtonView.waitForExistence(timeout: 2))
        syncButtonView.tap()

        // Test show ListView after syncing realm
        let table = application.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6))
        XCTAssertEqual(table.cells.count, SwiftSyncTestCase.bigObjectCount)
    }
}
