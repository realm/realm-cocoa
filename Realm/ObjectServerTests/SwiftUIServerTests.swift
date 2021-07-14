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
@objc(SwiftUIServerTests)
class SwiftUIServerTests: SwiftSyncTestCase {
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = []
        super.tearDown()
    }

    var cancellables: Set<AnyCancellable> = []

    // MARK: - AsyncOpen
    func testAsyncOpenOpenRealm() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAsyncOpenDownloadRealm() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
                        self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
                        ex.fulfill()
                    }
                }
                .store(in: &cancellables)
            waitForExpectations(timeout: 10.0)
            asyncOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAsyncOpenNotOpenRealmWithoutUserLogged() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // In case of no internet connection AsyncOpen should return an error if there is a timeout
    func testAsyncOpenFailWithoutInternetConnection() {
        let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
        Realm.Configuration.defaultConfiguration = config

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

    func testAsyncOpenProgressNotification() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - AutoOpen
    func testAutoOpenOpenReal() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAutoOpenDownloadRealm() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
                        self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
                        ex.fulfill()
                    }
                }
                .store(in: &cancellables)
            waitForExpectations(timeout: 10.0)
            autoOpen.cancel()
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAutoOpenNotOpenRealmWithoutUserLogged() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // In case of no internet connection AutoOpen should return an opened Realm, offline-first approach
    func testAutoOpenOpenRealmWithoutInternetConnection() {
        let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
        Realm.Configuration.defaultConfiguration = config

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

    func testAutoOpenProgressNotification() {
        do {
            let config = Realm.Configuration(objectTypes: [SwiftHugeSyncObject.self])
            Realm.Configuration.defaultConfiguration = config

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
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }
}
