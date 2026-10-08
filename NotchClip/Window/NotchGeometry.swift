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
        // No notch: a pill as tall as this screen's menu bar (32pt if the menu bar auto-hides).
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let size = CGSize(width: fallbackSize.width, height: menuBar > 0 ? menuBar : fallbackSize.height)
        return NotchGeometry(notchSize: size, centerX: screen.frame.width / 2, hasNotch: false)
    }
}

extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil }

    /// The built-in (notched) display if present, otherwise the main screen.
    static var notchScreen: NSScreen? {
        screens.first(where: \.hasNotch) ?? main ?? screens.first
    }
}
