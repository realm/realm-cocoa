////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

import Foundation
import Realm.Private
import RealmSwift
import XCTest

#if os(macOS)

extension URLSession {
    fileprivate func resultDataTask(with request: URLRequest, _ completionHandler: @escaping (Result<Data, Error>) -> Void) {
        URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue()).dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
                let data = data {
                completionHandler(.success(data))
            } else {
                completionHandler(.failure(error ?? URLError(.badServerResponse)))
            }
        }.resume()
    }

    // Synchronously perform a data task, returning the data from it
    fileprivate func resultDataTask(with request: URLRequest) -> Result<Data, Error> {
        var result: Result<Data, Error>!
        let group = DispatchGroup()
        group.enter()
        resultDataTask(with: request) {
            result = $0
            group.leave()
        }
        guard case .success = group.wait(timeout: .now() + 10) else {
            return .failure(URLError(.cannotFindHost))
        }
        return result
    }
}

private func bsonType(_ type: PropertyType) -> String {
    switch type {
    case .UUID: return "uuid"
    case .any: return "mixed"
    case .bool: return "bool"
    case .data: return "binData"
    case .date: return "date"
    case .decimal128: return "decimal"
    case .double: return "double"
    case .float: return "float"
    case .int: return "long"
    case .object: return "object"
    case .objectId: return "objectId"
    case .string: return "string"
    case .linkingObjects: return "linkingObjects"
    }
}

private extension Property {
    func stitchRule(_ schema: Schema) -> [String: Any] {
        let type: String
        if self.type == .object {
            type = bsonType(schema[objectClassName!]!.primaryKeyProperty!.type)
        } else {
            type = bsonType(self.type)
        }

        if isArray {
            return [
                "bsonType": "array",
                "items": [
                    "bsonType": type
                ]
            ]
        }
        if isSet {
            return [
                "bsonType": "array",
                "uniqueItems": true,
                "items": [
                    "bsonType": type
                ]
            ]
        }
        if isMap {
            return [
                "bsonType": "object",
                "properties": [:],
                "additionalProperties": [
                    "bsonType": type
                ]
            ]
        }

        return [
            "bsonType": type
        ]
    }
}

private extension ObjectSchema {
    func stitchRule(_ partitionKeyType: String, _ schema: Schema, id: String? = nil) -> [String: Any] {
        var stitchProperties: [String: Any] = [
            "realm_id": [
                "bsonType": "\(partitionKeyType)"
            ]
        ]
        var relationships: [String: Any] = [:]

        // First pass we only create the primary key property as we can't add
        // links until the targets of the links exist
        if id == nil {
            let pk = primaryKeyProperty!
            stitchProperties[pk.name] = pk.stitchRule(schema)
        } else {
            for property in properties {
                stitchProperties[property.name] = property.stitchRule(schema)

                if property.type == .object {
                    relationships[property.name] = [
                        "ref": "#/relationship/mongodb1/test_data/\(property.objectClassName!)",
                        "foreign_key": "_id",
                        "is_list": property.isArray || property.isSet || property.isMap
                    ]
                }
            }
        }

        return [
            "_id": id as Any,
            "database": "test_data",
            "collection": "\(className)",
            "roles": [[
                "name": "default",
                "apply_when": [:],
                "insert": true,
                "delete": true,
                "additional_fields": [:]
            ]],
            "schema": [
                "properties": stitchProperties,
                // The server currently only supports non-optional collections
                // but requires them to be marked as optional
                "required": properties.compactMap { $0.isOptional || $0.type == .any || $0.isArray || $0.isMap || $0.isSet ? nil : $0.name },
                "title": "\(className)"
            ],
            "relationships": relationships
        ]
    }
}

// MARK: - AdminProfile
struct AdminProfile: Codable {
    struct Role: Codable {
        enum CodingKeys: String, CodingKey {
            case groupId = "group_id"
        }

        let groupId: String
    }

    let roles: [Role]
}

// MARK: - Admin
class Admin {
    // MARK: AdminSession
    /// An authenticated session for using the Admin API
    class AdminSession {
        /// The access token of the authenticated user
        var accessToken: String
        /// The group id associated with the authenticated user
        var groupId: String

        init(accessToken: String, groupId: String) {
            self.accessToken = accessToken
            self.groupId = groupId
        }

        // MARK: AdminEndpoint
        /// Representation of a given admin endpoint.
        /// This allows us to call a give endpoint dynamically with loose typing.
        @dynamicMemberLookup
        struct AdminEndpoint {
            /// The access token of the authenticated user
            var accessToken: String
            /// The group id associated with the authenticated user
            var groupId: String
            /// The endpoint url. This will be appending to dynamically by appending the dynamic member called
            /// as if it were a path.
            var url: URL

            /**
             Append the given member to the path. E.g., if the current URL is set to
            http://localhost:9090/api/admin/v3.0/groups/groupId/apps/appId
             and you currently have a:
             ```
             var app: AdminEndpoint
             ```
             you can fetch a list of all services by calling
             ```
             app.services.get()
             ```
             */
            subscript(dynamicMember member: String) -> AdminEndpoint {
                let pattern = "([a-z0-9])([A-Z])"

                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: member.count)
                let snakeCaseMember = regex?.stringByReplacingMatches(in: member,
                                                                      options: [],
                                                                      range: range,
                                                                      withTemplate: "$1_$2").lowercased()
                return AdminEndpoint(accessToken: accessToken,
                                     groupId: groupId,
                                     url: url.appendingPathComponent(snakeCaseMember!))
            }

            /**
             Append the given id to the path. E.g., if the current URL is set to
             http://localhost:9090/api/admin/v3.0/groups/groupId/apps/
              and you currently have a:
              ```
              var apps: AdminEndpoint
              var appId: String
              ```
              you can fetch the app from its appId with
              ```
              apps[appId].get()
              ```
             */
            subscript(_ id: String) -> AdminEndpoint {
                return AdminEndpoint(accessToken: accessToken,
                                     groupId: groupId,
                                     url: url.appendingPathComponent(id))
            }

            private func request(httpMethod: String, data: Any? = nil,
                                 completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                var components = URLComponents(url: self.url, resolvingAgainstBaseURL: false)!
                components.query = "bypass_service_change=SyncProtocolVersionIncrease"
                var request = URLRequest(url: components.url!)
                request.httpMethod = httpMethod
                request.allHTTPHeaderFields = [
                    "Authorization": "Bearer \(accessToken)",
                    "Content-Type": "application/json;charset=utf-8",
                    "Accept": "application/json"
                ]
                if let data = data {
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: data)
                    } catch {
                        completionHandler(.failure(error))
                    }
                }

                URLSession(configuration: URLSessionConfiguration.default,
                           delegate: nil, delegateQueue: OperationQueue())
                    .resultDataTask(with: request) { result in
                        completionHandler(result.flatMap { data in
                            Result {
                                data.count > 0 ? try JSONSerialization.jsonObject(with: data) : nil
                            }
                        })
                }
            }

            private func request(on group: DispatchGroup, httpMethod: String, data: Any? = nil, _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                group.enter()
                request(httpMethod: httpMethod, data: data) { result in
                    completionHandler(result)
                    group.leave()
                }
            }

            private func request(httpMethod: String, data: Any? = nil) -> Result<Any?, Error> {
                let group = DispatchGroup()
                var result: Result<Any?, Error>!
                group.enter()
                request(httpMethod: httpMethod, data: data) {
                    result = $0
                    group.leave()
                }
                guard case .success = group.wait(timeout: .now() + 5) else {
                    return .failure(URLError(.badServerResponse))
                }
                return result
            }

            func get(_ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(httpMethod: "GET", completionHandler: completionHandler)
            }

            func get(on group: DispatchGroup, _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(on: group, httpMethod: "GET", completionHandler)
            }

            func get() -> Result<Any?, Error> {
                request(httpMethod: "GET")
            }

            func post(_ data: Any, _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(httpMethod: "POST", data: data, completionHandler: completionHandler)
            }

            func post(on group: DispatchGroup, _ data: Any,
                      _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(on: group, httpMethod: "POST", data: data, completionHandler)
            }

            func post(_ data: Any) -> Result<Any?, Error> {
                request(httpMethod: "POST", data: data)
            }

            func put(_ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(httpMethod: "PUT", completionHandler: completionHandler)
            }

            func put(on group: DispatchGroup, data: Any? = nil, _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(on: group, httpMethod: "PUT", data: data, completionHandler)
            }

            func patch(on group: DispatchGroup, _ data: Any, _ completionHandler: @escaping (Result<Any?, Error>) -> Void) {
                request(on: group, httpMethod: "PATCH", data: data, completionHandler)
            }
        }

        /// The initial endpoint to access the admin server
        lazy var apps = AdminEndpoint(accessToken: accessToken,
                                      groupId: groupId,
                                      url: URL(string: "http://localhost:9090/api/admin/v3.0/groups/\(groupId)/apps")!)
    }

    private func userProfile(accessToken: String) -> Result<AdminProfile, Error> {
        var request = URLRequest(url: URL(string: "http://localhost:9090/api/admin/v3.0/auth/profile")!)
        request.allHTTPHeaderFields = [
            "Authorization": "Bearer \(String(describing: accessToken))"
        ]
        return URLSession.shared.resultDataTask(with: request)
            .flatMap { data in
                Result {
                    try JSONDecoder().decode(AdminProfile.self, from: data)
                }
            }
    }

    /// Synchronously authenticate an admin session
    func login() throws -> AdminSession {
        let authUrl = URL(string: "http://localhost:9090/api/admin/v3.0/auth/providers/local-userpass/login")!
        var loginRequest = URLRequest(url: authUrl)
        loginRequest.httpMethod = "POST"
        loginRequest.allHTTPHeaderFields = ["Content-Type": "application/json;charset=utf-8",
                                            "Accept": "application/json"]

        loginRequest.httpBody = try! JSONEncoder().encode(["provider": "userpass",
                                                           "username": "unique_user@domain.com",
                                                           "password": "password"])
        return try URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue())
            .resultDataTask(with: loginRequest)
            .flatMap { data in
                return Result {
                    if let accessToken = try JSONDecoder().decode([String: String].self, from: data)["access_token"] {
                        return accessToken
                    }
                    throw URLError(.badServerResponse)
                }
            }
            .flatMap { (accessToken: String) -> Result<AdminSession, Error> in
                self.userProfile(accessToken: accessToken).map {
                    AdminSession(accessToken: accessToken, groupId: $0.roles[0].groupId)
                }
            }
            .get()
    }
}

// MARK: RealmServer

/**
 A sandboxed server. This singleton launches and maintains all server processes
 and allows for app creation.
 */
@available(OSX 10.13, *)
@objc(RealmServer)
public class RealmServer: NSObject {
    public enum LogLevel {
        case none, info, warn, error
    }

    /// Shared RealmServer. This class only needs to be initialized and torn down once per test suite run.
    @objc public static var shared = RealmServer()

    /// Log level for the server and mongo processes.
    public var logLevel = LogLevel.none

    /// Process that runs the local mongo server. Should be terminated on exit.
    private let mongoProcess = Process()
    /// Process that runs the local backend server. Should be terminated on exit.
    private let serverProcess = Process()

    /// The root URL of the project.
    private static let rootUrl = URL(string: #file)!
        .deletingLastPathComponent() // RealmServer.swift
        .deletingLastPathComponent() // ObjectServerTests
        .deletingLastPathComponent() // Realm
    private static let buildDir = rootUrl.appendingPathComponent(".baas")
    private static let binDir = buildDir.appendingPathComponent("bin")

    /// The directory where mongo stores its files. This is a unique value so that
    /// we have a fresh mongo each run.
    private lazy var tempDir = URL(fileURLWithPath: NSTemporaryDirectory(),
                                   isDirectory: true).appendingPathComponent("realm-test-\(UUID().uuidString)")

    /// Whether or not this is a parent or child process.
    private lazy var isParentProcess = (getenv("RLMProcessIsChild") == nil)

    /// The current admin session
    private var session: Admin.AdminSession?

    /// Check if the BaaS files are present and we can run the server
    @objc public class func haveServer() -> Bool {
        let goDir = RealmServer.buildDir.appendingPathComponent("stitch")
        return FileManager.default.fileExists(atPath: goDir.path)
    }

    private override init() {
        super.init()

        if isParentProcess {
            atexit {
                _ = RealmServer.shared.tearDown
            }

            do {
                try launchMongoProcess()
                try launchServerProcess()
                self.session = try Admin().login()
            } catch {
                XCTFail("Could not initiate admin session: \(error.localizedDescription)")
            }
        }
    }

    /// Lazy teardown for exit only.
    private lazy var tearDown: () = {
        serverProcess.terminate()

        let mongo = RealmServer.binDir.appendingPathComponent("mongo").path

        // step down the replica set
        let rsStepDownProcess = Process()
        rsStepDownProcess.launchPath = mongo
        rsStepDownProcess.arguments = [
            "admin",
            "--port", "26000",
            "--eval", "'db.adminCommand({replSetStepDown: 0, secondaryCatchUpPeriodSecs: 0, force: true})'"]
        try? rsStepDownProcess.run()
        rsStepDownProcess.waitUntilExit()

        // step down the replica set
        let mongoShutdownProcess = Process()
        mongoShutdownProcess.launchPath = mongo
        mongoShutdownProcess.arguments = [
            "admin",
            "--port", "26000",
            "--eval", "'db.shutdownServer({force: true})'"]
        try? mongoShutdownProcess.run()
        mongoShutdownProcess.waitUntilExit()

        mongoProcess.terminate()

        try? FileManager().removeItem(at: tempDir)
    }()

    /// Launch the mongo server in the background.
    /// This process should run until the test suite is complete.
    private func launchMongoProcess() throws {
        try! FileManager().createDirectory(at: tempDir,
                                           withIntermediateDirectories: false,
                                           attributes: nil)

        mongoProcess.launchPath = RealmServer.binDir.appendingPathComponent("mongod").path
        mongoProcess.arguments = [
            "--quiet",
            "--dbpath", tempDir.path,
            "--bind_ip", "localhost",
            "--port", "26000",
            "--replSet", "test"
        ]
        mongoProcess.standardOutput = nil
        try mongoProcess.run()

        let initProcess = Process()
        initProcess.launchPath = RealmServer.binDir.appendingPathComponent("mongo").path
        initProcess.arguments = [
            "--port", "26000",
            "--eval", "rs.initiate()"
        ]
        initProcess.standardOutput = nil
        try initProcess.run()
        initProcess.waitUntilExit()
    }

    private func launchServerProcess() throws {
        let binDir = Self.buildDir.appendingPathComponent("bin").path
        let libDir = Self.buildDir.appendingPathComponent("lib").path
        let binPath = "$PATH:\(binDir)"

        let stitchRoot = RealmServer.buildDir.path + "/go/src/github.com/10gen/stitch"

        // create the admin user
        let userProcess = Process()
        userProcess.environment = [
            "PATH": binPath,
            "LD_LIBRARY_PATH": libDir
        ]
        userProcess.launchPath = "\(binDir)/create_user"
        userProcess.arguments = [
            "addUser",
            "-domainID",
            "000000000000000000000000",
            "-mongoURI", "mongodb://localhost:26000",
            "-salt", "DQOWene1723baqD!_@#",
            "-id", "unique_user@domain.com",
            "-password", "password"
        ]
        try userProcess.run()
        userProcess.waitUntilExit()

        serverProcess.environment = [
            "PATH": binPath,
            "LD_LIBRARY_PATH": libDir
        ]
        // golang server needs a tmp directory
        try! FileManager.default.createDirectory(atPath: "\(tempDir.path)/tmp",
            withIntermediateDirectories: false, attributes: nil)
        serverProcess.launchPath = "\(binDir)/stitch_server"
        serverProcess.currentDirectoryPath = tempDir.path
        serverProcess.arguments = [
            "--configFile",
            "\(stitchRoot)/etc/configs/test_config.json"
        ]

        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { file in
            guard file.availableData.count > 0,
                  let available = String(data: file.availableData, encoding: .utf8)?.split(separator: "\t") else {
                return
            }

            // prettify server output
            var parts = [String]()
            for part in available {
                if part.contains("INFO") {
                    guard self.logLevel == .info else {
                        return
                    }
                    parts.append("🔵")
                } else if part.contains("DEBUG") {
                    guard self.logLevel == .info || self.logLevel == .warn else {
                        return
                    }
                    parts.append("🟡")
                } else if part.contains("ERROR") {
                    parts.append("🔴")
                } else if let json = try? JSONSerialization.jsonObject(with: part.data(using: .utf8)!) {
                    parts.append(String(data: try! JSONSerialization.data(withJSONObject: json,
                                                                       options: .prettyPrinted),
                                  encoding: .utf8)!)
                } else if !part.isEmpty {
                    parts.append(String(part))
                }
            }
            print(parts.joined(separator: "\t"))
        }

        if logLevel != .none {
            serverProcess.standardOutput = pipe
        } else {
            serverProcess.standardOutput = nil
        }

        try serverProcess.run()
        waitForServerToStart()
    }

    private func waitForServerToStart() {
        let group = DispatchGroup()
        group.enter()
        func pingServer(_ tries: Int = 0) {
            let session = URLSession(configuration: URLSessionConfiguration.default,
                                     delegate: nil,
                                     delegateQueue: OperationQueue())
            session.dataTask(with: URL(string: "http://localhost:9090")!) { (_, _, error) in
                if error != nil {
                    usleep(50000)
                    pingServer(tries + 1)
                } else {
                    group.leave()
                }
            }.resume()
        }
        pingServer()
        guard case .success = group.wait(timeout: .now() + 10) else {
            return XCTFail("Server did not start")
        }
    }

    public typealias AppId = String

    private func failOnError<T>(_ result: Result<T, Error>) {
        if case .failure(let error) = result {
            XCTFail(error.localizedDescription)
        }
    }

    /// Create a new server app
    @objc public func createAppForBSONType(_ bsonType: String) throws -> AppId {
        guard let session = session else {
            throw URLError(.unknown)
        }

        let info = try session.apps.post(["name": "test"]).get()
        guard let appInfo = info as? [String: Any],
              let clientAppId = appInfo["client_app_id"] as? String,
              let appId = appInfo["_id"] as? String else {
            throw URLError(.badServerResponse)
        }

        let app = session.apps[appId]
        let group = DispatchGroup()

        app.authProviders.post(on: group, ["type": "anon-user"], failOnError)
        app.authProviders.post(on: group, [
            "type": "local-userpass",
            "config": [
                "emailConfirmationUrl": "http://foo.com",
                "resetPasswordUrl": "http://foo.com",
                "confirmEmailSubject": "Hi",
                "resetPasswordSubject": "Bye",
                "autoConfirm": true
            ]
        ], failOnError)

        app.authProviders.get(on: group) { authProviders in
            do {
                guard let authProviders = try authProviders.get() as? [[String: Any]] else {
                    return XCTFail("Bad formatting for authProviders")
                }
                guard let provider = authProviders.first(where: { $0["type"] as? String == "api-key" }) else {
                    return XCTFail("Did not find api-key provider")
                }
                app.authProviders[provider["_id"] as! String].enable.put(on: group, self.failOnError)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        _ = app.secrets.post([
            "name": "BackingDB_uri",
            "value": "mongodb://localhost:26000"
        ])

        let serviceResponse = app.services.post([
            "name": "mongodb1",
            "type": "mongodb",
            "config": [
                "uri": "mongodb://localhost:26000",
                "sync": [
                    "state": "enabled",
                    "database_name": "test_data",
                    "partition": [
                        "key": "realm_id",
                        "type": "\(bsonType)",
                        "required": false,
                        "permissions": [
                            "read": true,
                            "write": true
                        ]
                    ]
                ]
            ]
        ])

        guard let serviceId = (try serviceResponse.get() as? [String: Any])?["_id"] as? String else {
            throw URLError(.badServerResponse)
        }

        let rules = app.services[serviceId].rules

        // Creating the rules is a two-step process where we first add all the
        // rules and then add properties to them so that we can add relationships
        let schema = ObjectiveCSupport.convert(object: RLMSchema.shared())
        let syncTypes = schema.objectSchema.filter {
            guard let pk = $0.primaryKeyProperty else { return false }
            return pk.name == "_id"
        }
        var ruleCreations = [Result<Any?, Error>]()
        for objectSchema in syncTypes {
            ruleCreations.append(rules.post(objectSchema.stitchRule(bsonType, schema)))
        }

        var ruleIds: [String: String] = [:]
        for result in ruleCreations {
            guard case .success(let data) = result else {
                fatalError("Failed to create rule: \(result)")
            }
            let dict = (data as! [String: String])
            ruleIds[dict["collection"]!] = dict["_id"]!
        }
        for objectSchema in syncTypes {
            let id = ruleIds[objectSchema.className]!
            rules[id].put(on: group, data: objectSchema.stitchRule(bsonType, schema, id: id), failOnError)
        }

        app.sync.config.put(on: group, data: [
            "development_mode_enabled": true
        ], failOnError)

        app.functions.post(on: group, [
            "name": "sum",
            "private": false,
            "can_evaluate": [:],
            "source": """
            exports = function(...args) {
                return parseInt(args.reduce((a,b) => a + b, 0));
            };
            """
        ], failOnError)

        app.functions.post(on: group, [
            "name": "updateUserData",
            "private": false,
            "can_evaluate": [:],
            "source": """
            exports = async function(data) {
                const user = context.user;
                const mongodb = context.services.get("mongodb1");
                const userDataCollection = mongodb.db("test_data").collection("UserData");
                await userDataCollection.updateOne(
                                                   { "user_id": user.id },
                                                   { "$set": data },
                                                   { "upsert": true }
                                                   );
                return true;
            };
            """
        ], failOnError)

        let userDataRule: [String: Any] = [
            "database": "test_data",
            "collection": "UserData",
            "roles": [[
                "name": "default",
                "apply_when": [:],
                "insert": true,
                "delete": true,
                "additional_fields": [:]
            ]],
            "schema": [:],
            "relationships": [:]
        ]

        _ = rules.post(userDataRule)
        app.customUserData.patch(on: group, [
            "mongo_service_id": serviceId,
            "enabled": true,
            "database_name": "test_data",
            "collection_name": "UserData",
            "user_id_field": "user_id"
        ], failOnError)

        _ = app.secrets.post([
            "name": "gcm",
            "value": "gcm"
        ])

        app.services.post(on: group, [
            "name": "gcm",
            "type": "gcm",
            "config": [
                "senderId": "gcm"
            ],
            "secret_config": [
                "apiKey": "gcm"
            ],
            "version": 1
        ], failOnError)

        guard case .success = group.wait(timeout: .now() + 5.0) else {
            throw URLError(.badServerResponse)
        }

        return clientAppId
    }

    @objc public func createApp() throws -> AppId {
        try createAppForBSONType("string")
    }
}

#endif
