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
import Combine

#if canImport(RealmTestSupport)
import RealmSwiftSyncTestSupport
import RealmSyncTestSupport
#endif

@available(OSX 11, *)
class SwiftUIServerTests: SwiftSyncTestCase {
    override func setUp() {
        let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
        Realm.Configuration.defaultConfiguration = config
    }

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = []
        super.tearDown()
    }

    var cancellables: Set<AnyCancellable> = []

    // MARK: - AsyncOpen
    func testAsyncOpenOpenRealm() throws {
        _ = try logInUser(for: basicCredentials())

        let ex = expectation(description: "download-realm-async-open")
        let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
        asyncOpen.projectedValue
            .sink { asyncOpenState in
                if case let .open(realm) = asyncOpenState {
                    XCTAssertNotNil(realm)
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        asyncOpen.cancel()
    }

    func testAsyncOpenDownloadRealm() throws {
        let user = try logInUser(for: basicCredentials())
        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "download-populated-realm-async-open")
        asyncOpen.projectedValue
            .sink { asyncOpenState in
                if case let .open(realm) = asyncOpenState {
                    XCTAssertNotNil(realm)
                    self.checkCount(expected: SwiftSyncTestCase.bigObjectCount, realm, SwiftHugeSyncObject.self)
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        asyncOpen.cancel()
    }

    func testAsyncOpenNotOpenRealmWithoutUserLoggedIn() throws {
        let user = try logInUser(for: basicCredentials())
        user.logOut { _ in } //Logout current user

        let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "download-realm-async-open-not-logged")
        asyncOpen.projectedValue
            .sink { asyncOpenState in
                if case .notOpen = asyncOpenState {
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        asyncOpen.cancel()
    }

    // In case of no internet connection AsyncOpen should return an error if there is a timeout
    func testAsyncOpenFailWithoutInternetConnection() throws {
        let proxy = TimeoutProxyServer(port: 5678, targetPort: 9090)
        try! proxy.start()

        let appId = try! RealmServer.shared.createApp()
        let appConfig = AppConfiguration(baseURL: "http://localhost:5678",
                                         transport: AsyncOpenConnectionTimeoutTransport(),
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = App(id: appId, configuration: appConfig)
        _ = try logInUser(for: basicCredentials(app: app), app: app)

        autoreleasepool {
            proxy.delay = 3.0
            let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function, timeout: 2000)
            let ex = expectation(description: "download-realm-async-open-no-connection")
            asyncOpen.projectedValue
                .sink { asyncOpenState in
                    if case let .error(error) = asyncOpenState,
                       let nsError = error as NSError? {
                        XCTAssertEqual(nsError.code, Int(ETIMEDOUT))
                        XCTAssertEqual(nsError.domain, NSPOSIXErrorDomain)
                        ex.fulfill()
                    }
                }
                .store(in: &cancellables)
            waitForExpectations(timeout: 10.0)
            asyncOpen.cancel()
        }
        proxy.stop()
    }

    func testAsyncOpenProgressNotification() throws {
        let user = try logInUser(for: basicCredentials())
        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let asyncOpen = AsyncOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "progress-async-open")
        asyncOpen.projectedValue
            .sink { asyncOpenState in
                if case let .progress(progress) = asyncOpenState {
                    XCTAssertTrue(progress.fractionCompleted > 0)
                    if progress.isFinished {
                        ex.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        asyncOpen.cancel()
    }

    // MARK: - AutoOpen
    func testAutoOpenOpenRealm() throws {
        _ = try logInUser(for: basicCredentials())

        let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "download-realm-auto-open")
        autoOpen.projectedValue
            .sink { autoOpenState in
                if case let .open(realm) = autoOpenState {
                    XCTAssertNotNil(realm)
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        autoOpen.cancel()
    }

    func testAutoOpenDownloadRealm() throws {
        let user = try logInUser(for: basicCredentials())

        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "download-populated-realm-auto-open")
        autoOpen.projectedValue
            .sink { autoOpenState in
                if case let .open(realm) = autoOpenState {
                    XCTAssertNotNil(realm)
                    self.checkCount(expected: SwiftSyncTestCase.bigObjectCount, realm, SwiftHugeSyncObject.self)
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        autoOpen.cancel()
    }

    func testAutoOpenNotOpenRealmWithoutUserLoggedIn() throws {
        let user = try logInUser(for: basicCredentials())
        user.logOut { _ in } //Logout current user

        let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "download-realm-auto-open-not-logged")
        autoOpen.projectedValue
            .sink { autoOpenState in
                if case .notOpen = autoOpenState {
                    ex.fulfill()
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        autoOpen.cancel()
    }

    // In case of no internet connection AutoOpen should return an opened Realm, offline-first approach
    func testAutoOpenOpenRealmWithoutInternetConnection() throws {
        let proxy = TimeoutProxyServer(port: 5678, targetPort: 9090)
        try! proxy.start()

        let appId = try! RealmServer.shared.createApp()
        let appConfig = AppConfiguration(baseURL: "http://localhost:5678",
                                         transport: AsyncOpenConnectionTimeoutTransport(),
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = App(id: appId, configuration: appConfig)
        _ = try logInUser(for: basicCredentials(app: app), app: app)

        autoreleasepool {
            proxy.delay = 3.0
            let autoOpen = AutoOpen(appId: appId, partitionValue: #function, timeout: 2000)
            let ex = expectation(description: "download-realm-auto-open-no-connection")
            autoOpen.projectedValue
                .sink { autoOpenState in
                    if case let .open(realm) = autoOpenState {
                        XCTAssertNotNil(realm)
                        ex.fulfill()
                    }
                }
                .store(in: &cancellables)
            waitForExpectations(timeout: 10.0)
            autoOpen.cancel()
        }

        proxy.stop()
    }

    func testAutoOpenProgressNotification() throws {
        let user = try logInUser(for: basicCredentials())
        if !isParent {
            populateRealm(user: user, partitionValue: #function)
            return
        }

        executeChild()

        let autoOpen = AutoOpen(appId: appId, partitionValue: #function)
        let ex = expectation(description: "progress-auto-open")
        autoOpen.projectedValue
            .sink { autoOpenState in
                if case let .progress(progress) = autoOpenState {
                    XCTAssertTrue(progress.fractionCompleted > 0)
                    if progress.isFinished {
                        ex.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 10.0)
        autoOpen.cancel()
    }
}
