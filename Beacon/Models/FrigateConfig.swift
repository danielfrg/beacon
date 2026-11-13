import Foundation

struct Camera: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var enabled: Bool
    var detectEnabled: Bool
    var motionEnabled: Bool
    var recordEnabled: Bool
    var snapshotsEnabled: Bool
    var width: Int?
    var height: Int?
    var fps: Int?
    /// go2rtc stream name used for live view.
    var goStream: String

    static func decodeCameras(from data: Data) throws -> [Camera] {
        let config = try JSONDecoder().decode(RawConfig.self, from: data)
        return config.cameras
            .map { name, raw in
                Camera(
                    name: name,
                    enabled: raw.enabled ?? true,
                    detectEnabled: raw.detect?.enabled ?? false,
                    motionEnabled: raw.motion?.enabled ?? false,
                    recordEnabled: raw.record?.enabled ?? false,
                    snapshotsEnabled: raw.snapshots?.enabled ?? false,
                    width: raw.detect?.width,
                    height: raw.detect?.height,
                    fps: raw.detect?.fps,
                    goStream: pickStream(raw.live?.streams, fallback: name)
                )
            }
            .sorted { $0.name < $1.name }
    }

    /// Prefer the entry keyed "Main" (case-insensitive), else the alphabetically first key.
    private static func pickStream(_ streams: [String: String]?, fallback: String) -> String {
        guard let streams, !streams.isEmpty else { return fallback }
        if let main = streams.first(where: { $0.key.lowercased() == "main" }) { return main.value }
        return streams.sorted { $0.key < $1.key }[0].value
    }
}

private struct RawConfig: Decodable {
    struct Toggle: Decodable { var enabled: Bool? }
    struct Detect: Decodable { var enabled: Bool?; var width: Int?; var height: Int?; var fps: Int? }
    struct Live: Decodable { var streams: [String: String]? }
    struct RawCamera: Decodable {
        var enabled: Bool?
        var detect: Detect?
        var motion: Toggle?
        var record: Toggle?
        var snapshots: Toggle?
        var live: Live?
    }
    var cameras: [String: RawCamera]
}
