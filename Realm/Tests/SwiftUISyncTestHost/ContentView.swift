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

import SwiftUI
import RealmSwift
import Combine

enum LoggingViewState {
    case initial
    case logging
    case logged
    case syncing
}

struct LoginView: View {
    @State var viewState: LoggingViewState = .initial
    @ObservedObject var loginHelper = LoginHelper()
    let testType: String = ProcessInfo.processInfo.environment["test_type"]!
    var user: User?

    var body: some View {
        VStack {
            switch viewState {
            case .initial:
                EmptyView()
            case .logging:
                VStack {
                    ProgressView("Logging in...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue)
                .transition(AnyTransition.move(edge: .leading)).animation(.default)
            case .logged:
                VStack {
                    Text("Logged in")
                        .accessibilityIdentifier("logged-view")
                    Button("Sync") {
                        viewState = .syncing
                    }
                    .accessibilityIdentifier("sync-button-view")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.yellow)
                .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            case .syncing:
                switch testType {
                case "async_open":
                    AsyncOpenView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                case "async_open_environment_partition_value":
                    AsyncOpenPartitionView()
                        .environment(\.partitionValue, ProcessInfo.processInfo.environment["function_name"]!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                case "async_open_environment_configuration":
                    AsyncOpenPartitionView()
                        .environment(\.realmConfiguration, loginHelper.user!.configuration(partitionValue: ProcessInfo.processInfo.environment["function_name"]!))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                case "auto_open":
                    AutoOpenView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                case "auto_open_environment_partition_value":
                    AutoOpenPartitionView()
                        .environment(\.partitionValue, ProcessInfo.processInfo.environment["function_name"]!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                case "auto_open_environment_configuration":
                    AutoOpenPartitionView()
                        .environment(\.realmConfiguration, loginHelper.user!.configuration(partitionValue: ProcessInfo.processInfo.environment["function_name"]!))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                default:
                    EmptyView()
                }
            }
        }
        .onAppear(perform: {
            viewState = .logging
            loginHelper.login(email: ProcessInfo.processInfo.environment["function_name"]!,
                              password: "password",
                              completion: { user in
                viewState = .logged
            })
        })
    }
}

class LoginHelper: ObservableObject {
    @Published var user: User?
    var cancellables = Set<AnyCancellable>()

    func login(email: String, password: String, completion: @escaping (User) -> Void) {
        let appConfig = AppConfiguration(baseURL: "http://localhost:9090",
                                         transport: nil,
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = RealmSwift.App(id: ProcessInfo.processInfo.environment["app_id"]!, configuration: appConfig)
        app.login(credentials: Credentials.emailPassword(email: email, password: password))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
            }, receiveValue: { user in
                self.user = user
                completion(user)
            })
            .store(in: &cancellables)
    }
}

struct AsyncOpenView: View {
    @State var canNavigate: Bool = false
    @State var progress: Progress?
    @AsyncOpen(appId: ProcessInfo.processInfo.environment["app_id"]!,
               partitionValue: ProcessInfo.processInfo.environment["function_name"]!,
               timeout: 2000) var asyncOpen

    var body: some View {
        VStack {
            switch asyncOpen {
            case .connecting:
                ProgressView()
            case .waitingForUser:
                ProgressView("Waiting for user to logged in...")
            case .open(let realm):
                if canNavigate {
                    ListView()
                        .environment(\.realm, realm)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                } else {
                    VStack {
                        Text(String(progress!.completedUnitCount))
                            .accessibilityIdentifier("progress-text-view")
                        Button("Navigate Next View") {
                            canNavigate = true
                        }
                        .accessibilityIdentifier("show-list-button-view")
                    }
                }
            case .error(let error):
                ErrorView(error: error)
                    .background(Color.red)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            case .progress(let progress):
                ProgressView(progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.yellow)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
                    .onAppear {
                        self.progress = progress
                    }
            }
        }
    }
}

struct AutoOpenView: View {
    @State var canNavigate: Bool = false
    @State var progress: Progress?
    @AutoOpen(appId: ProcessInfo.processInfo.environment["app_id"]!,
              partitionValue: ProcessInfo.processInfo.environment["function_name"]!,
              timeout: 2000) var autoOpen

    var body: some View {
        VStack {
            switch autoOpen {
            case .connecting:
                ProgressView()
            case .waitingForUser:
                ProgressView("Waiting for user to logged in...")
            case .open(let realm):
                if canNavigate {
                    ListView()
                        .environment(\.realm, realm)
                        .transition(AnyTransition.move(edge: .leading)).animation(.default)
                } else {
                    VStack {
                        Text(String(progress!.completedUnitCount))
                            .accessibilityIdentifier("progress-text-view")
                        Button("Navigate Next View") {
                            canNavigate = true
                        }
                        .accessibilityIdentifier("show-list-button-view")
                    }
                }
            case .error(let error):
                ErrorView(error: error)
                    .background(Color.red)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            case .progress(let progress):
                ProgressView(progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.yellow)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
                    .onAppear {
                        self.progress = progress
                    }
            }
        }
    }
}

struct AsyncOpenPartitionView: View {
    @AsyncOpen(appId: ProcessInfo.processInfo.environment["app_id"]!,
               partitionValue: "wrong_partition_value",
               timeout: 2000) var asyncOpen

    var body: some View {
        VStack {
            switch asyncOpen {
            case .connecting:
                ProgressView()
            case .waitingForUser:
                ProgressView("Waiting for user to logged in...")
            case .open(let realm):
                ListView()
                    .environment(\.realm, realm)
                    .transition(AnyTransition.move(edge: .leading)).animation(.default)
            case .error(let error):
                ErrorView(error: error)
                    .background(Color.red)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            case .progress(let progress):
                ProgressView(progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.yellow)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            }
        }

    }
}

struct AutoOpenPartitionView: View {
    @AutoOpen(appId: ProcessInfo.processInfo.environment["app_id"]!,
               partitionValue: "wrong_partition_value",
               timeout: 2000) var autoOpen

    var body: some View {
        VStack {
            switch autoOpen {
            case .connecting:
                ProgressView()
            case .waitingForUser:
                ProgressView("Waiting for user to logged in...")
            case .open(let realm):
                ListView()
                    .environment(\.realm, realm)
                    .transition(AnyTransition.move(edge: .leading)).animation(.default)
            case .error(let error):
                ErrorView(error: error)
                    .background(Color.red)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            case .progress(let progress):
                ProgressView(progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.yellow)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            }
        }

    }
}

struct ErrorView: View {
    var error: Error
    var body: some View {
        VStack(spacing: 20) {
            Text("Error")
            Text(error.localizedDescription)
        }
        .padding()
    }
}

struct ListView: View {
    @ObservedResults(SwiftHugeSyncObject.self) var objects

    var body: some View {
        List {
            ForEach(objects) { object in
                Text("\(object._id)")
            }
        }
        .accessibilityIdentifier("table-view")
        .navigationTitle("SwiftHugeSyncObject's List")
    }
}
