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
    func testAsyncOpenOpenRealm() {
        do {
            _ = try logInUser(for: basicCredentials())
            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
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

    func testAsyncOpenDownloadRealm() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            executeChild()

            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-async-open")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
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

    func testAsyncOpenNotOpenRealmWithoutUserLogged() {
        do {
            let user = try logInUser(for: basicCredentials())
            user.logOut { _ in } //Logout current user

            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-async-open-not-logged")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
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

    // In case of no internet connection AsyncOpen should return an error if there is a timeout
    func testAsyncOpenFailWithoutInternetConnection() {
        let proxy = TimeoutProxyServer(port: 5678, targetPort: 9090)
        try! proxy.start()

        let appId = try! RealmServer.shared.createApp()
        let appConfig = AppConfiguration(baseURL: "http://localhost:5678",
                                         transport: AsyncOpenConnectionTimeoutTransport(),
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = App(id: appId, configuration: appConfig)
        do {
            _ = try logInUser(for: basicCredentials(app: app), app: app)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            return
        }

        autoreleasepool {
            proxy.delay = 3.0
            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function, timeout: 2000)
            let ex = expectation(description: "download-realm-auto-open-fail")
            _ = XCTWaiter.wait(for: [ex], timeout: 5.0)
            if case let .error(error) = asyncOpen.wrappedValue {
                if let error = error as NSError? {
                    XCTAssertEqual(error.code, Int(ETIMEDOUT))
                    XCTAssertEqual(error.domain, NSPOSIXErrorDomain)
                    ex.fulfill()
                } else {
                    XCTFail("Not expected error")
                }
            } else {
                XCTFail("Could not open Realm or failed")
            }
            asyncOpen.cancel()
        }

        proxy.stop()
    }

    // MARK: - AutoOpen
    func testAutoOpenOpenReal() {
        do {
            _ = try logInUser(for: basicCredentials())

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-auto-open")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
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

    func testAutoOpenDownloadRealm() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            executeChild()

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-populated-realm-auto-open")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
            if case let .open(realm) = autoOpen.wrappedValue {
                XCTAssertNotNil(realm)
                self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
                XCTAssertTrue(autoOpen.wai)
            } else {
                XCTFail("Could not open Realm or failed")
            }
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAutoOpenNotOpenRealmWithoutUserLogged() {
        do {
            let user = try logInUser(for: basicCredentials())
            user.logOut { _ in } //Logout current user

            let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
            let ex = expectation(description: "download-realm-auto-open-not-logged")
            _ = XCTWaiter.wait(for: [ex], timeout: 5)
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

    // In case of no internet connection AutoOpen should return an opened Realm, offline-first approach
    func testAutoOpenOpenRealmWithoutInternetConnection() {
        let proxy = TimeoutProxyServer(port: 5678, targetPort: 9090)
        try! proxy.start()

        let appId = try! RealmServer.shared.createApp()
        let appConfig = AppConfiguration(baseURL: "http://localhost:5678",
                                         transport: AsyncOpenConnectionTimeoutTransport(),
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = App(id: appId, configuration: appConfig)

        do {
            _ = try logInUser(for: basicCredentials(app: app), app: app)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            return
        }

        autoreleasepool {
            proxy.delay = 3.0
            let autoOpen = AutoOpen(appId: appId, partitionValue: #function, timeout: 2000)
            let ex = expectation(description: "download-realm-auto-open-fail")
            _ = XCTWaiter.wait(for: [ex], timeout: 5.0)
            if case let .open(realm) = autoOpen.wrappedValue {
                XCTAssertNotNil(realm)
            } else {
                XCTFail("Could not open Realm or failed")
            }
            autoOpen.cancel()
        }

        proxy.stop()
    }
}
