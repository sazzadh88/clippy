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
    var searchVisible = false
    var searchText = ""
    /// Mirrors the header's @FocusState so key handling knows whether ⌫ belongs to the field.
    var searchFocused = false
    /// Bumped to ask the header to focus the search field (⌘F).
    private(set) var focusSearchRequest = 0
    var selectedID: ClipItem.ID?
    private(set) var copiedID: ClipItem.ID?
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    let store: ClipboardStore
    let monitor: PasteboardMonitor
    let settings: AppSettings

    init(store: ClipboardStore, monitor: PasteboardMonitor, settings: AppSettings) {
        self.store = store
        self.monitor = monitor
        self.settings = settings
    }

    func openSettings() {
        collapse()
        onOpenSettings?()
    }

    // MARK: - List contents

    /// Display order: pinned section first, then recent. Filtered by the pin toggle and search.
    var sections: (pinned: [ClipItem], recent: [ClipItem]) {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let items = store.items.filter { (!pinnedOnly || $0.isPinned) && (query.isEmpty || $0.matches(query)) }
        return (items.filter(\.isPinned), items.filter { !$0.isPinned })
    }

    var visibleItems: [ClipItem] { sections.pinned + sections.recent }

    // MARK: - Actions (shared by mouse and keyboard)

    func copy(_ item: ClipItem, plainTextOnly: Bool = false) {
        withAnimation(.rowSpring) { monitor.copy(item, plainTextOnly: plainTextOnly) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { copiedID = item.id }
        Task {
            try? await Task.sleep(for: .seconds(0.9)) // let the "Copied" morph play
            if copiedID == item.id { withAnimation(.easeOut(duration: 0.2)) { copiedID = nil } }
            if settings.collapseAfterCopy { collapse() }
        }
    }

    func delete(_ item: ClipItem) {
        if selectedID == item.id {
            // Keep a selection for repeated ⌫: next item, else previous.
            let items = visibleItems
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                selectedID = items.indices.contains(i + 1) ? items[i + 1].id : (i > 0 ? items[i - 1].id : nil)
            }
        }
        withAnimation(.rowSpring) { store.remove(id: item.id) }
    }

    func togglePin(_ item: ClipItem) {
        withAnimation(.rowSpring) { store.togglePin(id: item.id) }
    }

    func moveSelection(by delta: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : items.count)
        selectedID = items[min(max(current + delta, 0), items.count - 1)].id
    }

    func copySelected() {
        if let item = visibleItems.first(where: { $0.id == selectedID }) { copy(item) }
    }

    func deleteSelected() {
        if let item = visibleItems.first(where: { $0.id == selectedID }) { delete(item) }
    }

    /// ⌘1…⌘9: copy the nth visible item.
    func quickCopy(_ n: Int) {
        let items = visibleItems
        guard items.indices.contains(n - 1) else { return }
        selectedID = items[n - 1].id
        copy(items[n - 1])
    }

    func showSearch() {
        withAnimation(.easeOut(duration: 0.15)) { searchVisible = true }
        focusSearchRequest += 1
    }

    func hideSearch() {
        withAnimation(.easeOut(duration: 0.15)) { searchVisible = false }
        searchText = ""
    }

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
        selectedID = visibleItems.first?.id
        withAnimation(Motion.expand) { state = .expanded }
        withAnimation(Motion.contentIn) { showContent = true }
        onStateChange?(state)
    }

    func collapse() {
        guard state == .expanded else { return }
        withAnimation(Motion.contentOut) { showContent = false }
        withAnimation(Motion.collapse) { state = .collapsed }
        searchVisible = false
        searchText = ""
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
                .contextMenu {
                    Button("Settings…") { model.openSettings() }
                    Divider()
                    Button("Quit NotchClip") { NSApp.terminate(nil) }
                }

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
