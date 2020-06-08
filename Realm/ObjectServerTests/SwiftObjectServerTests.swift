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

import XCTest
import RealmSwift

// Used by testOfflineClientReset
// The naming here is nonstandard as the sync-1.x.realm test file comes from the .NET unit tests.
// swiftlint:disable identifier_name

class SwiftPerson: Object {
    @objc dynamic var _id: ObjectId? = ObjectId.generate()
    @objc dynamic var firstName: String = ""
    @objc dynamic var lastName: String = ""
    @objc dynamic var age: Int = 30
    @objc dynamic var realm_id: String? = ""

    convenience init(firstName: String, lastName: String, realm_id: String) {
        self.init()
        self.firstName = firstName
        self.lastName = lastName
        self.realm_id = realm_id
    }

    override class func primaryKey() -> String? {
        return "_id"
    }
}

class SwiftObjectServerTests: SwiftSyncTestCase {
    /// It should be possible to successfully open a Realm configured for sync.
    func testBasicSwiftSync() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
            XCTAssert(realm.isEmpty, "Freshly synced Realm was not empty...")
        } catch {
            XCTFail("Got an error: \(error)")
        }
    }

    /// If client B adds objects to a Realm, client A should see those new objects.
    func testSwiftAddObjects() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
            if isParent {
                waitForDownloads(for: realm)
                checkCount(expected: 0, realm, SwiftPerson.self)
                executeChild()
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            } else {
                // Add objects
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr", realm_id: "foo"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: "foo"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney", realm_id: "foo"))
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
            if isParent {
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr", realm_id: "foo"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: "foo"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney", realm_id: "foo"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
                executeChild()
            } else {
                checkCount(expected: 0, realm, SwiftPerson.self)
                waitForDownloads(for: realm)
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
        let partitionValueA = "foo"
        let partitionValueB = "bar"
        let partitionValueC = "baz"

        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())

            let realmA = try Realm(configuration: user.configuration(partitionValue: partitionValueA))
            let realmB = try Realm(configuration: user.configuration(partitionValue: partitionValueB))
            let realmC = try Realm(configuration: user.configuration(partitionValue: partitionValueC))

            if self.isParent {
                waitForDownloads(for: realmA)
                waitForDownloads(for: realmB)
                waitForDownloads(for: realmC)

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
                    realmA.add(SwiftPerson(firstName: "Ringo", lastName: "Starr", realm_id: partitionValueA))
                    realmA.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: partitionValueA))
                    realmA.add(SwiftPerson(firstName: "Paul", lastName: "McCartney", realm_id: partitionValueA))
                }
                try realmB.write {
                    realmB.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: partitionValueB))
                    realmB.add(SwiftPerson(firstName: "Paul", lastName: "McCartney", realm_id: partitionValueB))
                }
                try realmC.write {
                    realmC.add(SwiftPerson(firstName: "Ringo", lastName: "Starr", realm_id: partitionValueC))
                    realmC.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: partitionValueC))
                    realmC.add(SwiftPerson(firstName: "Paul", lastName: "McCartney", realm_id: partitionValueC))
                    realmC.add(SwiftPerson(firstName: "George", lastName: "Harrison", realm_id: partitionValueC))
                    realmC.add(SwiftPerson(firstName: "Pete", lastName: "Best", realm_id: partitionValueC))
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)

            var theError: SyncError?
            let ex = expectation(description: "Waiting for error handler to be called...")
            app.syncManager.errorHandler = { (error, session) in
                if let error = error as? SyncError {
                    theError = error
                } else {
                    XCTFail("Error \(error) was not a sync error. Something is wrong.")
                }
                ex.fulfill()
            }
            user.simulateClientResetError(forSession: "foo")
            waitForExpectations(timeout: 10, handler: nil)
            XCTAssertNotNil(theError)
            XCTAssertTrue(theError!.code == SyncError.Code.clientResetError)
            let resetInfo = theError!.clientResetInfo()
            XCTAssertNotNil(resetInfo)
            XCTAssertTrue(resetInfo!.0.contains("io.realm.object-server-recovered-realms/recovered_realm"))
            XCTAssertNotNil(realm)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testClientResetManualInitiation() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            var theError: SyncError?

            try autoreleasepool {
                let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
                let ex = expectation(description: "Waiting for error handler to be called...")
                app.syncManager.errorHandler = { (error, session) in
                    if let error = error as? SyncError {
                        theError = error
                    } else {
                        XCTFail("Error \(error) was not a sync error. Something is wrong.")
                    }
                    ex.fulfill()
                }
                user.simulateClientResetError(forSession: "foo")
                waitForExpectations(timeout: 10, handler: nil)
                XCTAssertNotNil(theError)
                XCTAssertNotNil(realm)
            }
            let (path, errorToken) = theError!.clientResetInfo()!
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
            SyncSession.immediatelyHandleError(errorToken)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }


    // MARK: - Progress notifiers

    let bigObjectCount = 2

    func populateRealm(user: SyncUser, partitionValue: String) {
        do {

            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: partitionValue, user: user)
            try! realm.write {
                for _ in 0..<bigObjectCount {
                    realm.add(SwiftPerson(firstName: "Arthur",
                                          lastName: "Jones",
                                          realm_id: partitionValue))
                }
            }
            waitForUploads(for: realm)
            checkCount(expected: bigObjectCount, realm, SwiftPerson.self)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // FIXME: Dependancy on Stitch deployment
    #if false
    func testStreamingDownloadNotifier() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionKey: "realm_id")
                //return
            }

            var callCount = 0
            var transferred = 0
            var transferrable = 0
            let realm = try synchronouslyOpenRealm(partitionValue: "realm_id", user: user)

            let session = realm.syncSession
            XCTAssertNotNil(session)
            let ex = expectation(description: "streaming-downloads-expectation")
            var hasBeenFulfilled = false

            let token = session!.addProgressNotification(for: .download, mode: .forCurrentlyOutstandingWork) { p in
                callCount += 1
                XCTAssert(p.transferredBytes >= transferred)
                XCTAssert(p.transferrableBytes >= transferrable)
                transferred = p.transferredBytes
                transferrable = p.transferrableBytes
                if p.transferredBytes > 0 && p.isTransferComplete && !hasBeenFulfilled {
                    ex.fulfill()
                    hasBeenFulfilled = true
                }
            }

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
    #endif

    func testStreamingUploadNotifier() {
        do {
            var transferred = 0
            var transferrable = 0
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: "foo", user: user)
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
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon", realm_id: "foo"))
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: "foo")
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let config = user.configuration(partitionValue: "foo")
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { realm, error in
                XCTAssertNil(error)
                guard let realm = realm else {
                    XCTFail("No realm on async open")
                    ex.fulfill()
                    return
                }
                self.checkCount(expected: self.bigObjectCount, realm, SwiftPerson.self)
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: "foo")
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let customFileURL = realmURLForFile("copy")
            var config = user.configuration(partitionValue: "foo")
            config.fileURL = customFileURL
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertEqual(pathOnDisk, customFileURL.path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { realm, error in
                XCTAssertNil(error)
                self.checkCount(expected: self.bigObjectCount, realm!, SwiftPerson.self)
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
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: "foo")
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            // Use a serial queue for asyncOpen to ensure that the first one adds
            // the completion block before the second one cancels it
            RLMSetAsyncOpenQueue(DispatchQueue(label: "io.realm.asyncOpen"))

            let ex = expectation(description: "async open")
            let config = user.configuration(partitionValue: "foo")
            Realm.asyncOpen(configuration: config) { _, error in
                XCTAssertNotNil(error)
                ex.fulfill()
            }
            let task = Realm.asyncOpen(configuration: config) { _, _ in
                XCTFail("Cancelled completion handler was called")
            }
            task.cancel()
            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // FIXME: Dependancy on Stitch deployment
    #if false
    func testAsyncOpenProgress() {
        app().sharedManager().logLevel = .all
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionKey: "realm_id")
                return
            }

            // Wait for the child process to upload everything.
            executeChild()
            let ex1 = expectation(description: "async open")
            let ex2 = expectation(description: "download progress")
            let config = user.configuration(partitionValue: "realm_id")
            let task = Realm.asyncOpen(configuration: config) { _, error in
                XCTAssertNil(error)
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
        let syncTimeoutOptions = SyncTimeoutOptions()
        syncTimeoutOptions.connectTimeout = 3000
        app().sharedManager().timeoutOptions = syncTimeoutOptions

        // The server proxy adds a 2 second delay, so a 3 second timeout should succeed
        autoreleasepool {
            do {
                let user = try synchronouslyLogInUser(for: basicCredentials())
                let config = user.configuration(partitionValue: "realm_id")
                let ex = expectation(description: "async open")
                Realm.asyncOpen(configuration: config) { _, error in
                    XCTAssertNil(error)
                    ex.fulfill()
                }
                waitForExpectations(timeout: 10.0, handler: nil)
                try synchronouslyLogOutUser(user)
            } catch {
                XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            }
        }

        self.resetSyncManager()
        self.setupSyncManager()

        // and a 1 second timeout should fail
        autoreleasepool {
            do {
                let user = try synchronouslyLogInUser(for: basicCredentials())
                let config = user.configuration(partitionValue: "realm_id")

                syncTimeoutOptions.connectTimeout = 1000
                app().sharedManager().timeoutOptions = syncTimeoutOptions

                let ex = expectation(description: "async open")
                Realm.asyncOpen(configuration: config) { _, error in
                    XCTAssertNotNil(error)
                    if let error = error as NSError? {
                        XCTAssertEqual(error.code, Int(ETIMEDOUT))
                        XCTAssertEqual(error.domain, NSPOSIXErrorDomain)
                    }
                    ex.fulfill()
                }
                waitForExpectations(timeout: 4.0, handler: nil)
                try synchronouslyLogOutUser(user)
            } catch {
                XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            }
        }
    }
    #endif

    // MARK: - App Credentials

    func testUsernamePasswordCredential() {
        let usernamePasswordCredential = AppCredentials(username: "username", password: "password")
        XCTAssertEqual(usernamePasswordCredential.provider.rawValue, "local-userpass")
    }

    func testJWTCredentials() {
        let jwtCredential = AppCredentials(jwt: "token")
        XCTAssertEqual(jwtCredential.provider.rawValue, "custom-token")
    }

    func testAnonymousCredentials() {
        let anonymousCredential = AppCredentials.anonymous()
        XCTAssertEqual(anonymousCredential.provider.rawValue, "anon-user")
    }

    func testUserAPIKeyCredentials() {
        let userAPIKeyCredential = AppCredentials(userAPIKey: "apikey")
        XCTAssertEqual(userAPIKeyCredential.provider.rawValue, "api-key")
    }

    func testServerAPIKeyCredentials() {
        let serverAPIKeyCredential = AppCredentials(serverAPIKey: "apikey")
        XCTAssertEqual(serverAPIKeyCredential.provider.rawValue, "api-key")
    }

    func testFacebookCredentials() {
        let facebookCredential = AppCredentials(facebookToken: "token")
        XCTAssertEqual(facebookCredential.provider.rawValue, "oauth2-facebook")
    }

    func testGoogleCredentials() {
        let googleCredential = AppCredentials(googleToken: "token")
        XCTAssertEqual(googleCredential.provider.rawValue, "oauth2-google")
    }

    func testAppleCredentials() {
        let appleCredential = AppCredentials(appleToken: "token")
        XCTAssertEqual(appleCredential.provider.rawValue, "oauth2-apple")
    }

    func testFunctionCredentials() {
        var error: NSError!
        let functionCredential = AppCredentials.init(functionPayload: ["dog": ["name": "fido"]], error: &error)
        XCTAssertEqual(functionCredential.provider.rawValue, "custom-function")
    }

    // MARK: - Authentication

    func testInvalidCredentials() {
        do {
            let username = "testInvalidCredentialsUsername"
            let credentials = basicCredentials()
            let user = try synchronouslyLogInUser(for: credentials)
            XCTAssertEqual(user.state, .loggedIn)

            let credentials2 = AppCredentials(username: username, password: "NOT_A_VALID_PASSWORD")
            let ex = expectation(description: "Should log in the user properly")

            self.app.login(withCredential: credentials2, completion: { user2, error in
                XCTAssertNil(user2)
                XCTAssertNotNil(error)
                ex.fulfill()
            })

            waitForExpectations(timeout: 10, handler: nil)

        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - User-specific functionality

    func testUserExpirationCallback() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())

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
            _ = try immediatelyOpenRealm(partitionValue: "realm_id", user: user)

            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    private func realmURLForFile(_ fileName: String) -> URL {
        let testDir = RLMRealmPathForFile("realm-object-server")
        let directory = URL(fileURLWithPath: testDir, isDirectory: true)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - RealmApp tests

    let appName = "translate-utwuv"

    private func realmAppConfig() -> AppConfiguration {

        return AppConfiguration(baseURL: "http://localhost:9090",
                                transport: nil,
                                localAppName: "auth-integration-tests",
                                localAppVersion: "20180301")
    }

    func testRealmAppInit() {
        let appWithNoConfig = RealmApp(id: appName)
        XCTAssertEqual(appWithNoConfig.allUsers().count, 0)

        let appWithConfig = RealmApp(id: appName, configuration: realmAppConfig())
        XCTAssertEqual(appWithConfig.allUsers().count, 0)
    }

    func testRealmAppLogin() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: SyncUser?

        app.login(withCredential: AppCredentials(username: email, password: password)) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.identity, app.currentUser()?.identity)
        XCTAssertEqual(app.allUsers().count, 1)
    }

    func testRealmAppSwitchAndRemove() {

        let email1 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password1 = randomString(10)
        let email2 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password2 = randomString(10)

        let registerUser1Ex = expectation(description: "Register user 1")
        let registerUser2Ex = expectation(description: "Register user 2")

        app.usernamePasswordProviderClient().registerEmail(email1, password: password1) { (error) in
            XCTAssertNil(error)
            registerUser1Ex.fulfill()
        }

        app.usernamePasswordProviderClient().registerEmail(email2, password: password2) { (error) in
            XCTAssertNil(error)
            registerUser2Ex.fulfill()
        }

        wait(for: [registerUser1Ex, registerUser2Ex], timeout: 4.0)

        let login1Ex = expectation(description: "Login user 1")
        let login2Ex = expectation(description: "Login user 2")

        var syncUser1: SyncUser?
        var syncUser2: SyncUser?

        app.login(withCredential: AppCredentials(username: email1, password: password1)) { (user, error) in
            XCTAssertNil(error)
            syncUser1 = user
            login1Ex.fulfill()
        }

        wait(for: [login1Ex], timeout: 4.0)

        app.login(withCredential: AppCredentials(username: email2, password: password2)) { (user, error) in
            XCTAssertNil(error)
            syncUser2 = user
            login2Ex.fulfill()
        }

        wait(for: [login2Ex], timeout: 4.0)

        XCTAssertEqual(app.allUsers().count, 2)

        XCTAssertEqual(syncUser2!.identity, app.currentUser()!.identity)

        app.switch(to: syncUser1!)
        XCTAssertTrue(syncUser1!.identity == app.currentUser()?.identity)

        let removeEx = expectation(description: "Remove user 1")

        app.remove(syncUser1!) { (error) in
            XCTAssertNil(error)
            removeEx.fulfill()
        }

        wait(for: [removeEx], timeout: 4.0)

        XCTAssertEqual(syncUser2!.identity, app.currentUser()!.identity)
        XCTAssertEqual(app.allUsers().count, 1)
    }

    func testRealmAppLinkUser() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: SyncUser?

        let credentials = AppCredentials(username: email, password: password)

        app.login(withCredential: AppCredentials.anonymous()) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        let linkEx = expectation(description: "Link user")

        app.linkUser(syncUser!, credentials: credentials) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            linkEx.fulfill()
        }

        wait(for: [linkEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.identity, app.currentUser()?.identity)
        XCTAssertEqual(syncUser?.identities().count, 2)
    }

    // MARK: - Provider Clients

    func testUsernamePasswordProviderClient() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let confirmUserEx = expectation(description: "Confirm user")

        app.usernamePasswordProviderClient().confirmUser("atoken", tokenId: "atokenid") { (error) in
            XCTAssertNotNil(error)
            confirmUserEx.fulfill()
        }
        wait(for: [confirmUserEx], timeout: 4.0)

        let resendEmailEx = expectation(description: "Resend email confirmation")

        app.usernamePasswordProviderClient().resendConfirmationEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendEmailEx.fulfill()
        }
        wait(for: [resendEmailEx], timeout: 4.0)

        let resendResetPasswordEx = expectation(description: "Resend reset password email")

        app.usernamePasswordProviderClient().sendResetPasswordEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendResetPasswordEx.fulfill()
        }
        wait(for: [resendResetPasswordEx], timeout: 4.0)

        let resetPasswordEx = expectation(description: "Reset password email")

        app.usernamePasswordProviderClient().resetPassword(to: "password", token: "atoken", tokenId: "tokenId") { (error) in
            XCTAssertNotNil(error)
            resetPasswordEx.fulfill()
        }
        wait(for: [resetPasswordEx], timeout: 4.0)

        let callResetFunctionEx = expectation(description: "Reset password function")
        app.usernamePasswordProviderClient().callResetPasswordFunction(email: email,
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

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = AppCredentials(username: email, password: password)

        app.login(withCredential: credentials) { (_, error) in
            XCTAssertNil(error)
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        let createAPIKeyEx = expectation(description: "Create user api key")

        var apiKey: UserAPIKey?
        app.userAPIKeyProviderClient().createApiKey(withName: "my-api-key") { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            apiKey = key
            createAPIKeyEx.fulfill()
        }
        wait(for: [createAPIKeyEx], timeout: 4.0)

        let fetchAPIKeyEx = expectation(description: "Fetch user api key")
        app.userAPIKeyProviderClient().fetchApiKey(apiKey!.objectId) { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            fetchAPIKeyEx.fulfill()
        }
        wait(for: [fetchAPIKeyEx], timeout: 4.0)

        let fetchAPIKeysEx = expectation(description: "Fetch user api keys")
        app.userAPIKeyProviderClient().fetchApiKeys(completion: { (keys, error) in
            XCTAssertNotNil(keys)
            XCTAssertEqual(keys!.count, 1)
            XCTAssertNil(error)
            fetchAPIKeysEx.fulfill()
        })
        wait(for: [fetchAPIKeysEx], timeout: 4.0)

        let disableKeyEx = expectation(description: "Disable API key")
        app.userAPIKeyProviderClient().disableApiKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            disableKeyEx.fulfill()
        }
        wait(for: [disableKeyEx], timeout: 4.0)

        let enableKeyEx = expectation(description: "Enable API key")
        app.userAPIKeyProviderClient().enableApiKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            enableKeyEx.fulfill()
        }
        wait(for: [enableKeyEx], timeout: 4.0)

        let deleteKeyEx = expectation(description: "Delete API key")
        app.userAPIKeyProviderClient().deleteApiKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            deleteKeyEx.fulfill()
        }
        wait(for: [deleteKeyEx], timeout: 4.0)
    }

    func testCallFunction() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")

        let credentials = AppCredentials(username: email, password: password)
        app.login(withCredential: credentials) { (_, error) in
            XCTAssertNil(error)
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let callFunctionEx = expectation(description: "Call function")
        app.functions.sum([1, 2, 3, 4, 5]) { bson, error in
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

    func testCustomUserData() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.usernamePasswordProviderClient().registerEmail(email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = AppCredentials(username: email, password: password)
        app.login(withCredential: credentials) { (_, error) in
            XCTAssertNil(error)
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let userDataEx = expectation(description: "Update user data")
        app.functions.updateUserData([["favourite_colour": "green", "apples": 10]]) { _, error  in
            XCTAssertNil(error)
            userDataEx.fulfill()
        }
        wait(for: [userDataEx], timeout: 4.0)

        let refreshDataEx = expectation(description: "Refresh user data")
        app.currentUser()?.refreshCustomData { error in
            XCTAssertNil(error)
            refreshDataEx.fulfill()
        }
        wait(for: [refreshDataEx], timeout: 4.0)

        XCTAssertEqual(app.currentUser()?.customData?["favourite_colour"], .string("green"))
        XCTAssertEqual(app.currentUser()?.customData?["apples"], .int64(10))
    }

    // MARK: - Mongo Client

    func testMongoClient() {
        let mongoClient = app.mongoClient("mongodb1")
        XCTAssertEqual(mongoClient.name, "mongodb1")
        let database = mongoClient.database(withName: "test_data")
        XCTAssertEqual(database.name, "test_data")
        let collection = database.collection(withName: "Dog")
        XCTAssertEqual(collection.name, "Dog")
    }

    func removeAllFromCollection(_ collection: MongoCollection) {
        let deleteEx = expectation(description: "Delete all from Mongo collection")
        collection.deleteManyDocuments(filter: [:]) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            deleteEx.fulfill()
        }
        wait(for: [deleteEx], timeout: 4.0)
    }

    func setupMongoCollection() -> MongoCollection {
        _ = try? synchronouslyLogInUser(for: basicCredentials())
        let mongoClient = app.mongoClient("mongodb1")
        let database = mongoClient.database(withName: "test_data")
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

    func testMongoInsert() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]

        let insertOneEx1 = expectation(description: "Insert one document")
        collection.insertOne(document) { (objectId, error) in
            XCTAssertNotNil(objectId)
            XCTAssertNil(error)
            insertOneEx1.fulfill()
        }
        wait(for: [insertOneEx1], timeout: 4.0)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 3)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            XCTAssertEqual(result![1]["name"] as! String, "fido")
            XCTAssertEqual(result![2]["name"] as! String, "rex")
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)
    }

    func testMongoFind() {
        let collection = setupMongoCollection()

        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]
        let document3: Document = ["name": "rex", "breed": "tibetan mastiff", "coat": ["fawn", "brown", "white"]]
        let findOptions = FindOptions(1, nil, nil)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 3)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 3)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            XCTAssertEqual(result![1]["name"] as! String, "rex")
            XCTAssertEqual(result![2]["name"] as! String, "rex")
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)

        let findEx2 = expectation(description: "Find documents")
        collection.find(filter: [:], options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 1)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            findEx2.fulfill()
        }
        wait(for: [findEx2], timeout: 4.0)

        let findEx3 = expectation(description: "Find documents")
        collection.find(filter: document3, options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 1)
            findEx3.fulfill()
        }
        wait(for: [findEx3], timeout: 4.0)

        let findOneEx1 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            findOneEx1.fulfill()
        }
        wait(for: [findOneEx1], timeout: 4.0)

        let findOneEx2 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document, options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            findOneEx2.fulfill()
        }
        wait(for: [findOneEx2], timeout: 4.0)
    }

    func testMongoFindAndReplace() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneReplaceEx1 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2) { (result, error) in
            // no doc found, both should be nil
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneReplaceEx1.fulfill()
        }
        wait(for: [findOneReplaceEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneReplaceEx2 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document2, replacement: document3, options: options1) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "john")
            findOneReplaceEx2.fulfill()
        }
        wait(for: [findOneReplaceEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, false)
        let findOneReplaceEx3 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2, options: options2) { (result, error) in
            // upsert but do not return document
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneReplaceEx3.fulfill()
        }
        wait(for: [findOneReplaceEx3], timeout: 4.0)
    }

    func testMongoFindAndUpdate() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneUpdateEx1 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2) { (result, error) in
            // no doc found, both should be nil
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneUpdateEx1.fulfill()
        }
        wait(for: [findOneUpdateEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx2 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document2, update: document3, options: options1) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "john")
            findOneUpdateEx2.fulfill()
        }
        wait(for: [findOneUpdateEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx3 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2, options: options2) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "rex")
            findOneUpdateEx3.fulfill()
        }
        wait(for: [findOneUpdateEx3], timeout: 4.0)
    }

    func testMongoFindAndDelete() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 1)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let findOneDeleteEx1 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document) { (document, error) in
            // Document does not exist, but should not return an error because of that
            XCTAssertNotNil(document)
            XCTAssertNil(error)
            findOneDeleteEx1.fulfill()
        }
        wait(for: [findOneDeleteEx1], timeout: 4.0)

        // FIXME: It seems there is a possible server bug that does not handle
        // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
        // "expected pre-image to match projection matcher"
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
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 0)
            findEx.fulfill()
        }
        wait(for: [findEx], timeout: 4.0)
    }

    func testMongoUpdateOne() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 4)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document, update: document2) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 1)
            XCTAssertEqual(updateResult?.modifiedCount, 1)
            XCTAssertNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document5, update: document2, upsert: true) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 0)
            XCTAssertEqual(updateResult?.modifiedCount, 0)
            XCTAssertNotNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoUpdateMany() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 4)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document, update: document2) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 1)
            XCTAssertEqual(updateResult?.modifiedCount, 1)
            XCTAssertNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document5, update: document2, upsert: true) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 0)
            XCTAssertEqual(updateResult?.modifiedCount, 0)
            XCTAssertNotNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoDeleteOne() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteOneDocument(filter: document) { (count, error) in
            XCTAssertEqual(count, 0)
            XCTAssertNil(error)
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteOneDocument(filter: document) { (count, error) in
            XCTAssertEqual(count, 1)
            XCTAssertNil(error)
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoDeleteMany() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteManyDocuments(filter: document) { (count, error) in
            XCTAssertEqual(count, 0)
            XCTAssertNil(error)
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteManyDocuments(filter: ["breed": "cane corso"]) { (count, error) in
            XCTAssertEqual(count, 2)
            XCTAssertNil(error)
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoCountAndAggregate() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 1)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        collection.aggregate(pipeline: [["$match": ["name": "fido"]], ["$group": ["_id": "$name"]]]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
        }

        let countEx1 = expectation(description: "Count documents")
        collection.count(filter: document) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            countEx1.fulfill()
        }
        wait(for: [countEx1], timeout: 4.0)

        let countEx2 = expectation(description: "Count documents")
        collection.count(filter: document, limit: 1) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            XCTAssertEqual(count, 1)
            countEx2.fulfill()
        }
        wait(for: [countEx2], timeout: 4.0)
    }
}
