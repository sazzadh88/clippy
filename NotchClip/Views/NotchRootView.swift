import AppKit
import SwiftUI

enum NotchState { case collapsed, hovered, expanded }

struct NotchMetrics {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var earRadius: CGFloat

    /// Visible bounds including ears, relative to the top-center of the window.
    var outerWidth: CGFloat { width + earRadius * 2 }
}

enum Motion {
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private static func spring(_ response: Double, _ damping: Double) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: response, dampingFraction: damping)
    }
    static var hover: Animation { spring(0.3, 0.7) }
    static var expand: Animation { spring(0.42, 0.78) }
    /// Delayed so content fades out first.
    static var collapse: Animation { spring(0.35, 0.9).delay(reduceMotion ? 0 : 0.12) }
    static var contentIn: Animation { reduceMotion ? .easeInOut(duration: 0.15) : .easeOut(duration: 0.22).delay(0.09) }
    static var contentOut: Animation { .easeIn(duration: reduceMotion ? 0.15 : 0.12) }
}

@MainActor @Observable
final class NotchViewModel {
    static let expandedSize = CGSize(width: 620, height: 300)

    var geometry = NotchGeometry(notchSize: NotchGeometry.fallbackSize, centerX: 0, hasNotch: false)
    private(set) var state: NotchState = .collapsed
    private(set) var showContent = false
    var pinnedOnly = false
    var collapseAfterCopy = true
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?

    var metrics: NotchMetrics { metrics(for: state) }

    func metrics(for state: NotchState) -> NotchMetrics {
        let n = geometry.notchSize
        // Fallback (no hardware notch) is a pill; a real notch has ~10pt bottom corners.
        let collapsedRadius = geometry.hasNotch ? 10 : n.height / 2
        switch state {
        case .collapsed:
            return NotchMetrics(width: n.width, height: n.height, bottomRadius: collapsedRadius, earRadius: 0)
        case .hovered:
            return NotchMetrics(width: n.width + 12, height: n.height + 4, bottomRadius: collapsedRadius + 2, earRadius: 6)
        case .expanded:
            return NotchMetrics(width: Self.expandedSize.width, height: Self.expandedSize.height,
                                bottomRadius: 24, earRadius: 12)
        }
    }

    func hover() {
        guard state == .collapsed else { return }
        withAnimation(Motion.hover) { state = .hovered }
        onStateChange?(state)
    }

    func unhover() {
        guard state == .hovered else { return }
        withAnimation(Motion.hover) { state = .collapsed }
        onStateChange?(state)
    }

    func expand() {
        guard state != .expanded else { return }
        withAnimation(Motion.expand) { state = .expanded }
        withAnimation(Motion.contentIn) { showContent = true }
        onStateChange?(state)
    }

    func collapse() {
        guard state == .expanded else { return }
        withAnimation(Motion.contentOut) { showContent = false }
        withAnimation(Motion.collapse) { state = .collapsed }
        onStateChange?(state)
    }
}

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let m = model.metrics
        let notchHeight = model.geometry.notchSize.height
        ZStack(alignment: .top) {
            NotchShape(m)
                .fill(.black)
                .shadow(color: .white.opacity(model.state == .collapsed ? 0 : 0.08), radius: 12)
                .onTapGesture { model.expand() }

            if model.showContent {
                VStack(spacing: 6) {
                    HeaderView()
                    ClipboardListView()
                }
                .frame(width: NotchViewModel.expandedSize.width - 32,
                       height: NotchViewModel.expandedSize.height - notchHeight - 12)
                .padding(.top, notchHeight)
                .transition(.opacity
                    .combined(with: .scale(scale: 0.96, anchor: .top))
                    .combined(with: .modifier(active: BlurModifier(radius: 6), identity: BlurModifier(radius: 0))))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}
