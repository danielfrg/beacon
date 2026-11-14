import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServerSettings.self) private var settings
    @Environment(CamerasModel.self) private var model

    @AppStorage(Appearance.storageKey) private var appearance = Appearance.default.rawValue
    @State private var address = ""
    @State private var checking = false
    @State private var loadedAddress = false
    @State private var message: (text: String, isError: Bool)?
    @State private var appIcon = AppIconChoice.current
    @State private var iconError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://frigate.example.com", text: $address)
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
                        Text("The address of your Frigate server, for example https://frigate.example.com.")
                    }
                }

                Section {
                    NavigationLink("Manage Cameras") { ManageCamerasView() }
                        .disabled(model.cameras.isEmpty)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                if AppIconChoice.isSupported {
                    Section {
                        ForEach(AppIconChoice.allCases) { choice in
                            Button {
                                Task { await select(choice) }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(choice.previewName)
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(.primary.opacity(0.12)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(choice.title).foregroundStyle(.primary)
                                        if let subtitle = choice.subtitle {
                                            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if appIcon == choice {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("appIcon.\(choice.rawValue)")
                            .accessibilityLabel(choice.title)
                            .accessibilityHint(choice.subtitle ?? "")
                            .accessibilityAddTraits(appIcon == choice ? .isSelected : [])
                        }
                    } header: {
                        Text("App icon")
                    } footer: {
                        if let iconError { Text(iconError).foregroundStyle(Color.red) }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                // Only the first time: coming back from a pushed screen must not discard unsaved typing.
                guard !loadedAddress else { return }
                loadedAddress = true
                address = settings.baseURL?.absoluteString ?? ""
            }
        }
    }

    private func select(_ choice: AppIconChoice) async {
        iconError = nil
        do {
            try await AppIconChoice.apply(choice)
            appIcon = choice
        } catch {
            iconError = "Couldn't change the icon: \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard !checking else { return } // Return key and Save button can race
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
