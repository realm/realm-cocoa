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
                var request = URLRequest(url: url)
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

/// Bog standard subprocess abstraction for shell commands.
private struct Subprocess {
    var path = ["/bin/", "/usr/bin/"]
    private var _environment = [String: String]()
    var environment: [String: String] {
        get {
            ["PATH": path.joined(separator: ":")].merging(_environment, uniquingKeysWith: { key1, _ in key1 })
        } set {
            _environment = newValue
        }
    }

    private let defaultDirectoryPath: String?

    init(defaultDirectoryPath: String? = nil) {
        self.defaultDirectoryPath = defaultDirectoryPath
    }

    @discardableResult
    func popen(_ commandString: String,
               currentDirectoryPath: String? = nil) -> (exitCode: Int32, output: String) {
        func createProcesses(_ commandString: String,
                             process: inout Process,
                             processes: inout [Process]) {
            if let currentDirectoryPath = currentDirectoryPath {
                process.currentDirectoryPath = currentDirectoryPath
            } else if let defaultDirectoryPath = self.defaultDirectoryPath {
                process.currentDirectoryPath = defaultDirectoryPath
            }
            processes.append(process)
            var commandAndFlags = commandString.split(separator: " ")
            process.launchPath = String(commandAndFlags.first!)
            commandAndFlags.removeFirst()
            var args = [String]()
            while commandAndFlags.count > 0 {
                var argument = commandAndFlags.removeFirst()
                switch argument.first! {
                case "|":
                    let pipe = Pipe()
                    let outputPipe = Pipe()
                    var tailProcess = Process()
                    createProcesses(commandAndFlags.joined(separator: " "),
                                    process: &tailProcess,
                                    processes: &processes)
                    tailProcess.standardInput = pipe
                    tailProcess.standardOutput = outputPipe
                    process.standardOutput = pipe
                    process.arguments = args
                    return
                case "\"", "'":
                    // the argument is guarded by quotes, so we have to rejoin
                    // the proceeding arguments to retain the intent of the caller
                    if argument.last != argument.first! {
                        var nextArg = commandAndFlags.removeFirst()
                        while nextArg.last != argument.first {
                            argument += " " + nextArg
                            nextArg = commandAndFlags.removeFirst()
                        }
                        // concat the final part of the quoted arg
                        argument += " " + nextArg
                    }
                    fallthrough
                default:
                    args.append(String(argument))
                }
            }
            process.arguments = args
        }
        var processes = [Process]()
        var process = Process()
        process.environment = environment
        createProcesses(commandString, process: &process, processes: &processes)

        processes.forEach { process in
            process.launch()
        }
        processes.forEach {
            $0.waitUntilExit()
        }
        let data = (processes.last!.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        return (processes.last!.terminationStatus, String(data: data,
                                                          encoding: .utf8)!)
    }
}
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

    private struct Dependencies: Decodable {
        enum CodingKeys: String, CodingKey {
            case mongoDBVersion = "MONGODB_VERSION",
                 goVersion = "GO_VERSION",
                 nodeVersion = "NODE_VERSION",
                 stitchVersion = "STITCH_VERSION"
        }
        var mongoDBVersion: String
        var goVersion: String
        var nodeVersion: String
        var stitchVersion: String
    }

    /// Shared RealmServer. This class only needs to be initialized and torn down once per test suite run.
    @objc public static var shared = RealmServer()
    private lazy var dependencies: Dependencies = {
        guard let data = fileManager.contents(atPath: RealmServer.rootUrl.appendingPathComponent("dependencies.list").path),
              let dependenciesString = String(data: data, encoding: .utf8) else {
            fatalError("`dependencies.list` missing from root directory")
        }

        do {
            let dependenciesMap = dependenciesString.components(separatedBy: "\n").dropLast().reduce(into: [String: String]()) {
                let keyValuePair = $1.split(separator: "=")
                $0[String(keyValuePair[0])] = String(keyValuePair[1])
            }
            let dependenciesJSON = try JSONEncoder().encode(dependenciesMap)
            return try JSONDecoder().decode(Dependencies.self,
                                            from: dependenciesJSON)
        } catch {
            fatalError("`dependencies.list` malformed: \(error.localizedDescription)")
        }
    }()

    /// The root URL of the project.
    private static let rootUrl = URL(fileURLWithPath: #file)
        .deletingLastPathComponent() // RealmServer.swift
        .deletingLastPathComponent() // ObjectServerTests
        .deletingLastPathComponent() // Realm
    /// The build directory where the server source and binaries are stored.
    private lazy var buildDir = RealmServer.rootUrl.appendingPathComponent("build")
    /// The binary directory where the server binaries are stored.
    private lazy var binDir = buildDir.appendingPathComponent("bin")
    /// The directory where mongo stores its files. This is a unique value so that
    /// we have a fresh mongo each run.
    private var tempDir = URL(fileURLWithPath: NSTemporaryDirectory(),
                              isDirectory: true).appendingPathComponent("realm-test-\(UUID().uuidString)")
    private lazy var mongoDBURL = URL(string: "https://fastdl.mongodb.org/osx/mongodb-macos-x86_64-\(dependencies.mongoDBVersion).tgz")!
    private lazy var transpilerTarget = "node10-macos"
    private lazy var stitchSupportLibURL = "https://s3.amazonaws.com/stitch-artifacts/stitch-support/stitch-support-macos-debug-4.3.2-721-ge791a2e-patch-5e2a6ad2a4cf473ae2e67b09.tgz"
    private lazy var mongoDir = buildDir.appendingPathComponent("mongodb-macos-x86_64-\(dependencies.mongoDBVersion)")
    private lazy var mongoExe = binDir.appendingPathComponent("mongo")
    private lazy var mongodExe = binDir.appendingPathComponent("mongod")
    private lazy var libDir = buildDir.appendingPathComponent("lib")

    let fileManager = FileManager.default
    /// Log level for the server and mongo processes.
    public var logLevel = LogLevel.none

    /// Process that runs the local mongo server. Should be terminated on exit.
    private let mongoProcess = Process()
    /// Process that runs the local backend server. Should be terminated on exit.
    private let serverProcess = Process()

    /// Whether or not this is a parent or child process.
    private lazy var isParentProcess = (getenv("RLMProcessIsChild") == nil)

    /// The "shell" that processes are launched on
    private lazy var subprocess = Subprocess(defaultDirectoryPath: buildDir.path)

    /// The current admin session
    private var session: Admin.AdminSession?

    /// Check if the current git user is authorised to use BaaS
    @objc public class func haveServer() -> Bool {
        let stitchDir = rootUrl
                     .appendingPathComponent("build")
                     .appendingPathComponent("stitch")
         return FileManager.default.fileExists(atPath: stitchDir.path) ||
            Subprocess().popen("/usr/bin/git ls-remote --exit-code --quiet git@github.com:10gen/baas").exitCode == 0
    }

    private override init() {
        super.init()

        if isParentProcess {
            atexit {
                _ = RealmServer.shared.tearDown
            }

            do {
                try buildServer()
                try launchMongoProcess()
                try launchServerProcess()
                self.session = try Admin().login()
            } catch {
                XCTFail("Could not initiate admin session: \(error.localizedDescription)")
            }
        }
    }

    private func setupMongod() throws {
        if !fileManager.fileExists(atPath: binDir.appendingPathComponent("mongo").path) {
            subprocess.popen("/usr/bin/curl --silent \(mongoDBURL) | /usr/bin/tar xz")
            subprocess.popen("/bin/mkdir \(binDir.path)")
            subprocess.popen("/bin/cp \(mongoDir.appendingPathComponent("/bin/mongo").path) \(binDir.appendingPathComponent("mongo").path)")
            subprocess.popen("/bin/cp \(mongoDir.appendingPathComponent("/bin/mongod").path) \(binDir.appendingPathComponent("mongod").path)")

            let mongoProcess = Process()
            mongoProcess.launchPath = binDir.appendingPathComponent("mongod").path
            mongoProcess.arguments = [
                "--quiet",
                "--dbpath", tempDir.path,
                "--bind_ip", "localhost",
                "--port", "26000",
                "--replSet", "test",
                "--fork",
                "--logpath", "\(buildDir.appendingPathComponent("mongod.log"))"
            ]
            mongoProcess.standardOutput = nil
            try mongoProcess.run()

            subprocess.popen("\(binDir.appendingPathComponent("mongo").path) --port=26000 --eval=\"rs.initiate()\"")
            subprocess.popen("""
                        \(binDir.appendingPathComponent("mongo").path) --port 26000 --eval 'use admin; db.createUser({user: "test", pwd: "test", roles: [{role: "userAdminAnyDatabase", db: "admin"}]})'
                        """)

            let shutdownProcess = mongoShutdownProcess()
            shutdownProcess.launch()
            shutdownProcess.waitUntilExit()
            mongoProcess.terminate()
        }
    }

    private func setupStitch() throws {
        print("Setting up stitch")

        let goRoot = buildDir.appendingPathComponent("go")
        var stitchDir = buildDir.appendingPathComponent("stitch")
        let updateDocFilepath = binDir.appendingPathComponent("update_doc")
        let assistedAggFilepath = binDir.appendingPathComponent("assisted_agg")

        if fileManager.fileExists(atPath: "\(goRoot.path)/bin/go")
            && fileManager.fileExists(atPath: stitchDir.path)
            && fileManager.fileExists(atPath: libDir.appendingPathComponent("libstitch_support.dylib").path)
            && fileManager.fileExists(atPath: updateDocFilepath.path)
            && fileManager.fileExists(atPath: assistedAggFilepath.path)
            && fileManager.fileExists(atPath: buildDir
                                        .appendingPathComponent("node-v\(dependencies.nodeVersion)-darwin-x64").path)
            && fileManager.fileExists(atPath: binDir.appendingPathComponent("transpiler").path)
            && fileManager.fileExists(atPath: binDir.appendingPathComponent("create_user").path)
            && fileManager.fileExists(atPath: binDir.appendingPathComponent("stitch_server").path) {
            return
        }

        try fileManager.createDirectory(at: libDir, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: goRoot.appendingPathComponent("bin/go").path) {
            print("Downloading golang")
            subprocess.popen("/usr/bin/curl --silent https://dl.google.com/go/go\(dependencies.goVersion).darwin-amd64.tar.gz | /usr/bin/tar xz")
            subprocess.popen("/bin/mkdir -p \(goRoot.appendingPathComponent("src/github.com/10gen").path)")
        }



        if !fileManager.fileExists(atPath: stitchDir.path) {
            print("Cloning stitch")
            subprocess.popen("/usr/bin/git clone git@github.com:10gen/baas \(stitchDir.path)")
        }

        print("checking out stitch")
        let stitchWorktree = goRoot
            .appendingPathComponent("src")
            .appendingPathComponent("github.com")
            .appendingPathComponent("10gen")
            .appendingPathComponent("stitch")
        if FileManager.default.fileExists(atPath: stitchDir.appendingPathComponent(".git").path) {
            // Fetch the BaaS version if we don't have it
            if subprocess.popen("/usr/bin/git -C \(stitchDir.path) show-ref --verify --quiet \(dependencies.stitchVersion)").exitCode != 0 {
                subprocess.popen("/usr/bin/git -C \(stitchDir.path) fetch")
            }

            // Set the worktree to the correct version
            if fileManager.fileExists(atPath: stitchWorktree.path) {
                subprocess.popen("/usr/bin/git -C \(stitchWorktree.path) checkout \(dependencies.stitchVersion)")
            } else {
                subprocess.popen("/usr/bin/git -C \(stitchDir.path) worktree add \(stitchWorktree.path) \(dependencies.stitchVersion)")
            }
        } else {
            print("Stitch exists without .git directory– copying files from \(stitchDir) to \(stitchWorktree)")
            // We have a stitch directory with no .git directory, meaning we're
            // running on CI and just need to copy the files into place
            if !fileManager.fileExists(atPath: stitchWorktree.path) {
                subprocess.popen("/bin/cp -Rc \(stitchDir.path) \(stitchWorktree.path)")
            }
        }

        subprocess.popen("/bin/mkdir -p \(goRoot.appendingPathComponent("src/github.com/10gen/stitch/etc/dylib").path)")
        stitchDir = stitchWorktree
        if !fileManager.fileExists(atPath: libDir.appendingPathComponent("libstitch_support.dylib").path) {
            print("downloading mongodb dylibs")
            subprocess.popen("/usr/bin/curl -s \(stitchSupportLibURL) | /usr/bin/tar xvfz - --strip-components=1 -C \(goRoot.appendingPathComponent("src/github.com/10gen/stitch/etc/dylib").path)")
            subprocess.popen("/bin/cp \(goRoot.appendingPathComponent("src/github.com/10gen/stitch/etc/dylib/lib/libstitch_support.dylib").path) lib")
        }

        if !fileManager.fileExists(atPath: updateDocFilepath.path) {
            print("downloading update_doc")
            subprocess.popen("/usr/bin/curl --silent -O https://s3.amazonaws.com/stitch-artifacts/stitch-mongo-libs/stitch_mongo_libs_osx_patch_cbcbfd8ebefcca439ff2e4d99b022aedb0d61041_59e2b7a5c9ec4432c400181c_17_10_15_01_19_33/update_doc")
            subprocess.popen("/bin/mv update_doc bin/update_doc")
            subprocess.popen("/bin/chmod +x \(updateDocFilepath.path)")
        }

        if !fileManager.fileExists(atPath: assistedAggFilepath.path) {
            print("downloading assisted_agg")
            subprocess.popen("/usr/bin/curl --silent -O https://s3.amazonaws.com/stitch-artifacts/stitch-mongo-libs/stitch_mongo_libs_osx_patch_b1c679a26ecb975372de41238ea44e4719b8fbf0_5f3d91c10ae6066889184912_20_08_19_20_57_17/assisted_agg")
            subprocess.popen("/bin/mv assisted_agg bin/assisted_agg")
            subprocess.popen("/bin/chmod +x \(assistedAggFilepath.path)")
        }

        if !fileManager.fileExists(atPath: buildDir.appendingPathComponent("node-v\(dependencies.nodeVersion)-darwin-x64").path) {
            print("downloading node 🚀")
            subprocess.popen("/usr/bin/curl --silent https://nodejs.org/dist/v\(dependencies.nodeVersion)/node-v\(dependencies.nodeVersion)-darwin-x64.tar.gz | /usr/bin/tar xz")
        }
        subprocess.path.append("\(buildDir.appendingPathComponent("node-v\(dependencies.nodeVersion)-darwin-x64/bin/").path)")

        if !fileManager.fileExists(atPath: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".yarn/bin/yarn").path) {
            subprocess.popen("/bin/rm -rf ~/.yarn")
            subprocess.popen("/usr/bin/curl -o- -L https://yarnpkg.com/install.sh | /bin/bash")
        }
        subprocess.path.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".yarn/bin:~/.config/yarn/global/node_modules/.bin").path)

        if !fileManager.fileExists(atPath: binDir.appendingPathComponent("transpiler").path) {
            print("building transpiler")
            subprocess.popen("\(fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".yarn/bin/yarn").path) install",
                 currentDirectoryPath: stitchDir.appendingPathComponent("etc").appendingPathComponent("transpiler").path)
            subprocess.popen("\(fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".yarn/bin/yarn").path) run build",
                 currentDirectoryPath: stitchDir.appendingPathComponent("etc").appendingPathComponent("transpiler").path)
            subprocess.popen("/bin/cp -c bin/transpiler \(buildDir.appendingPathComponent("bin").path)", currentDirectoryPath: stitchDir.appendingPathComponent("etc").appendingPathComponent("transpiler").path)
        }

        subprocess.environment["GOROOT"] = goRoot.path
        subprocess.environment["GOCACHE"] = goRoot.appendingPathComponent("cache").path
        subprocess.environment["GOPATH"] = goRoot.appendingPathComponent("bin").path
        subprocess.environment["STITCH_PATH"] = stitchDir.path
        subprocess.environment["LD_LIBRARY_PATH"] = libDir.path
        subprocess.path.append(stitchDir.appendingPathComponent("etc").appendingPathComponent("transpiler").appendingPathComponent("bin").path)

        if !fileManager.fileExists(atPath: binDir.appendingPathComponent("create_user").path) {
            print("build create_user binary")

            subprocess.popen("\(goRoot.appendingPathComponent("bin/go").path) build -modcacherw -o create_user cmd/auth/user.go", currentDirectoryPath: stitchDir.path)
            subprocess.popen("/bin/cp -c create_user \(binDir.path)", currentDirectoryPath: stitchDir.path)

            print("create_user binary built")
        }

        if !fileManager.fileExists(atPath: binDir.appendingPathComponent("stitch_server").path) {
            print("building server binary")

            subprocess.popen("\(goRoot.appendingPathComponent("bin/go").path) build -modcacherw -o stitch_server cmd/server/main.go", currentDirectoryPath: stitchDir.path)
            subprocess.popen("/bin/cp -c stitch_server \(binDir.path)", currentDirectoryPath: stitchDir.path)

            print("server binary built")
        }

        subprocess.popen("/bin/cp stitch/etc/configs/test_config.json ./")
    }

    private func buildServer() throws {
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: buildDir.path) {
            try! FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        }
        try setupMongod()
        try setupStitch()
    }

    fileprivate func mongoShutdownProcess() -> Process {
        let mongo = binDir.appendingPathComponent("mongo").path
        // step down the replica set
        let mongoShutdownProcess = Process()
        mongoShutdownProcess.launchPath = mongo
        mongoShutdownProcess.arguments = [
            "admin",
            "--port", "26000",
            "--eval", "'db.shutdownServer({force: true})'"]
        return mongoShutdownProcess
    }
    /// Lazy teardown for exit only.
    private lazy var tearDown: () = {
        serverProcess.terminate()

        let mongo = binDir.appendingPathComponent("mongo").path

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
        let mongoShutdownProcess = self.mongoShutdownProcess()
        try? mongoShutdownProcess.run()
        mongoShutdownProcess.waitUntilExit()

        mongoProcess.terminate()

        try? FileManager().removeItem(at: tempDir)
    }()

    /// Launch the mongo server in the background.
    /// This process should run until the test suite is complete.
    fileprivate func launchMongoProcess() throws {
        mongoProcess.launchPath = binDir.appendingPathComponent("mongod").path
        mongoProcess.arguments = [
            "--quiet",
            "--dbpath", tempDir.path,
            "--bind_ip", "localhost",
            "--port", "26000",
            "--replSet", "test",
            "--fork",
            "--logpath", buildDir.appendingPathComponent("mongod.log").path
        ]
        mongoProcess.standardOutput = nil
        try mongoProcess.run()

        let initProcess = Process()
        initProcess.launchPath = binDir.appendingPathComponent("mongo").path
        initProcess.arguments = [
            "--port", "26000",
            "--eval", "rs.initiate()"
        ]
        initProcess.standardOutput = nil
        try initProcess.run()
        initProcess.waitUntilExit()
    }

    private func launchServerProcess() throws {
        let binDir = buildDir.appendingPathComponent("bin").path
        let libDir = buildDir.appendingPathComponent("lib").path
        let binPath = "$PATH:\(binDir)"

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
        try! FileManager.default.createDirectory(atPath: tempDir.appendingPathComponent("tmp").path,
            withIntermediateDirectories: false, attributes: nil)
        serverProcess.launchPath = "\(binDir)/stitch_server"
        serverProcess.currentDirectoryPath = tempDir.path
        serverProcess.arguments = [
            "--configFile",
            buildDir.appendingPathComponent("test_config.json").path
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
    @objc public func createApp() throws -> AppId {
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
                        "type": "string",
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

        let dogRule: [String: Any] = [
            "database": "test_data",
            "collection": "Dog",
            "roles": [[
                "name": "default",
                "apply_when": [:],
                "insert": true,
                "delete": true,
                "additional_fields": [:]
            ]],
            "schema": [
                "properties": [
                    "_id": [
                        "bsonType": "objectId"
                    ],
                    "breed": [
                        "bsonType": "string"
                    ],
                    "name": [
                        "bsonType": "string"
                    ],
                    "realm_id": [
                        "bsonType": "string"
                    ]
                ],
                "required": ["name"],
                "title": "Dog"
            ]
        ]

        let personRule: [String: Any] = [
            "database": "test_data",
            "collection": "Person",
            "relationships": [:],
            "roles": [[
                "name": "default",
                "apply_when": [:],
                "write": true,
                "insert": true,
                "delete": true,
                "additional_fields": [:]
            ]],
            "schema": [
                "properties": [
                    "_id": [
                        "bsonType": "objectId"
                    ],
                    "age": [
                        "bsonType": "int"
                    ],
                    "firstName": [
                        "bsonType": "string"
                    ],
                    "lastName": [
                        "bsonType": "string"
                    ],
                    "realm_id": [
                        "bsonType": "string"
                    ]
                ],
                "required": ["firstName",
                             "lastName",
                             "age"],
                "title": "Person"
            ]
        ]

        let hugeSyncObjectRule: [String: Any] = [
            "database": "test_data",
            "collection": "HugeSyncObject",
            "roles": [[
                "name": "default",
                        "apply_when": [:],
                "insert": true,
                "delete": true,
                        "additional_fields": [:]
            ]],
            "schema": [
                "properties": [
                    "_id": [
                        "bsonType": "objectId"
                    ],
                    "dataProp": [
                        "bsonType": "binData"
                    ],
                    "realm_id": [
                        "bsonType": "string"
                    ]
                ],
                "required": [],
                "title": "HugeSyncObject"
            ],
            "relationships": [:]
        ]

        let swiftHugeSyncObjectRule: [String: Any] = [
            "database": "test_data",
            "collection": "SwiftHugeSyncObject",
            "roles": [[
                "name": "default",
                        "apply_when": [:],
                "insert": true,
                "delete": true,
                        "additional_fields": [:]
            ]],
            "schema": [
                "properties": [
                    "_id": [
                        "bsonType": "objectId"
                    ],
                    "data": [
                        "bsonType": "binData"
                    ],
                    "realm_id": [
                        "bsonType": "string"
                    ]
                ],
                "required": ["_id"],
                "title": "SwiftHugeSyncObject"
            ],
            "relationships": [:]
        ]

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

        let swiftPersonRule: [String: Any] = [
            "database": "test_data",
            "collection": "SwiftPerson",
            "roles": [[
                "name": "default",
                "apply_when": [:],
                "insert": true,
                "delete": true,
                "additional_fields": [:]
            ]],
            "schema": [
                "properties": [
                    "_id": [
                        "bsonType": "objectId"
                    ],
                    "age": [
                        "bsonType": "int"
                    ],
                    "firstName": [
                        "bsonType": "string"
                    ],
                    "lastName": [
                        "bsonType": "string"
                    ],
                    "realm_id": [
                        "bsonType": "string"
                    ]
                ],
                "required": [
                             "firstName",
                             "lastName",
                             "age"
                             ],
                "title": "SwiftPerson"
            ],
                "relationships": [:]
        ]

        let rules = app.services[serviceId].rules

        rules.post(on: group, dogRule, failOnError)
        rules.post(on: group, personRule, failOnError)
        rules.post(on: group, hugeSyncObjectRule, failOnError)
        // When running ObjcObjectServerTests,
        // we do not want to pull in swift schema reqs
        #if SWIFT_PACKAGE && REALM_HAVE_COMBINE
        rules.post(on: group, swiftHugeSyncObjectRule, failOnError)
        rules.post(on: group, swiftPersonRule, failOnError)
        #endif

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
}

#endif
