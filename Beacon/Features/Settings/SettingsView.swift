import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServerSettings.self) private var settings
    @Environment(CamerasModel.self) private var model

    @State private var address = ""
    @State private var checking = false
    @State private var message: (text: String, isError: Bool)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.0.2.10:5000", text: $address)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { Task { await save() } }
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Text("Save")
                            if checking { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(checking || address.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Frigate server")
                } footer: {
                    if let message {
                        Text(message.text).foregroundStyle(message.isError ? Color.red : Color.green)
                    } else {
                        Text("The address of your Frigate server, for example 192.0.2.10:5000.")
                    }
                }

                Section {
                    NavigationLink("Manage Cameras") { ManageCamerasView() }
                        .disabled(model.cameras.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { address = settings.baseURL?.absoluteString ?? "" }
        }
    }

    private func save() async {
        checking = true
        message = nil
        defer { checking = false }
        switch await checkConnection(address) {
        case .ok(let url, let count):
            settings.baseURL = url
            address = url.absoluteString
            message = ("Connected. Found \(count) camera\(count == 1 ? "" : "s").", false)
            await model.load(baseURL: url)
        case .invalid:
            message = ("Enter the address of your Frigate server.", true)
        case .failed(let text):
            message = (text, true)
        }
    }
}

#Preview {
    SettingsView()
        .environment(ServerSettings())
        .environment(CamerasModel())
}
