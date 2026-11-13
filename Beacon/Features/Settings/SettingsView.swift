import SwiftUI

/// Placeholder; the real settings screen is built in the settings task.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
