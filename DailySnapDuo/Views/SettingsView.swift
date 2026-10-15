import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onSubmit { model.rename(name) }
                    Button("Save name") { model.rename(name) }
                }

                Section("Reminders") {
                    Toggle("Daily prompt", isOn: $model.settings.notificationsEnabled)
                    if model.notificationAuthorization == .denied {
                        Button("Notifications are off in Settings") {
                            model.openSystemSettings()
                        }
                    } else if model.notificationAuthorization == .notDetermined {
                        Button("Allow reminders") {
                            Task { await model.enableNotifications() }
                        }
                    }
                }

                Section {
                    Toggle("Practice with Riley", isOn: Binding(
                        get: { model.settings.samplePartner },
                        set: { model.setSamplePartner($0) }
                    ))
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Riley posts a drawn snap after the window opens, so you can try the reveal on one phone. You still have to post before you can see it.")
                }

                Section {
                    Picker("Sync", selection: $model.settings.syncMode) {
                        ForEach(SyncMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    if model.settings.syncMode == .http {
                        TextField("http://192.168.1.20:8787", text: $model.settings.serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    Text(model.settings.syncMode.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("iCloud needs a paid Apple Developer account. A free Apple ID can use this iPhone, a snap file, or the relay.")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("One prompt a day for two people. The time comes from your invite code, so both phones agree without a server.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.rename(name)
                        model.noteSettingsChanged()
                        dismiss()
                    }
                }
            }
            .onAppear { name = model.profile?.displayName ?? "" }
            .onChange(of: model.settings) { _, _ in
                model.noteSettingsChanged()
            }
        }
        .presentationDragIndicator(.visible)
    }
}
