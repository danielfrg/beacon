import SwiftUI

struct CameraDetailView: View {
    @State private var model: CameraDetailModel
    @Environment(\.dismiss) private var dismiss

    init(camera: Camera, api: FrigateAPI, onChange: @escaping (Camera) -> Void) {
        _model = State(initialValue: CameraDetailModel(camera: camera, api: api, onChange: onChange))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    LabeledContent("Name", value: model.camera.name)
                    LabeledContent("Status", value: model.camera.enabled ? "Enabled" : "Disabled")
                    LabeledContent("Detect resolution", value: resolution)
                    LabeledContent("Detect frame rate", value: model.camera.fps.map { "\($0) fps" } ?? "—")
                }
                Section {
                    ForEach(CameraDetailModel.Feature.allCases) { feature in
                        Toggle(feature.title, isOn: Binding(
                            get: { model.isOn(feature) },
                            set: { value in Task { await model.toggle(feature, to: value) } }))
                            .disabled(model.busy.contains(feature))
                    }
                } header: {
                    Text("Controls")
                } footer: {
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("These change settings on your Frigate server.")
                    }
                }
            }
            .navigationTitle(model.camera.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var resolution: String {
        guard let w = model.camera.width, let h = model.camera.height else { return "—" }
        return "\(w) × \(h)"
    }
}
