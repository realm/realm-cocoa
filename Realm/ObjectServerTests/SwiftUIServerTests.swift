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

import RealmSwift
import XCTest
import SwiftUI

#if canImport(RealmTestSupport)
import RealmSwiftSyncTestSupport
import RealmSyncTestSupport
#endif

@available(OSX 11, *)
@objc(SwiftUIServerTests)
class SwiftUIServerTests: SwiftSyncTestCase {
    // MARK: - AsyncOpen
    func testOpenRealmWithAsyncOpen() {
        do {
            let _ = try logInUser(for: basicCredentials())
            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .open(realm) = asyncOpen.wrappedValue {
                XCTAssertNotNil(realm)
                ex.fulfill()
            } else {
                XCTFail("Could not open Realm")
            }
            asyncOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmWithAsyncOpen() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            executeChild()

            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .open(realm) = asyncOpen.wrappedValue {
                XCTAssertNotNil(realm)
                self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
            } else {
                XCTFail("Could not open Realm or failed")
            }
            asyncOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmFailWithAsyncOpen() {
        do {
            _ = try logInUser(for: basicCredentials())
            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .error(error) = asyncOpen.wrappedValue {
                XCTAssertNotNil(error)
                ex.fulfill()
            } else {
                XCTFail("Not Expected State")
            }
            asyncOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmWithoutUserLoggedWithAsyncOpen() {
        do {
            let user = try logInUser(for: basicCredentials())
            user.logOut { _ in } //Logout current user

            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case .notOpen = asyncOpen.wrappedValue {
                ex.fulfill()
            } else {
                XCTFail("Not Expected State")
            }
            asyncOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    //MARK: - AutoOpen
    func testOpenRealmWithAutoOpen() {
        do {
            _ = try logInUser(for: basicCredentials())

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .open(realm) = autoOpen.wrappedValue {
                XCTAssertNotNil(realm)
                ex.fulfill()
            } else {
                XCTFail("Could not open Realm")
            }
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmWithAutoOpen() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            executeChild()

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .open(realm) = autoOpen.wrappedValue {
                XCTAssertNotNil(realm)
                self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
            } else {
                XCTFail("Could not open Realm or failed")
            }
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmFailWithAutoOpen() {
        do {
            _ = try logInUser(for: basicCredentials())

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .error(error) = autoOpen.wrappedValue {
                XCTAssertNotNil(error)
                ex.fulfill()
            } else {
                XCTFail("Not Expected State")
            }
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmWithoutUserLoggedWithAutoOpen() {
        do {
            let user = try logInUser(for: basicCredentials())
            user.logOut { _ in } //Logout current user

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-async-open")
            let _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case .notOpen = autoOpen.wrappedValue {
                ex.fulfill()
            } else {
                XCTFail("Not Expected State")
            }
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }
}
