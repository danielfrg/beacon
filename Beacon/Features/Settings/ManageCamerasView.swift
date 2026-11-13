import SwiftUI

/// Reorder cameras and choose which ones are shown.
struct ManageCamerasView: View {
    @Environment(CamerasModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach(model.allArranged, id: \.camera.id) { entry in
                    HStack(spacing: 12) {
                        Button {
                            model.setHidden(entry.camera.name, !entry.hidden)
                        } label: {
                            Image(systemName: entry.hidden ? "plus.circle.fill" : "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(entry.hidden ? Color.green : Color.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(entry.hidden ? "Show \(entry.camera.name)" : "Hide \(entry.camera.name)")
                        Text(entry.camera.name)
                            .foregroundStyle(entry.hidden ? .secondary : .primary)
                    }
                }
                .onMove { model.move(from: $0, to: $1) }
            } footer: {
                Text("Change the order of cameras and decide what cameras should be shown.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Manage Cameras")
        .navigationBarTitleDisplayMode(.inline)
    }
}
