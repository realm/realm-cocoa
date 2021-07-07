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

struct LoginView: View {
    @ObservedObject var loginHelper = LoginHelper()
    var body: some View {
        NavigationView {
            if loginHelper.isLogged {
                switch ProcessInfo.processInfo.environment["test_type"] {
                case "async_open":
                    AsyncOpenView()
                case "auto_open":
                    AutoOpenView()
                default:
                    EmptyView()
                }
            } else {
                ProgressView("Logging...")
            }
        }
        .onAppear(perform: {
            loginHelper.login(email: ProcessInfo.processInfo.environment["function_name"]!, password: "password")
        })
    }
}

class LoginHelper: ObservableObject {
    @Published var isLogged: Bool = false
    var cancellables = Set<AnyCancellable>()

    func login(email: String, password: String) {
        let appConfig = AppConfiguration(baseURL: "http://localhost:9090",
                                         transport: nil,
                                         localAppName: nil,
                                         localAppVersion: nil)
        let app = RealmSwift.App(id: ProcessInfo.processInfo.environment["app_id"]!, configuration: appConfig)
        app.login(credentials: Credentials.emailPassword(email: email, password: password))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
            }, receiveValue: { _ in
                self.isLogged = true
            })
            .store(in: &cancellables)
    }
}

struct AsyncOpenView: View {
    @AsyncOpen(appId: ProcessInfo.processInfo.environment["app_id"]!, partitionValue: ProcessInfo.processInfo.environment["function_name"]!) var asyncOpen

    var body: some View {

        switch asyncOpen {
        case .notOpen:
            ProgressView()
        case .open(let realm):
            ListView()
                .environment(\.realm, realm)
            ErrorView()
        case .progress(let progress):
            ProgressView(progress)
        }
    }
}

struct AutoOpenView: View {
    @AsyncOpen(appId: ProcessInfo.processInfo.environment["app_id"]!, partitionValue: ProcessInfo.processInfo.environment["function_name"]!) var asyncOpen

    var body: some View {
        switch asyncOpen {
        case .notOpen:
            ProgressView()
        case .open(let realm):
            ListView()
                .environment(\.realm, realm)
            ErrorView()
        case .progress(let progress):
            ProgressView(progress)
        }
    }
}

struct ErrorView: View {
    var body: some View {
        Text("Error View")
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
        .navigationTitle("SwiftPerson's List")
    }
}
