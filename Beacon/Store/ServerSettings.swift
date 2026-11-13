import Foundation
import Observation

/// The configured Frigate server, persisted in UserDefaults.
@Observable
final class ServerSettings {
    private static let key = "serverURL"
    private let defaults: UserDefaults

    var baseURL: URL? {
        didSet { defaults.set(baseURL?.absoluteString, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURL = defaults.string(forKey: Self.key).flatMap(URL.init(string:))
    }
}
