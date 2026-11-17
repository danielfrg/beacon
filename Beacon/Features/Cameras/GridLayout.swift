import CoreGraphics

/// Columns and spacing for the camera grid: one column on phones and narrow windows,
/// two on regular-width windows, three once the window is wide (iPad landscape, 13" iPads).
struct GridLayout: Equatable {
    static let wideThreshold: CGFloat = 1000

    let columns: Int
    let spacing: CGFloat

    init(isRegular: Bool, width: CGFloat) {
        guard isRegular else {
            columns = 1
            spacing = 16
            return
        }
        columns = width >= Self.wideThreshold ? 3 : 2
        spacing = 24
    }
}
