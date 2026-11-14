import UIKit

/// The home-screen icon the user can pick. Automatic is the primary `AppIcon`, which ships a
/// light and a dark variant so iOS follows the device theme. Light and Dark are alternate icons
/// declared in `project.yml` that stay fixed whatever the device theme is.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case automatic, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var subtitle: String? {
        self == .automatic ? "Matches your iPhone" : nil
    }

    /// Name passed to `setAlternateIconName`; nil means the primary icon.
    var alternateName: String? {
        switch self {
        case .automatic: nil
        case .light: "AppIconLight"
        case .dark: "AppIconDark"
        }
    }

    /// Image set used to show the icon in Settings (app icon sets can't be loaded as images).
    var previewName: String {
        switch self {
        case .automatic: "IconAuto"
        case .light: "IconLight"
        case .dark: "IconDark"
        }
    }

    /// The icon currently set on the device.
    @MainActor static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateName == name } ?? .automatic
    }

    @MainActor static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// Switches the home-screen icon. iOS shows its own confirmation alert.
    @MainActor static func apply(_ choice: AppIconChoice) async throws {
        guard choice != current else { return }
        try await UIApplication.shared.setAlternateIconName(choice.alternateName)
    }
}
