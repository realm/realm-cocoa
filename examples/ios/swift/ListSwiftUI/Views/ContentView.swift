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
import SwiftUI

class Reminder: EmbeddedObject, ObjectKeyIdentifiable {
    enum Priority: Int, PersistableEnum, CaseIterable, Identifiable, CustomStringConvertible {
        var id: Int { self.rawValue }

        case low, medium, high

        var description: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            }
        }
    }
    @Persisted var title: String
    @Persisted var notes: String
    @Persisted var isFlagged: Bool
    @Persisted var date: Date
    @Persisted var isComplete: Bool
    @Persisted var priority: Priority = .low
}

class ReminderList: Object, ObjectKeyIdentifiable {
    @Persisted var name = "New List"
    @Persisted var icon: String = "list.bullet"
    @Persisted var reminders: RealmSwift.List<Reminder>
}

struct FocusableTextField: UIViewRepresentable {
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var didBecomeFirstResponder = false

        init(text: Binding<String>) {
            _text = text
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }

    let title: String
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    init(_ title: String, text: Binding<String>, isFirstResponder: Binding<Bool>) {
        self.title = title
        self._text = text
        self._isFirstResponder = isFirstResponder
    }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = title
        textField.delegate = context.coordinator
        return textField
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<Self>) {
        uiView.text = text
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }
    }
}

struct ReminderRowView: View {
    @ObservedRealmObject var list: ReminderList
    @ObservedRealmObject var reminder: Reminder
    @State var hasFocus: Bool
    @State var showReminderForm = false

    var body: some View {
        NavigationLink(destination: ReminderFormView(list: list,
                                                     reminder: reminder,
                                                     showReminderForm: $showReminderForm), isActive: $showReminderForm) {
            FocusableTextField("title", text: reminder.bind(\.title), isFirstResponder: $hasFocus).textCase(.lowercase)
        }.isDetailLink(true)
    }
}

struct ReminderFormView: View {
    @ObservedRealmObject var list: ReminderList
    @ObservedRealmObject var reminder: Reminder
    @Binding var showReminderForm: Bool

    var body: some View {
        Form {
            TextField("title", text: $reminder.title)
            DatePicker("date", selection: $reminder.date)
            Picker("priority", selection: $reminder.priority, content: {
                ForEach(Reminder.Priority.allCases) { priority in
                    Text(priority.description).tag(priority)
                }
            })
        }
        .navigationTitle(reminder.title)
        .navigationBarItems(trailing:
        Button("Save") {
            if reminder.realm == nil {
                $list.reminders.append(reminder)
            }
            showReminderForm.toggle()
        }.disabled(reminder.title.isEmpty))
    }
}

struct ReminderListView: View {
    @ObservedRealmObject var list: ReminderList
    @State var newReminderAdded = false
    @State var showReminderForm = false

    func shouldFocusReminder(_ reminder: Reminder) -> Bool {
        return newReminderAdded &&
            list.reminders.lastIndex(of: reminder) == (list.reminders.count - 1)
    }

    var body: some View {
        VStack {
            List {
                ForEach(list.reminders) { reminder in
                    ReminderRowView(list: list,
                                    reminder: reminder,
                                    hasFocus: shouldFocusReminder(reminder))
                }
                .onMove(perform: $list.reminders.move)
                .onDelete(perform: $list.reminders.remove)
            }
        }.navigationTitle(list.name)
        .navigationBarItems(trailing: HStack {
            EditButton()
            Button("add") {
                newReminderAdded = true
                $list.reminders.append(Reminder())
            }.accessibility(identifier: "addReminder")
        })
    }
}

struct ReminderListRowView: View {
    @ObservedRealmObject var list: ReminderList

    var body: some View {
        HStack {
            Image(systemName: list.icon)
            TextField("List Name", text: $list.name)
            Spacer()
            Text("\(list.reminders.count)")
        }.frame(minWidth: 100)
    }
}

struct ReminderListResultsView: View {
    @ObservedResults(ReminderList.self) var reminders
    @Binding var searchFilter: String

    var body: some View {
        List {
            ForEach(reminders) { list in
                NavigationLink(destination: ReminderListView(list: list)) {
                    ReminderListRowView(list: list).tag(list)
                }.accessibilityIdentifier(list.name)
            }.onDelete(perform: $reminders.remove)
        }.onChange(of: searchFilter) { value in
            $reminders.filter = value.isEmpty ? nil : NSPredicate(format: "name CONTAINS[c] %@", value)
        }
    }
}

public extension Color {
    static let lightText = Color(UIColor.lightText)
    static let darkText = Color(UIColor.darkText)

    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)

    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
}

struct SearchView: View {
    @Binding var searchFilter: String

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    .padding(.leading, 7)
                    .padding(.top, 7)
                    .padding(.bottom, 7)
                TextField("search", text: $searchFilter)
                    .padding(.top, 7)
                    .padding(.bottom, 7)
            }.background(RoundedRectangle(cornerRadius: 15)
                            .fill(Color.secondarySystemBackground))
            Spacer()
        }.frame(maxHeight: 40).padding()
    }
}

struct Footer: View {
    @ObservedResults(ReminderList.self) var lists

    var body: some View {
        HStack {
            Button(action: {
                $lists.append(ReminderList())
            }, label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add list")
                }
            }).buttonStyle(BorderlessButtonStyle())
            .padding()
            .accessibility(identifier: "addList")
            Spacer()
        }
    }
}

struct ContentView: View {
    @State var searchFilter: String = ""

    var body: some View {
        NavigationView {
            VStack {
                SearchView(searchFilter: $searchFilter)
                ReminderListResultsView(searchFilter: $searchFilter)
                Spacer()
                Footer()
            }
            .navigationBarItems(trailing: EditButton())
            .navigationTitle("reminders")
        }
    }
}

#if DEBUG
// swiftlint:disable type_name
struct Content_Preview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
