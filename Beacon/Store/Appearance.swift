import SwiftUI

/// User's light/dark choice. Dark is the default; "system" follows the device.
enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, system

    static let `default` = Appearance.dark
    static let storageKey = "appearance"

    init(storedValue: String) {
        self = Appearance(rawValue: storedValue) ?? .default
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
