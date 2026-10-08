import AppKit

/// Notch size and position for one screen, in points.
struct NotchGeometry: Equatable {
    static let fallbackSize = CGSize(width: 180, height: 32)

    var notchSize: CGSize
    /// Notch center x, relative to the screen's left edge.
    var centerX: CGFloat
    var hasNotch: Bool

    static func of(_ screen: NSScreen) -> NotchGeometry {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            if width > 0 {
                return NotchGeometry(notchSize: CGSize(width: width, height: top),
                                     centerX: left.width + width / 2,
                                     hasNotch: true)
            }
        }
        return NotchGeometry(notchSize: fallbackSize, centerX: screen.frame.width / 2, hasNotch: false)
    }
}

extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil }

    /// The built-in (notched) display if present, otherwise the main screen.
    static var notchScreen: NSScreen? {
        screens.first(where: \.hasNotch) ?? main ?? screens.first
    }
}
