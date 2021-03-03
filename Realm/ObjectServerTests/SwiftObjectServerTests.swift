////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#if os(macOS)

import Combine
import Realm
import RealmSwift
import XCTest

#if canImport(RealmTestSupport)
import RealmSwiftSyncTestSupport
import RealmSyncTestSupport
import RealmTestSupport
#endif

extension User {
    func configuration(testName: String) -> Realm.Configuration {
        var config = self.configuration(partitionValue: testName)
        config.objectTypes = [SwiftPerson.self, SwiftHugeSyncObject.self]
        return config
    }
}

@available(OSX 10.14, *)
@objc(SwiftObjectServerTests)
class SwiftObjectServerTests: SwiftSyncTestCase {
    /// It should be possible to successfully open a Realm configured for sync.
    func testBasicSwiftSync() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: #function, user: user)
            XCTAssert(realm.isEmpty, "Freshly synced Realm was not empty...")
        } catch {
            XCTFail("Got an error: \(error)")
        }
    }

    func testBasicSwiftSyncWithNilPartitionValue() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: .null, user: user)
            XCTAssert(realm.isEmpty, "Freshly synced Realm was not empty...")
        } catch {
            XCTFail("Got an error: \(error)")
        }
    }

    /// If client B adds objects to a Realm, client A should see those new objects.
    func testSwiftAddObjects() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: #function, user: user)
            if isParent {
                checkCount(expected: 0, realm, SwiftPerson.self)
                executeChild()
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            } else {
                // Add objects
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testSwiftAddObjectsWithNilPartitionValue() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: .null, user: user)
            if isParent {
                checkCount(expected: 0, realm, SwiftPerson.self)
                executeChild()
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
                try realm.write {
                    realm.deleteAll()
                }
                waitForUploads(for: realm)
            } else {
                // Add objects
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    /// If client B removes objects from a Realm, client A should see those changes.
    func testSwiftDeleteObjects() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: #function, user: user)
            if isParent {
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
                executeChild()
            } else {
                checkCount(expected: 3, realm, SwiftPerson.self)
                try realm.write {
                    realm.deleteAll()
                }
                waitForUploads(for: realm)
                checkCount(expected: 0, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    /// A client should be able to open multiple Realms and add objects to each of them.
    func testMultipleRealmsAddObjects() {
        let partitionValueA = #function
        let partitionValueB = "\(#function)bar"
        let partitionValueC = "\(#function)baz"

        do {
            let user = try logInUser(for: basicCredentials())

            let realmA = try openRealm(partitionValue: partitionValueA, user: user)
            let realmB = try openRealm(partitionValue: partitionValueB, user: user)
            let realmC = try openRealm(partitionValue: partitionValueC, user: user)

            if self.isParent {
                checkCount(expected: 0, realmA, SwiftPerson.self)
                checkCount(expected: 0, realmB, SwiftPerson.self)
                checkCount(expected: 0, realmC, SwiftPerson.self)
                executeChild()

                waitForDownloads(for: realmA)
                waitForDownloads(for: realmB)
                waitForDownloads(for: realmC)

                checkCount(expected: 3, realmA, SwiftPerson.self)
                checkCount(expected: 2, realmB, SwiftPerson.self)
                checkCount(expected: 5, realmC, SwiftPerson.self)

                XCTAssertEqual(realmA.objects(SwiftPerson.self).filter("firstName == %@", "Ringo").count,
                               1)
                XCTAssertEqual(realmB.objects(SwiftPerson.self).filter("firstName == %@", "Ringo").count,
                               0)
            } else {
                // Add objects.
                try realmA.write {
                    realmA.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realmA.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmA.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                try realmB.write {
                    realmB.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmB.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                try realmC.write {
                    realmC.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realmC.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmC.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                    realmC.add(SwiftPerson(firstName: "George", lastName: "Harrison"))
                    realmC.add(SwiftPerson(firstName: "Pete", lastName: "Best"))
                }

                waitForUploads(for: realmA)
                waitForUploads(for: realmB)
                waitForUploads(for: realmC)

                checkCount(expected: 3, realmA, SwiftPerson.self)
                checkCount(expected: 2, realmB, SwiftPerson.self)
                checkCount(expected: 5, realmC, SwiftPerson.self)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testConnectionState() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try immediatelyOpenRealm(partitionValue: #function, user: user)
            let session = realm.syncSession!

            func wait(forState desiredState: SyncSession.ConnectionState) {
                let ex = expectation(description: "Wait for connection state: \(desiredState)")
                let token = session.observe(\SyncSession.connectionState, options: .initial) { s, _ in
                    if s.connectionState == desiredState {
                        ex.fulfill()
                    }
                }
                waitForExpectations(timeout: 5.0)
                token.invalidate()
            }

            wait(forState: .connected)

            session.suspend()
            wait(forState: .disconnected)

            session.resume()
            wait(forState: .connecting)
            wait(forState: .connected)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - Client reset

    func testClientReset() {
        do {
            let user = try logInUser(for: basicCredentials())
            let realm = try openRealm(partitionValue: #function, user: user)

            var theError: SyncError?
            let ex = expectation(description: "Waiting for error handler to be called...")
            app.syncManager.errorHandler = { (error, _) in
                if let error = error as? SyncError {
                    theError = error
                } else {
                    XCTFail("Error \(error) was not a sync error. Something is wrong.")
                }
                ex.fulfill()
            }
            user.simulateClientResetError(forSession: #function)
            waitForExpectations(timeout: 10, handler: nil)
            XCTAssertNotNil(theError)
            guard let error = theError else { return }
            XCTAssertTrue(error.code == SyncError.Code.clientResetError)
            guard let resetInfo = error.clientResetInfo() else {
                XCTAssertNotNil(error.clientResetInfo())
                return
            }
            XCTAssertTrue(resetInfo.0.contains("mongodb-realm/\(self.appId)/recovered-realms/recovered_realm"))
            XCTAssertNotNil(realm)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testClientResetManualInitiation() {
        do {
            let user = try logInUser(for: basicCredentials())
            var theError: SyncError?

            try autoreleasepool {
                let realm = try openRealm(partitionValue: #function, user: user)
                let ex = expectation(description: "Waiting for error handler to be called...")
                app.syncManager.errorHandler = { (error, _) in
                    if let error = error as? SyncError {
                        theError = error
                    } else {
                        XCTFail("Error \(error) was not a sync error. Something is wrong.")
                    }
                    ex.fulfill()
                }
                user.simulateClientResetError(forSession: #function)
                waitForExpectations(timeout: 10, handler: nil)
                XCTAssertNotNil(theError)
                XCTAssertNotNil(realm)
            }
            guard let error = theError else { return }
            let (path, errorToken) = error.clientResetInfo()!
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
            SyncSession.immediatelyHandleError(errorToken, syncManager: self.app.syncManager)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - Progress notifiers

    let bigObjectCount = 2

    func populateRealm(user: User, partitionValue: String) {
        do {
            assert(user.isLoggedIn)
            let config = user.configuration(testName: partitionValue)
            let realm = try openRealm(configuration: config)
            try! realm.write {
                for _ in 0..<bigObjectCount {
                    realm.add(SwiftHugeSyncObject.create())
                }
            }
            waitForUploads(for: realm)
            checkCount(expected: bigObjectCount, realm, SwiftHugeSyncObject.self)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testStreamingDownloadNotifier() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            var callCount = 0
            var transferred = 0
            var transferrable = 0
            let realm = try immediatelyOpenRealm(partitionValue: #function, user: user)

            guard let session = realm.syncSession else {
                XCTFail("Session must not be nil")
                return

            }
            let ex = expectation(description: "streaming-downloads-expectation")
            var hasBeenFulfilled = false

            let token = session.addProgressNotification(for: .download, mode: .reportIndefinitely) { p in
                callCount += 1
                XCTAssertGreaterThanOrEqual(p.transferredBytes, transferred)
                XCTAssertGreaterThanOrEqual(p.transferrableBytes, transferrable)
                transferred = p.transferredBytes
                transferrable = p.transferrableBytes
                if p.transferredBytes > 0 && p.isTransferComplete && !hasBeenFulfilled {
                    ex.fulfill()
                    hasBeenFulfilled = true
                }
            }
            XCTAssertNotNil(token)

            // Wait for the child process to upload all the data.
            executeChild()

            waitForExpectations(timeout: 60.0, handler: nil)
            token!.invalidate()
            XCTAssert(callCount > 1)
            XCTAssert(transferred >= transferrable)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testStreamingUploadNotifier() {
        do {
            var transferred = 0
            var transferrable = 0
            let user = try logInUser(for: basicCredentials())
            let config = user.configuration(testName: #function)
            let realm = try openRealm(configuration: config)
            let session = realm.syncSession
            XCTAssertNotNil(session)
            var ex = expectation(description: "initial upload")
            let token = session!.addProgressNotification(for: .upload, mode: .reportIndefinitely) { p in
                XCTAssert(p.transferredBytes >= transferred)
                XCTAssert(p.transferrableBytes >= transferrable)
                transferred = p.transferredBytes
                transferrable = p.transferrableBytes
                if p.transferredBytes > 0 && p.isTransferComplete {
                    ex.fulfill()
                }
            }
            waitForExpectations(timeout: 10.0, handler: nil)
            ex = expectation(description: "write transaction upload")
            try realm.write {
                for _ in 0..<bigObjectCount {
                    realm.add(SwiftHugeSyncObject.create())
                }
            }
            waitForExpectations(timeout: 10.0, handler: nil)
            token!.invalidate()
            XCTAssert(transferred >= transferrable)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - Download Realm

    func testDownloadRealm() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let config = user.configuration(testName: #function)
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { result in
                switch result {
                case .success(let realm):
                    self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
                case .failure(let error):
                    XCTFail("No realm on async open: \(error)")
                }
                ex.fulfill()
            }
            func fileSize(path: String) -> Int {
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    return attr[.size] as! Int
                }
                return 0
            }
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
            waitForExpectations(timeout: 10.0, handler: nil)
            XCTAssertGreaterThan(fileSize(path: pathOnDisk), 0)
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmToCustomPath() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let customFileURL = realmURLForFile("copy")
            var config = user.configuration(testName: #function)
            config.fileURL = customFileURL
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertEqual(pathOnDisk, customFileURL.path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { result in
                switch result {
                case .success(let realm):
                    self.checkCount(expected: self.bigObjectCount, realm, SwiftHugeSyncObject.self)
                case .failure(let error):
                    XCTFail("No realm on async open: \(error)")
                }
                ex.fulfill()
            }
            func fileSize(path: String) -> Int {
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    return attr[.size] as! Int
                }
                return 0
            }
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
            waitForExpectations(timeout: 10.0, handler: nil)
            XCTAssertGreaterThan(fileSize(path: pathOnDisk), 0)
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testCancelDownloadRealm() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            // Use a serial queue for asyncOpen to ensure that the first one adds
            // the completion block before the second one cancels it
            RLMSetAsyncOpenQueue(DispatchQueue(label: "io.realm.asyncOpen"))

            let ex = expectation(description: "async open")
            let config = user.configuration(testName: #function)
            Realm.asyncOpen(configuration: config) { result in
                guard case .failure = result else {
                    XCTFail("No error on cancelled async open")
                    return ex.fulfill()
                }
                ex.fulfill()
            }
            let task = Realm.asyncOpen(configuration: config) { _ in
                XCTFail("Cancelled completion handler was called")
            }
            task.cancel()
            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAsyncOpenProgress() {
        do {
            let user = try logInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: #function)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()
            let ex1 = expectation(description: "async open")
            let ex2 = expectation(description: "download progress")
            let config = user.configuration(testName: #function)
            let task = Realm.asyncOpen(configuration: config) { result in
                XCTAssertNotNil(try? result.get())
                ex1.fulfill()
            }

            task.addProgressNotification { progress in
                if progress.isTransferComplete {
                    ex2.fulfill()
                }
            }

            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAsyncOpenTimeout() {
        let proxy = TimeoutProxyServer(port: 5678, targetPort: 9090)
        try! proxy.start()

        let appId = try! RealmServer.shared.createApp()
        let appConfig = AppConfiguration(baseURL: "http://localhost:5678",
                                         transport: AsyncOpenConnectionTimeoutTransport(),
                                         localAppName: nil, localAppVersion: nil)
        let app = App(id: appId, configuration: appConfig)

        let syncTimeoutOptions = SyncTimeoutOptions()
        syncTimeoutOptions.connectTimeout = 3000
        app.syncManager.timeoutOptions = syncTimeoutOptions

        let user: User
        do {
            user = try logInUser(for: basicCredentials(app: app), app: app)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            return
        }
        var config = user.configuration(partitionValue: #function, cancelAsyncOpenOnNonFatalErrors: true)
        config.objectTypes = []

        // Two second timeout with a one second delay should work
        autoreleasepool {
            proxy.delay = 1.0
            let ex = expectation(description: "async open")
            Realm.asyncOpen(configuration: config) { result in
                let realm = try? result.get()
                XCTAssertNotNil(realm)
                realm?.syncSession?.suspend()
                ex.fulfill()
            }
            waitForExpectations(timeout: 10.0, handler: nil)
        }

        // Two second timeout with a two second delay should fail
        autoreleasepool {
            proxy.delay = 3.5
            let ex = expectation(description: "async open")
            Realm.asyncOpen(configuration: config) { result in
                guard case .failure(let error) = result else {
                    XCTFail("Did not fail: \(result)")
                    return
                }
                if let error = error as NSError? {
                    XCTAssertEqual(error.code, Int(ETIMEDOUT))
                    XCTAssertEqual(error.domain, NSPOSIXErrorDomain)
                }
                ex.fulfill()
            }
            waitForExpectations(timeout: 4.0, handler: nil)
        }

        proxy.stop()
    }

    func testAppCredentialSupport() {
        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.facebook(accessToken: "accessToken")),
                       RLMCredentials(facebookToken: "accessToken"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.google(serverAuthCode: "serverAuthCode")),
                       RLMCredentials(googleAuthCode: "serverAuthCode"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.apple(idToken: "idToken")),
                       RLMCredentials(appleToken: "idToken"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.emailPassword(email: "email", password: "password")),
                       RLMCredentials(email: "email", password: "password"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.jwt(token: "token")),
                       RLMCredentials(jwt: "token"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.function(payload: ["dog": ["name": "fido"]])),
                       RLMCredentials(functionPayload: ["dog": ["name" as NSString: "fido" as NSString] as NSDictionary]))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.userAPIKey("key")),
                       RLMCredentials(userAPIKey: "key"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.serverAPIKey("key")),
                       RLMCredentials(serverAPIKey: "key"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.anonymous),
                       RLMCredentials.anonymous())
    }

    // MARK: - Authentication

    func testInvalidCredentials() {
        do {
            let email = "testInvalidCredentialsEmail"
            let credentials = basicCredentials()
            let user = try logInUser(for: credentials)
            XCTAssertEqual(user.state, .loggedIn)

            let credentials2 = Credentials.emailPassword(email: email, password: "NOT_A_VALID_PASSWORD")
            let ex = expectation(description: "Should fail to log in the user")

            self.app.login(credentials: credentials2) { result in
                guard case .failure = result else {
                    XCTFail("Login should not have been successful")
                    return ex.fulfill()
                }
                ex.fulfill()
            }

            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - User-specific functionality

    func testUserExpirationCallback() {
        do {
            let user = try logInUser(for: basicCredentials())

            // Set a callback on the user
            var blockCalled = false
            let ex = expectation(description: "Error callback should fire upon receiving an error")
            app.syncManager.errorHandler = { (error, _) in
                XCTAssertNotNil(error)
                blockCalled = true
                ex.fulfill()
            }

            // Screw up the token on the user.
            manuallySetAccessToken(for: user, value: badAccessToken())
            manuallySetRefreshToken(for: user, value: badAccessToken())
            // Try to open a Realm with the user; this will cause our errorHandler block defined above to be fired.
            XCTAssertFalse(blockCalled)
            _ = try immediatelyOpenRealm(partitionValue: #function, user: user)

            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    private func realmURLForFile(_ fileName: String) -> URL {
        let testDir = RLMRealmPathForFile("mongodb-realm")
        let directory = URL(fileURLWithPath: testDir, isDirectory: true)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - App tests

    let appName = "translate-utwuv"

    private func appConfig() -> AppConfiguration {
        return AppConfiguration(baseURL: "http://localhost:9090",
                                transport: nil,
                                localAppName: "auth-integration-tests",
                                localAppVersion: "20180301")
    }

    func testAppInit() {
        let appWithNoConfig = App(id: appName)
        XCTAssertEqual(appWithNoConfig.allUsers.count, 0)

        let appWithConfig = App(id: appName, configuration: appConfig())
        XCTAssertEqual(appWithConfig.allUsers.count, 0)
    }

    func testAppLogin() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: User?

        app.login(credentials: Credentials.emailPassword(email: email, password: password)) { result in
            switch result {
            case .success(let user):
                syncUser = user
            case .failure:
                XCTFail("Should login user")
            }
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.id, app.currentUser?.id)
        XCTAssertEqual(app.allUsers.count, 1)
    }

    func testAppSwitchAndRemove() {
        let email1 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password1 = randomString(10)
        let email2 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password2 = randomString(10)

        let registerUser1Ex = expectation(description: "Register user 1")
        let registerUser2Ex = expectation(description: "Register user 2")

        app.emailPasswordAuth.registerUser(email: email1, password: password1) { (error) in
            XCTAssertNil(error)
            registerUser1Ex.fulfill()
        }

        app.emailPasswordAuth.registerUser(email: email2, password: password2) { (error) in
            XCTAssertNil(error)
            registerUser2Ex.fulfill()
        }

        wait(for: [registerUser1Ex, registerUser2Ex], timeout: 4.0)

        let login1Ex = expectation(description: "Login user 1")
        let login2Ex = expectation(description: "Login user 2")

        var syncUser1: User?
        var syncUser2: User?

        app.login(credentials: Credentials.emailPassword(email: email1, password: password1)) { result in
            if case .success(let user) = result {
                syncUser1 = user
            } else {
                XCTFail("Should login user 1")
            }
            login1Ex.fulfill()
        }

        wait(for: [login1Ex], timeout: 4.0)

        app.login(credentials: Credentials.emailPassword(email: email2, password: password2)) { result in
            if case .success(let user) = result {
                syncUser2 = user
            } else {
                XCTFail("Should login user 2")
            }
            login2Ex.fulfill()
        }

        wait(for: [login2Ex], timeout: 4.0)

        XCTAssertEqual(app.allUsers.count, 2)

        XCTAssertEqual(syncUser2!.id, app.currentUser!.id)

        app.switch(to: syncUser1!)
        XCTAssertTrue(syncUser1!.id == app.currentUser?.id)

        let removeEx = expectation(description: "Remove user 1")

        syncUser1?.remove { (error) in
            XCTAssertNil(error)
            removeEx.fulfill()
        }

        wait(for: [removeEx], timeout: 4.0)

        XCTAssertEqual(syncUser2!.id, app.currentUser!.id)
        XCTAssertEqual(app.allUsers.count, 1)
    }

    func testAppLinkUser() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: User!

        let credentials = Credentials.emailPassword(email: email, password: password)

        app.login(credentials: Credentials.anonymous) { result in
            if case .success(let user) = result {
                syncUser = user
            } else {
                XCTFail("Should login user")
            }
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let linkEx = expectation(description: "Link user")
        syncUser.linkUser(credentials: credentials) { result in
            switch result {
            case .success(let user):
                syncUser = user
            case .failure:
                XCTFail("Should link user")
            }
            linkEx.fulfill()
        }

        wait(for: [linkEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.id, app.currentUser?.id)
        XCTAssertEqual(syncUser?.identities.count, 2)
    }

    // MARK: - Provider Clients

    func testEmailPasswordProviderClient() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let confirmUserEx = expectation(description: "Confirm user")

        app.emailPasswordAuth.confirmUser("atoken", tokenId: "atokenid") { (error) in
            XCTAssertNotNil(error)
            confirmUserEx.fulfill()
        }
        wait(for: [confirmUserEx], timeout: 4.0)

        let resendEmailEx = expectation(description: "Resend email confirmation")

        app.emailPasswordAuth.resendConfirmationEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendEmailEx.fulfill()
        }
        wait(for: [resendEmailEx], timeout: 4.0)

        let resendResetPasswordEx = expectation(description: "Resend reset password email")

        app.emailPasswordAuth.sendResetPasswordEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendResetPasswordEx.fulfill()
        }
        wait(for: [resendResetPasswordEx], timeout: 4.0)

        let resetPasswordEx = expectation(description: "Reset password email")

        app.emailPasswordAuth.resetPassword(to: "password", token: "atoken", tokenId: "tokenId") { (error) in
            XCTAssertNotNil(error)
            resetPasswordEx.fulfill()
        }
        wait(for: [resetPasswordEx], timeout: 4.0)

        let callResetFunctionEx = expectation(description: "Reset password function")
        app.emailPasswordAuth.callResetPasswordFunction(email: email,
                                                                       password: randomString(10),
                                                                       args: [[:]]) { (error) in
            XCTAssertNotNil(error)
            callResetFunctionEx.fulfill()
        }
        wait(for: [callResetFunctionEx], timeout: 4.0)
    }

    func testUserAPIKeyProviderClient() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = Credentials.emailPassword(email: email, password: password)

        var syncUser: User?
        app.login(credentials: credentials) { result in
            switch result {
            case .success(let user):
                syncUser = user
            case .failure:
                XCTFail("Should link user")
            }
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        let createAPIKeyEx = expectation(description: "Create user api key")

        var apiKey: UserAPIKey?
        syncUser?.apiKeysAuth.createAPIKey(named: "my-api-key") { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            apiKey = key
            createAPIKeyEx.fulfill()
        }
        wait(for: [createAPIKeyEx], timeout: 4.0)

        let fetchAPIKeyEx = expectation(description: "Fetch user api key")
        syncUser?.apiKeysAuth.fetchAPIKey(apiKey!.objectId) { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            fetchAPIKeyEx.fulfill()
        }
        wait(for: [fetchAPIKeyEx], timeout: 4.0)

        let fetchAPIKeysEx = expectation(description: "Fetch user api keys")
        syncUser?.apiKeysAuth.fetchAPIKeys(completion: { (keys, error) in
            XCTAssertNotNil(keys)
            XCTAssertEqual(keys!.count, 1)
            XCTAssertNil(error)
            fetchAPIKeysEx.fulfill()
        })
        wait(for: [fetchAPIKeysEx], timeout: 4.0)

        let disableKeyEx = expectation(description: "Disable API key")
        syncUser?.apiKeysAuth.disableAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            disableKeyEx.fulfill()
        }
        wait(for: [disableKeyEx], timeout: 4.0)

        let enableKeyEx = expectation(description: "Enable API key")
        syncUser?.apiKeysAuth.enableAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            enableKeyEx.fulfill()
        }
        wait(for: [enableKeyEx], timeout: 4.0)

        let deleteKeyEx = expectation(description: "Delete API key")
        syncUser?.apiKeysAuth.deleteAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            deleteKeyEx.fulfill()
        }
        wait(for: [deleteKeyEx], timeout: 4.0)
    }

    func testApiKeyAuthResultCompletion() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = Credentials.emailPassword(email: email, password: password)
        var syncUser: User?
        app.login(credentials: credentials) { result in
            switch result {
            case .success(let user):
                syncUser = user
            case .failure:
                XCTFail("Should login")
            }
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let createAPIKeyEx = expectation(description: "Create user api key")
        var apiKey: UserAPIKey?
        syncUser?.apiKeysAuth.createAPIKey(named: "my-api-key") { result in
            switch result {
            case .success(let userAPIKey):
                apiKey = userAPIKey
            case .failure:
                XCTFail("Should create api key")
            }
            createAPIKeyEx.fulfill()
        }
        wait(for: [createAPIKeyEx], timeout: 4.0)

        let fetchAPIKeyEx = expectation(description: "Fetch user api key")
        syncUser?.apiKeysAuth.fetchAPIKey(apiKey!.objectId as! ObjectId, { result in
            if case .failure = result {
                XCTFail("Should fetch api key")
            }
            fetchAPIKeyEx.fulfill()
        })
        wait(for: [fetchAPIKeyEx], timeout: 4.0)

        let fetchAPIKeysEx = expectation(description: "Fetch user api keys")
        syncUser?.apiKeysAuth.fetchAPIKeys { result in
            switch result {
            case .success(let userAPIKeys):
                XCTAssertEqual(userAPIKeys.count, 1)
            case .failure:
                XCTFail("Should fetch api key")
            }
            fetchAPIKeysEx.fulfill()
        }
        wait(for: [fetchAPIKeysEx], timeout: 4.0)
    }

    func testCallFunction() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")

        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials) { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
            case .failure:
                XCTFail("Should link user")
            }
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let callFunctionEx = expectation(description: "Call function")
        app.currentUser?.functions.sum([1, 2, 3, 4, 5]) { bson, error in
            guard let bson = bson else {
                XCTFail(error!.localizedDescription)
                return
            }

            guard case let .int64(sum) = bson else {
                XCTFail(error!.localizedDescription)
                return
            }

            XCTAssertNil(error)
            XCTAssertEqual(sum, 15)
            callFunctionEx.fulfill()
        }
        wait(for: [callFunctionEx], timeout: 4.0)
    }

    func testPushRegistration() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginExpectation = expectation(description: "Login user")

        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials) { result in
            if case .failure = result {
                XCTFail("Should link user")
            }
            loginExpectation.fulfill()
        }
        wait(for: [loginExpectation], timeout: 4.0)

        let registerDeviceExpectation = expectation(description: "Register Device")
        let client = app.pushClient(serviceName: "gcm")
        client.registerDevice(token: "some-token", user: app.currentUser!) { error in
            XCTAssertNil(error)
            registerDeviceExpectation.fulfill()
        }
        wait(for: [registerDeviceExpectation], timeout: 4.0)

        let dergisterDeviceExpectation = expectation(description: "Deregister Device")
        client.deregisterDevice(user: app.currentUser!, completion: { error in
            XCTAssertNil(error)
            dergisterDeviceExpectation.fulfill()
        })
        wait(for: [dergisterDeviceExpectation], timeout: 4.0)
    }

    func testCustomUserData() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials) { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
            case .failure:
                XCTFail("Should link user")
            }
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let userDataEx = expectation(description: "Update user data")
        app.currentUser?.functions.updateUserData([["favourite_colour": "green", "apples": 10]]) { _, error  in
            XCTAssertNil(error)
            userDataEx.fulfill()
        }
        wait(for: [userDataEx], timeout: 4.0)

        let refreshDataEx = expectation(description: "Refresh user data")
        app.currentUser?.refreshCustomData { customData, error in
            XCTAssertNil(error)
            XCTAssertNotNil(customData)
            XCTAssertEqual(customData?["apples"] as! Int, 10)
            XCTAssertEqual(customData?["favourite_colour"] as! String, "green")
            refreshDataEx.fulfill()
        }
        wait(for: [refreshDataEx], timeout: 4.0)

        XCTAssertEqual(app.currentUser?.customData["favourite_colour"], .string("green"))
        XCTAssertEqual(app.currentUser?.customData["apples"], .int64(10))
    }
}

    // MARK: - Mongo Client
@objc(SwiftMongoClientTests)
class SwiftMongoClientTests: SwiftSyncTestCase {
    override func tearDown() {
        _ = setupMongoCollection()
        super.tearDown()
    }
    func testMongoClient() {
        let user = try! logInUser(for: Credentials.anonymous)
        let mongoClient = user.mongoClient("mongodb1")
        XCTAssertEqual(mongoClient.name, "mongodb1")
        let database = mongoClient.database(named: "test_data")
        XCTAssertEqual(database.name, "test_data")
        let collection = database.collection(withName: "Dog")
        XCTAssertEqual(collection.name, "Dog")
    }

    func removeAllFromCollection(_ collection: MongoCollection) {
        let deleteEx = expectation(description: "Delete all from Mongo collection")
        collection.deleteManyDocuments(filter: [:]) { result in
            if case .failure = result {
                XCTFail("Should delete")
            }
            deleteEx.fulfill()
        }
        wait(for: [deleteEx], timeout: 4.0)
    }

    func setupMongoCollection() -> MongoCollection {
        let user = try! logInUser(for: basicCredentials())
        let mongoClient = user.mongoClient("mongodb1")
        let database = mongoClient.database(named: "test_data")
        let collection = database.collection(withName: "Dog")
        removeAllFromCollection(collection)
        return collection
    }

    func testMongoOptions() {
        let findOptions = FindOptions(1, nil, nil)
        let findOptions1 = FindOptions(5, ["name": 1], ["_id": 1])
        let findOptions2 = FindOptions(5, ["names": ["fido", "bob", "rex"]], ["_id": 1])

        XCTAssertEqual(findOptions.limit, 1)
        XCTAssertEqual(findOptions.projection, nil)
        XCTAssertEqual(findOptions.sort, nil)

        XCTAssertEqual(findOptions1.limit, 5)
        XCTAssertEqual(findOptions1.projection, ["name": 1])
        XCTAssertEqual(findOptions1.sort, ["_id": 1])
        XCTAssertEqual(findOptions2.projection, ["names": ["fido", "bob", "rex"]])

        let findModifyOptions = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        XCTAssertEqual(findModifyOptions.projection, ["name": 1])
        XCTAssertEqual(findModifyOptions.sort, ["_id": 1])
        XCTAssertTrue(findModifyOptions.upsert)
        XCTAssertTrue(findModifyOptions.shouldReturnNewDocument)
    }

    func testMongoInsertResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]

        let insertOneEx1 = expectation(description: "Insert one document")
        collection.insertOne(document) { result in
            if case .failure = result {
                XCTFail("Should insert")
            }
            insertOneEx1.fulfill()
        }
        wait(for: [insertOneEx1], timeout: 4.0)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 2)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual(documents.count, 3)
                XCTAssertEqual(documents[0]["name"]??.stringValue, "fido")
                XCTAssertEqual(documents[1]["name"]??.stringValue, "fido")
                XCTAssertEqual(documents[2]["name"]??.stringValue, "rex")
            case .failure:
                XCTFail("Should find")
            }
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)
    }

    func testMongoFindResultCompletion() {
        let collection = setupMongoCollection()

        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]
        let document3: Document = ["name": "rex", "breed": "tibetan mastiff", "coat": ["fawn", "brown", "white"]]
        let findOptions = FindOptions(1, nil, nil)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 3)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { result in
                switch result {
                case .success(let documents):
                    XCTAssertEqual(documents.count, 3)
                    XCTAssertEqual(documents[0]["name"]??.stringValue, "fido")
                    XCTAssertEqual(documents[1]["name"]??.stringValue, "rex")
                    XCTAssertEqual(documents[2]["name"]??.stringValue, "rex")
                case .failure:
                    XCTFail("Should find")
                }
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)

        let findEx2 = expectation(description: "Find documents")
        collection.find(filter: [:], options: findOptions) { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(document.count, 1)
                XCTAssertEqual(document[0]["name"]??.stringValue, "fido")
            case .failure:
                XCTFail("Should find")
            }
            findEx2.fulfill()
        }
        wait(for: [findEx2], timeout: 4.0)

        let findEx3 = expectation(description: "Find documents")
        collection.find(filter: document3, options: findOptions) { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual(documents.count, 1)
            case .failure:
                XCTFail("Should find")
            }
            findEx3.fulfill()
        }
        wait(for: [findEx3], timeout: 4.0)

        let findOneEx1 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document) { result in
            switch result {
            case .success(let document):
                XCTAssertNotNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneEx1.fulfill()
        }
        wait(for: [findOneEx1], timeout: 4.0)

        let findOneEx2 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document, options: findOptions) { result in
            switch result {
            case .success(let document):
                XCTAssertNotNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneEx2.fulfill()
        }
        wait(for: [findOneEx2], timeout: 4.0)
    }

    func testMongoFindAndReplaceResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneReplaceEx1 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2) { result in
            switch result {
            case .success(let document):
                // no doc found, both should be nil
                XCTAssertNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneReplaceEx1.fulfill()
        }
        wait(for: [findOneReplaceEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneReplaceEx2 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document2, replacement: document3, options: options1) { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(document!["name"]??.stringValue, "john")
            case .failure:
                XCTFail("Should find")
            }
            findOneReplaceEx2.fulfill()
        }
        wait(for: [findOneReplaceEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, false)
        let findOneReplaceEx3 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2, options: options2) { result in
            switch result {
            case .success(let document):
                // upsert but do not return document
                XCTAssertNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneReplaceEx3.fulfill()
        }
        wait(for: [findOneReplaceEx3], timeout: 4.0)
    }

    func testMongoFindAndUpdateResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneUpdateEx1 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2) { result in
            switch result {
            case .success(let document):
                // no doc found, both should be nil
                XCTAssertNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneUpdateEx1.fulfill()
        }
        wait(for: [findOneUpdateEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx2 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document2, update: document3, options: options1) { result in
            switch result {
            case .success(let document):
                XCTAssertNotNil(document)
                XCTAssertEqual(document!["name"]??.stringValue, "john")
            case .failure:
                XCTFail("Should find")
            }
            findOneUpdateEx2.fulfill()
        }
        wait(for: [findOneUpdateEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx3 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2, options: options2) { result in
            switch result {
            case .success(let document):
                XCTAssertNotNil(document)
                XCTAssertEqual(document!["name"]??.stringValue, "rex")
            case .failure:
                XCTFail("Should find")
            }
            findOneUpdateEx3.fulfill()
        }
        wait(for: [findOneUpdateEx3], timeout: 4.0)
    }

    func testMongoFindAndDeleteResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 1)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let findOneDeleteEx1 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document) { result in
            switch result {
            case .success(let document):
                // Document does not exist, but should not return an error because of that
                XCTAssertNotNil(document)
            case .failure:
                XCTFail("Should find")
            }
            findOneDeleteEx1.fulfill()
        }
        wait(for: [findOneDeleteEx1], timeout: 4.0)

        // FIXME: It seems there is a possible server bug that does not handle
        // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
        // "expected pre-image to match projection matcher"
        // https://jira.mongodb.org/browse/REALMC-6878
        /*
        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], false, false)
        let findOneDeleteEx2 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options1) { (document, error) in
            // Document does not exist, but should not return an error because of that
            XCTAssertNil(document)
            XCTAssertNil(error)
            findOneDeleteEx2.fulfill()
        }
        wait(for: [findOneDeleteEx2], timeout: 4.0)
        */

        // FIXME: It seems there is a possible server bug that does not handle
        // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
        // "expected pre-image to match projection matcher"
        // https://jira.mongodb.org/browse/REALMC-6878
        /*
        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1])
        let findOneDeleteEx3 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options2) { (document, error) in
            XCTAssertNotNil(document)
            XCTAssertEqual(document!["name"] as! String, "fido")
            XCTAssertNil(error)
            findOneDeleteEx3.fulfill()
        }
        wait(for: [findOneDeleteEx3], timeout: 4.0)
        */

        let findEx = expectation(description: "Find documents")
        collection.find(filter: [:]) { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual(documents.count, 0)
            case .failure:
                XCTFail("Should find")
            }
            findEx.fulfill()
        }
        wait(for: [findEx], timeout: 4.0)
    }

    func testMongoUpdateOneResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 4)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document, update: document2) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(updateResult.matchedCount, 1)
                XCTAssertEqual(updateResult.modifiedCount, 1)
                XCTAssertNil(updateResult.objectId)
            case .failure:
                XCTFail("Should update")
            }
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document5, update: document2, upsert: true) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(updateResult.matchedCount, 0)
                XCTAssertEqual(updateResult.modifiedCount, 0)
                XCTAssertNotNil(updateResult.objectId)
            case .failure:
                XCTFail("Should update")
            }
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoUpdateManyResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 4)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document, update: document2) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(updateResult.matchedCount, 1)
                XCTAssertEqual(updateResult.modifiedCount, 1)
                XCTAssertNil(updateResult.objectId)
            case .failure:
                XCTFail("Should update")
            }
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document5, update: document2, upsert: true) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(updateResult.matchedCount, 0)
                XCTAssertEqual(updateResult.modifiedCount, 0)
                XCTAssertNotNil(updateResult.objectId)
            case .failure:
                XCTFail("Should update")
            }
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoDeleteOneResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteOneDocument(filter: document) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 0)
            case .failure:
                XCTFail("Should delete")
            }
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 2)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteOneDocument(filter: document) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 1)
            case .failure:
                XCTFail("Should delete")
            }
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoDeleteManyResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteManyDocuments(filter: document) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 0)
            case .failure:
                XCTFail("Should delete")
            }
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 2)
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteManyDocuments(filter: ["breed": "cane corso"]) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 2)
            case .failure:
                XCTFail("Should selete")
            }
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoCountAndAggregateResultCompletion() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document]) { result in
            switch result {
            case .success(let objectIds):
                XCTAssertEqual(objectIds.count, 1)
            case .failure(let error):
                XCTFail("Insert failed: \(error)")
            }
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        collection.aggregate(pipeline: [["$match": ["name": "fido"]], ["$group": ["_id": "$name"]]]) { result in
            switch result {
            case .success(let documents):
                XCTAssertNotNil(documents)
            case .failure(let error):
                XCTFail("Aggregate failed: \(error)")
            }
        }

        let countEx1 = expectation(description: "Count documents")
        collection.count(filter: document) { result in
            switch result {
            case .success(let count):
                XCTAssertNotNil(count)
            case .failure(let error):
                XCTFail("Count failed: \(error)")
            }
            countEx1.fulfill()
        }
        wait(for: [countEx1], timeout: 4.0)

        let countEx2 = expectation(description: "Count documents")
        collection.count(filter: document, limit: 1) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 1)
            case .failure(let error):
                XCTFail("Count failed: \(error)")
            }
            countEx2.fulfill()
        }
        wait(for: [countEx2], timeout: 4.0)
    }

    func testWatch() {
        performWatchTest(nil)
    }

    func testWatchAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchTest(queue)
    }

    func performWatchTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3, expectation: &watchEx)

        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(delegate: watchTestUtility, queue: queue)
        } else {
            changeStream = collection.watch(delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for _ in 0..<3 {
                collection.insertOne(document) { result in
                    if case .failure = result {
                        XCTFail("Should insert")
                    }
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchWithMatchFilter() {
        performWatchWithMatchFilterTest(nil)
    }

    func testWatchWithMatchFilterAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchWithMatchFilterTest(queue)
    }

    func performWatchWithMatchFilterTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()
        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objIds):
                XCTAssertEqual(objIds.count, 4)
                objectIds = objIds.map { $0.objectIdValue! }
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3, matchingObjectId: objectIds.first!, expectation: &watchEx)

        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])],
                                            delegate: watchTestUtility,
                                            queue: queue)
        } else {
            changeStream = collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])],
                                            delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchWithFilterIds() {
        performWatchWithFilterIdsTest(nil)
    }

    func testWatchWithFilterIdsAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchWithFilterIdsTest(queue)
    }

    func performWatchWithFilterIdsTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objIds):
                XCTAssertEqual(objIds.count, 4)
                objectIds = objIds.map { $0.objectIdValue! }
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3,
                                                matchingObjectId: objectIds.first!,
                                                expectation: &watchEx)
        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility, queue: queue)
        } else {
            changeStream = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchMultipleFilterStreams() {
        performMultipleWatchStreamsTest(nil)
    }

    func testWatchMultipleFilterStreamsAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performMultipleWatchStreamsTest(queue)
    }

    func performMultipleWatchStreamsTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objIds):
                XCTAssertEqual(objIds.count, 4)
                objectIds = objIds.map { $0.objectIdValue! }
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 5 document events")
        watchEx.expectedFulfillmentCount = 2

        let watchTestUtility1 = WatchTestUtility(targetEventCount: 3,
                                                 matchingObjectId: objectIds[0],
                                                 expectation: &watchEx)

        let watchTestUtility2 = WatchTestUtility(targetEventCount: 3,
                                                 matchingObjectId: objectIds[1],
                                                 expectation: &watchEx)

        let changeStream1: ChangeStream?
        let changeStream2: ChangeStream?

        if let queue = queue {
            changeStream1 = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility1, queue: queue)
            changeStream2 = collection.watch(filterIds: [objectIds[1]], delegate: watchTestUtility2, queue: queue)
        } else {
            changeStream1 = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility1)
            changeStream2 = collection.watch(filterIds: [objectIds[1]], delegate: watchTestUtility2)
        }

        let teardownEx = expectation(description: "All changes complete")
        DispatchQueue.global().async {
            watchTestUtility1.isOpenSemaphore.wait()
            watchTestUtility2.isOpenSemaphore.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                watchTestUtility1.semaphore.wait()
                watchTestUtility2.semaphore.wait()
            }
            changeStream1?.close()
            changeStream2?.close()
            teardownEx.fulfill()
        }
        wait(for: [watchEx, teardownEx], timeout: 60.0)
    }

    func testShouldNotDeleteOnMigrationWithSync() {
        let user = try! logInUser(for: basicCredentials())
        var configuration = user.configuration(testName: appId)

        assertThrows(configuration.deleteRealmIfMigrationNeeded = true,
                     reason: "Cannot set 'deleteRealmIfMigrationNeeded' when sync is enabled ('syncConfig' is set).")

        var localConfiguration = Realm.Configuration.defaultConfiguration
        assertSucceeds {
            localConfiguration.deleteRealmIfMigrationNeeded = true
        }
    }
}

#if REALM_HAVE_COMBINE || !SWIFT_PACKAGE

// XCTest doesn't care about the @available on the class and will try to run
// the tests even on older versions. Putting this check inside `defaultTestSuite`
// results in a warning about it being redundant due to the enclosing check, so
// it needs to be out of line.
func hasCombine() -> Bool {
    if #available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *) {
        return true
    }
    return false
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
extension Publisher {
    func expectValue(_ testCase: XCTestCase, _ expectation: XCTestExpectation, receiveValue: ((Self.Output) -> Void)? = nil) -> AnyCancellable {
        return self.sink(receiveCompletion: { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
        }, receiveValue: { value in
            receiveValue?(value)
            expectation.fulfill()
        })
    }

    func await(_ testCase: XCTestCase, timeout: TimeInterval = 4.0, receiveValue: ((Self.Output) -> Void)? = nil) {
        let expectation = testCase.expectation(description: "Async combine pipeline")
        let cancellable = self.expectValue(testCase, expectation, receiveValue: receiveValue)
        testCase.wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
    }

    func awaitFailure(_ testCase: XCTestCase, timeout: TimeInterval = 4.0) {
        let expectation = testCase.expectation(description: "Async combine pipeline should fail")
        let cancellable = self.sink(receiveCompletion: { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }, receiveValue: { value in
            XCTFail("Should have failed but got \(value)")
        })
        testCase.wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
    }
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
@objc(CombineObjectServerTests)
class CombineObjectServerTests: SwiftSyncTestCase {
    override class var defaultTestSuite: XCTestSuite {
        if hasCombine() {
            return super.defaultTestSuite
        }
        return XCTestSuite(name: "\(type(of: self))")
    }

    var subscriptions: Set<AnyCancellable> = []

    override func tearDown() {
        subscriptions.forEach { $0.cancel() }
        subscriptions = []
        super.tearDown()
    }

    func setupMongoCollection() -> MongoCollection {
        let user = try! logInUser(for: basicCredentials())
        let mongoClient = user.mongoClient("mongodb1")
        let database = mongoClient.database(named: "test_data")
        let collection = database.collection(withName: "Dog")
        removeAllFromCollection(collection)
        return collection
    }

    func removeAllFromCollection(_ collection: MongoCollection) {
        collection.deleteManyDocuments(filter: [:]).await(self)
    }

    // swiftlint:disable multiple_closures_with_trailing_closure
    func testWatchCombine() {
        let sema = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3

        collection.watch()
            .onOpen {
                openSema.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { _ in
                watchEx1.fulfill()
                XCTAssertFalse(Thread.isMainThread)
                sema.signal()
            }.store(in: &subscriptions)

        collection.watch()
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { _ in
                watchEx2.fulfill()
                XCTAssertTrue(Thread.isMainThread)
                sema2.signal()
            }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema.wait()
            openSema2.wait()
            for _ in 0..<3 {
                collection.insertOne(document) { result in
                    if case .failure(let error) = result {
                        XCTFail("Failed to insert: \(error)")
                    }
                }
                sema.wait()
                sema2.wait()
            }
            DispatchQueue.main.async {
                self.subscriptions.forEach { $0.cancel() }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    func testWatchCombineWithFilterIds() {
        let sema1 = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema1 = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objIds):
                XCTAssertEqual(objIds.count, 4)
                objectIds = objIds.map { $0.objectIdValue! }
            case .failure:
                XCTFail("Should insert")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3

        collection.watch(filterIds: [objectIds[0]])
            .onOpen {
                openSema1.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertTrue(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[0] {
                    watchEx1.fulfill()
                    sema1.signal()
                }
            }.store(in: &subscriptions)

        collection.watch(filterIds: [objectIds[1]])
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { (changeEvent) in
                XCTAssertFalse(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[1] {
                    watchEx2.fulfill()
                    sema2.signal()
                }
            }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema1.wait()
            openSema2.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure(let error) = result {
                        XCTFail("Failed to update: \(error)")
                    }
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure(let error) = result {
                        XCTFail("Failed to update: \(error)")
                    }
                }
                sema1.wait()
                sema2.wait()
            }
            DispatchQueue.main.async {
                self.subscriptions.forEach { $0.cancel() }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    func testWatchCombineWithMatchFilter() {
        let sema1 = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema1 = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { result in
            switch result {
            case .success(let objIds):
                XCTAssertEqual(objIds.count, 4)
                objectIds = objIds.map { $0.objectIdValue! }
            case .failure(let error):
                XCTFail("Failed to insert: \(error)")
            }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3

        collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])])
            .onOpen {
                openSema1.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertTrue(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[0] {
                    watchEx1.fulfill()
                    sema1.signal()
                }
        }.store(in: &subscriptions)

        collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[1])])
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertFalse(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[1] {
                    watchEx2.fulfill()
                    sema2.signal()
                }
        }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema1.wait()
            openSema2.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { result in
                    if case .failure = result {
                        XCTFail("Should update")
                    }
                }
                sema1.wait()
                sema2.wait()
            }
            DispatchQueue.main.async {
                self.subscriptions.forEach { $0.cancel() }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    // MARK: - Combine promises

    func testEmailPasswordAuthenticationCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)
        let auth = app.emailPasswordAuth

        auth.registerUser(email: email, password: password).await(self)
        auth.confirmUser("atoken", tokenId: "atokenid").awaitFailure(self)
        auth.resendConfirmationEmail(email: "atoken").awaitFailure(self)
        auth.sendResetPasswordEmail(email: "atoken").awaitFailure(self)
        auth.resetPassword(to: "password", token: "atoken", tokenId: "tokenId").awaitFailure(self)
        auth.callResetPasswordFunction(email: email, password: randomString(10), args: [[:]]).awaitFailure(self)
    }

    func testAppLoginCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let loginEx = expectation(description: "Login user")
        let appEx = expectation(description: "App changes triggered")
        var triggered = 0
        app.objectWillChange.sink { _ in
            triggered += 1
            if triggered == 2 {
                appEx.fulfill()
            }
        }.store(in: &subscriptions)

        app.emailPasswordAuth.registerUser(email: email, password: password)
            .flatMap { self.app.login(credentials: .emailPassword(email: email, password: password)) }
            .sink(receiveCompletion: { result in
                if case let .failure(error) = result {
                    XCTFail("Should have completed login chain: \(error.localizedDescription)")
                }
            }, receiveValue: { user in
                user.objectWillChange.sink { user in
                    XCTAssert(!user.isLoggedIn)
                    loginEx.fulfill()
                }.store(in: &self.subscriptions)
                XCTAssertEqual(user.id, self.app.currentUser?.id)
                user.logOut { _ in } // logout user and make sure it is observed
            })
            .store(in: &subscriptions)
        wait(for: [loginEx, appEx], timeout: 30.0)
        XCTAssertEqual(self.app.allUsers.count, 1)
        XCTAssertEqual(triggered, 2)
    }

    func testAsyncOpenCombine() {
        if isParent {
            let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
            let password = randomString(10)
            app.emailPasswordAuth.registerUser(email: email, password: password)
                .flatMap { self.app.login(credentials: .emailPassword(email: email, password: password)) }
                .flatMap { user in
                    Realm.asyncOpen(configuration: user.configuration(testName: #function))
                }
                .await(self, timeout: 30.0) { realm in
                    try! realm.write {
                        realm.add(SwiftHugeSyncObject.create())
                        realm.add(SwiftHugeSyncObject.create())
                    }
                    let progressEx = self.expectation(description: "Should upload")
                    let token = realm.syncSession!.addProgressNotification(for: .upload, mode: .forCurrentlyOutstandingWork) {
                        if $0.isTransferComplete {
                            progressEx.fulfill()
                        }
                    }
                    self.wait(for: [progressEx], timeout: 30.0)
                    token?.invalidate()
                }
            executeChild()
        } else {
            let chainEx = expectation(description: "Should chain realm login => realm async open")
            let progressEx = expectation(description: "Should receive progress notification")
            app.login(credentials: .anonymous)
                .flatMap {
                    Realm.asyncOpen(configuration: $0.configuration(testName: #function)).onProgressNotification {
                        if $0.isTransferComplete {
                            progressEx.fulfill()
                        }
                    }
                }
                .expectValue(self, chainEx) { realm in
                    XCTAssertEqual(realm.objects(SwiftHugeSyncObject.self).count, 2)
                }.store(in: &subscriptions)
            wait(for: [chainEx, progressEx], timeout: 30.0)
        }
    }

    func testAsyncOpenStandaloneCombine() {
        autoreleasepool {
            let realm = try! Realm()
            try! realm.write {
                (0..<10000).forEach { _ in realm.add(SwiftPerson(firstName: "Charlie", lastName: "Bucket")) }
            }
        }
        Realm.asyncOpen().await(self) { realm in
            XCTAssertEqual(realm.objects(SwiftPerson.self).count, 10000)
        }
    }

    func testRefreshCustomDataCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        app.emailPasswordAuth.registerUser(email: email, password: password).await(self)

        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials)
            .await(self) { user in
                XCTAssertNotNil(user)
            }

        let userDataEx = expectation(description: "Update user data")
        app.currentUser?.functions.updateUserData([["favourite_colour": "green", "apples": 10]]) { _, error  in
            XCTAssertNil(error)
            userDataEx.fulfill()
        }
        wait(for: [userDataEx], timeout: 4.0)

        app.currentUser?.refreshCustomData()
            .await(self) { customData in
                XCTAssertEqual(customData["apples"] as! Int, 10)
                XCTAssertEqual(customData["favourite_colour"] as! String, "green")
            }

        XCTAssertEqual(app.currentUser?.customData["favourite_colour"], .string("green"))
        XCTAssertEqual(app.currentUser?.customData["apples"], .int64(10))
    }

    func testMongoCollectionInsertCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]

        collection.insertOne(document).await(self)
        collection.insertMany([document, document2])
            .await(self) { objectIds in
                XCTAssertEqual(objectIds.count, 2)
            }
        collection.find(filter: [:])
            .await(self) { findResult in
                XCTAssertEqual(findResult.map({ $0["name"]??.stringValue }), ["fido", "fido", "rex"])
            }
    }

    func testMongoCollectionFindCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]
        let document3: Document = ["name": "rex", "breed": "tibetan mastiff", "coat": ["fawn", "brown", "white"]]
        let findOptions = FindOptions(1, nil, nil)

        collection.find(filter: [:], options: findOptions)
            .await(self) { findResult in
                XCTAssertEqual(findResult.count, 0)
            }
        collection.insertMany([document, document2, document3]).await(self)
        collection.find(filter: [:])
            .await(self) { findResult in
                XCTAssertEqual(findResult.map({ $0["name"]??.stringValue }), ["fido", "rex", "rex"])
            }
        collection.find(filter: [:], options: findOptions)
            .await(self) { findResult in
                XCTAssertEqual(findResult.count, 1)
                XCTAssertEqual(findResult[0]["name"]??.stringValue, "fido")
            }
        collection.find(filter: document3, options: findOptions)
            .await(self) { findResult in
                XCTAssertEqual(findResult.count, 1)
            }
        collection.findOneDocument(filter: document).await(self)

        collection.findOneDocument(filter: document, options: findOptions).await(self)
    }

    func testMongoCollectionCountAndAggregateCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        collection.insertMany([document]).await(self)
        collection.aggregate(pipeline: [["$match": ["name": "fido"]], ["$group": ["_id": "$name"]]])
            .await(self)
        collection.count(filter: document).await(self) { count in
            XCTAssertEqual(count, 1)
        }
        collection.count(filter: document, limit: 1).await(self) { count in
            XCTAssertEqual(count, 1)
        }
    }

    func testMongoCollectionDeleteOneCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        collection.deleteOneDocument(filter: document).await(self) { count in
            XCTAssertEqual(count, 0)
        }
        collection.insertMany([document, document2]).await(self)
        collection.deleteOneDocument(filter: document).await(self) { count in
            XCTAssertEqual(count, 1)
        }
    }

    func testMongoCollectionDeleteManyCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        collection.deleteManyDocuments(filter: document).await(self) { count in
            XCTAssertEqual(count, 0)
        }
        collection.insertMany([document, document2]).await(self)
        collection.deleteManyDocuments(filter: ["breed": "cane corso"]).await(self) { count in
            XCTAssertEqual(count, 2)
        }
    }

    func testMongoCollectionUpdateOneCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        collection.insertMany([document, document2, document3, document4]).await(self)
        collection.updateOneDocument(filter: document, update: document2).await(self) { updateResult in
            XCTAssertEqual(updateResult.matchedCount, 1)
            XCTAssertEqual(updateResult.modifiedCount, 1)
            XCTAssertNil(updateResult.objectId)
        }

        collection.updateOneDocument(filter: document5, update: document2, upsert: true).await(self) { updateResult in
            XCTAssertEqual(updateResult.matchedCount, 0)
            XCTAssertEqual(updateResult.modifiedCount, 0)
            XCTAssertNotNil(updateResult.objectId)
        }
    }

    func testMongoCollectionUpdateManyCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        collection.insertMany([document, document2, document3, document4]).await(self)
        collection.updateManyDocuments(filter: document, update: document2).await(self) { updateResult in
            XCTAssertEqual(updateResult.matchedCount, 1)
            XCTAssertEqual(updateResult.modifiedCount, 1)
            XCTAssertNil(updateResult.objectId)
        }
        collection.updateManyDocuments(filter: document5, update: document2, upsert: true).await(self) { updateResult in
            XCTAssertEqual(updateResult.matchedCount, 0)
            XCTAssertEqual(updateResult.modifiedCount, 0)
            XCTAssertNotNil(updateResult.objectId)
        }
    }

    func testMongoCollectionFindAndUpdateCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        collection.findOneAndUpdate(filter: document, update: document2).await(self)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        collection.findOneAndUpdate(filter: document2, update: document3, options: options1).await(self) { updateResult in
            guard let updateResult = updateResult else {
                XCTFail("Should find")
                return
            }
            XCTAssertEqual(updateResult["name"]??.stringValue, "john")
        }

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        collection.findOneAndUpdate(filter: document, update: document2, options: options2).await(self) { updateResult in
            guard let updateResult = updateResult else {
                XCTFail("Should find")
                return
            }
            XCTAssertEqual(updateResult["name"]??.stringValue, "rex")
        }
    }

    func testMongoCollectionFindAndReplaceCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        collection.findOneAndReplace(filter: document, replacement: document2).await(self) { updateResult in
            XCTAssertNil(updateResult)
        }

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        collection.findOneAndReplace(filter: document2, replacement: document3, options: options1).await(self) { updateResult in
            guard let updateResult = updateResult else {
                XCTFail("Should find")
                return
            }
            XCTAssertEqual(updateResult["name"]??.stringValue, "john")
        }

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, false)
        collection.findOneAndReplace(filter: document, replacement: document2, options: options2).await(self) { updateResult in
            XCTAssertNil(updateResult)
        }
    }

    func testMongoCollectionFindAndDeleteCombine() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        collection.insertMany([document]).await(self)

        collection.findOneAndDelete(filter: document).await(self) { updateResult in
            XCTAssertNotNil(updateResult)
        }
        collection.findOneAndDelete(filter: document).await(self) { updateResult in
            XCTAssertNil(updateResult)
        }

        collection.insertMany([document]).await(self)
        let options1 = FindOneAndModifyOptions(projection: ["name": 1], sort: ["_id": 1], upsert: false, shouldReturnNewDocument: false)
        collection.findOneAndDelete(filter: document, options: options1).await(self) { deleteResult in
            XCTAssertNotNil(deleteResult)
        }
        collection.findOneAndDelete(filter: document, options: options1).await(self) { deleteResult in
            XCTAssertNil(deleteResult)
        }

        collection.insertMany([document]).await(self)
        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1])
        collection.findOneAndDelete(filter: document, options: options2).await(self) { deleteResult in
            XCTAssertNotNil(deleteResult)
        }
        collection.findOneAndDelete(filter: document, options: options2).await(self) { deleteResult in
            XCTAssertNil(deleteResult)
        }

        collection.insertMany([document]).await(self)
        collection.find(filter: [:]).await(self) { updateResult in
            XCTAssertEqual(updateResult.count, 1)
        }
    }

    func testCallFunctionCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        app.emailPasswordAuth.registerUser(email: email, password: password).await(self)

        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials).await(self) { user in
            XCTAssertNotNil(user)
        }

        app.currentUser?.functions.sum([1, 2, 3, 4, 5]).await(self) { bson in
            guard case let .int64(sum) = bson else {
                XCTFail("Should be int64")
                return
            }
            XCTAssertEqual(sum, 15)
        }

        app.currentUser?.functions.updateUserData([["favourite_colour": "green", "apples": 10]]).await(self) { bson in
            guard case let .bool(upd) = bson else {
                XCTFail("Should be bool")
                return
            }
            XCTAssertTrue(upd)
        }
    }

    func testAPIKeyAuthCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        app.emailPasswordAuth.registerUser(email: email, password: password).await(self)

        var syncUser: User?
        app.login(credentials: Credentials.emailPassword(email: email, password: password)).await(self) { user in
            syncUser = user
        }

        var apiKey: UserAPIKey?
        syncUser?.apiKeysAuth.createAPIKey(named: "my-api-key").await(self) { userApiKey in
            apiKey = userApiKey
        }

        var objId: ObjectId? = try? ObjectId(string: apiKey!.objectId.stringValue)
        syncUser?.apiKeysAuth.fetchAPIKey(objId!).await(self) { userApiKey in
            apiKey = userApiKey
        }

        syncUser?.apiKeysAuth.fetchAPIKeys().await(self) { userApiKeys in
            XCTAssertEqual(userApiKeys.count, 1)
        }

        objId = try? ObjectId(string: apiKey!.objectId.stringValue)
        syncUser?.apiKeysAuth.disableAPIKey(objId!).await(self)
        syncUser?.apiKeysAuth.enableAPIKey(objId!).await(self)
        syncUser?.apiKeysAuth.deleteAPIKey(objId!).await(self)
    }

    func testPushRegistrationCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        app.emailPasswordAuth.registerUser(email: email, password: password).await(self)
        app.login(credentials: Credentials.emailPassword(email: email, password: password)).await(self)

        let client = app.pushClient(serviceName: "gcm")
        client.registerDevice(token: "some-token", user: app.currentUser!).await(self)
        client.deregisterDevice(user: app.currentUser!).await(self)
    }
}
#endif

#endif // os(macOS)
