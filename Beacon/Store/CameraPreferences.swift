import Foundation

/// Per-server camera order and visibility, stored on the device and keyed by camera name.
struct CameraPreferences {
    private let defaults: UserDefaults
    private let orderKey: String
    private let hiddenKey: String
    private var order: [String]
    private var hidden: Set<String>

    init(defaults: UserDefaults = .standard, server: URL) {
        self.defaults = defaults
        orderKey = "cameraOrder.\(server.absoluteString)"
        hiddenKey = "cameraHidden.\(server.absoluteString)"
        order = defaults.stringArray(forKey: orderKey) ?? []
        hidden = Set(defaults.stringArray(forKey: hiddenKey) ?? [])
    }

    /// Visible cameras in saved order; unknown (new) cameras are appended in their given order.
    func arranged(_ cameras: [Camera]) -> [Camera] {
        allArranged(cameras).filter { !$0.hidden }.map(\.camera)
    }

    /// Every current camera in saved order, with its hidden flag.
    func allArranged(_ cameras: [Camera]) -> [(camera: Camera, hidden: Bool)] {
        let byName = Dictionary(cameras.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let known = order.compactMap { byName[$0] }
        let knownNames = Set(known.map(\.name))
        let added = cameras.filter { !knownNames.contains($0.name) }
        return (known + added).map { ($0, hidden.contains($0.name)) }
    }

    /// Moves within the full (including hidden) list and persists the result.
    mutating func move(from source: IndexSet, to destination: Int, in cameras: [Camera]) {
        var names = allArranged(cameras).map(\.camera.name)
        let moving = source.sorted().map { names[$0] }
        let offset = source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { names.remove(at: index) }
        names.insert(contentsOf: moving, at: destination - offset)
        order = names
        defaults.set(order, forKey: orderKey)
    }

    mutating func setHidden(_ name: String, _ isHidden: Bool) {
        if isHidden { hidden.insert(name) } else { hidden.remove(name) }
        defaults.set(Array(hidden).sorted(), forKey: hiddenKey)
    }
}
