import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    /// Window is always the max expanded size; the shape animates inside it.
    static let panelSize = CGSize(width: 620, height: 300)
    /// Room around the panel for the glow.
    static let margin: CGFloat = 24

    let panel = NotchPanel()
    let model = NotchViewModel()

    init() {
        let host = NSHostingView(rootView: NotchRootView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    func reposition() {
        guard let screen = NSScreen.notchScreen else { return }
        let geometry = NotchGeometry.of(screen)
        model.geometry = geometry
        let size = CGSize(width: Self.panelSize.width + Self.margin * 2,
                          height: Self.panelSize.height + Self.margin)
        let origin = CGPoint(x: screen.frame.minX + geometry.centerX - size.width / 2,
                             y: screen.frame.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }
}
