import UIKit

/// The home-screen icons the user can pick from. The first is the default `AppIcon`;
/// the rest are alternate icons declared in `project.yml`. Each one ships a light and a
/// dark variant, so iOS picks the right one from the device appearance.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case sun, lighthouse, lighthouseBird

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sun: "Red Sun"
        case .lighthouse: "Lighthouse"
        case .lighthouseBird: "Lighthouse and Bird"
        }
    }

    /// Name passed to `setAlternateIconName`; nil means the primary icon.
    var alternateName: String? {
        switch self {
        case .sun: nil
        case .lighthouse: "AppIconLighthouse"
        case .lighthouseBird: "AppIconLighthouseBird"
        }
    }

    /// Image set used to show the icon in Settings (app icon sets can't be loaded as images).
    var previewName: String {
        switch self {
        case .sun: "IconSun"
        case .lighthouse: "IconLighthouse"
        case .lighthouseBird: "IconLighthouseBird"
        }
    }

    /// The icon currently set on the device.
    @MainActor static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateName == name } ?? .sun
    }

    @MainActor static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// Switches the home-screen icon. iOS shows its own confirmation alert.
    @MainActor static func apply(_ choice: AppIconChoice) async throws {
        guard choice != current else { return }
        try await UIApplication.shared.setAlternateIconName(choice.alternateName)
    }
}
