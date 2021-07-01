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
        do {
            let _ = try logInUser(for: basicCredentials())
            let app = XCUIApplication()
            app.launchEnvironment["test_type"] = "multi_realm_test"
            app.launchEnvironment["app_id"] = appId
            app.launch()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }
}
