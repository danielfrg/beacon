import Foundation
import Observation

/// Read-only camera info plus a few server toggles (applied optimistically, reverted on failure).
@MainActor
@Observable
final class CameraDetailModel {
    enum Feature: String, CaseIterable, Identifiable {
        case detect, motion, recordings, snapshots
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private(set) var camera: Camera
    private(set) var busy: Set<Feature> = []
    var error: String?

    private let api: FrigateAPI
    private let onChange: (Camera) -> Void

    init(camera: Camera, api: FrigateAPI, onChange: @escaping (Camera) -> Void = { _ in }) {
        self.camera = camera
        self.api = api
        self.onChange = onChange
    }

    func isOn(_ feature: Feature) -> Bool {
        switch feature {
        case .detect: camera.detectEnabled
        case .motion: camera.motionEnabled
        case .recordings: camera.recordEnabled
        case .snapshots: camera.snapshotsEnabled
        }
    }

    func toggle(_ feature: Feature, to on: Bool) async {
        guard !busy.contains(feature) else { return }
        let original = camera
        let previous = isOn(feature)
        error = nil
        busy.insert(feature)
        defer { busy.remove(feature) }
        set(feature, on)
        do {
            try await api.setFeature(feature.rawValue, on: on, camera: original)
        } catch {
            set(feature, previous) // only this feature; other toggles may be mid-flight
            self.error = "Couldn't change \(feature.title.lowercased()): \(FrigateError.userMessage(for: error))"
            return
        }
        // Confirm against the server; keep the local value if the refresh itself fails.
        if let fresh = try? await api.fetchCameras().first(where: { $0.name == original.name }) {
            camera = fresh
        }
        if isOn(feature) != on {
            // Frigate accepted the request but kept the old value (e.g. it depends on another setting).
            error = "Frigate didn't apply this change. \(feature.title) may depend on another setting."
        }
        onChange(camera)
    }

    private func set(_ feature: Feature, _ on: Bool) {
        switch feature {
        case .detect: camera.detectEnabled = on
        case .motion: camera.motionEnabled = on
        case .recordings: camera.recordEnabled = on
        case .snapshots: camera.snapshotsEnabled = on
        }
    }
}
