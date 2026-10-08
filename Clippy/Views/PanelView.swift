import AppKit
import SwiftUI

enum Motion {
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

@MainActor @Observable
final class PanelModel {
    static let size = CGSize(width: 420, height: 480)

    private(set) var isOpen = false
    var pinnedOnly = false
    var searchVisible = false
    var searchText = ""
    /// Mirrors the header's @FocusState so key handling knows whether ⌫ belongs to the field.
    var searchFocused = false
    /// Bumped to ask the header to focus the search field (⌘F).
    private(set) var focusSearchRequest = 0
    var selectedID: ClipItem.ID?
    private(set) var copiedID: ClipItem.ID?
    @ObservationIgnored var onOpenChange: ((Bool) -> Void)?
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    let store: ClipboardStore
    let monitor: PasteboardMonitor
    let settings: AppSettings

    init(store: ClipboardStore, monitor: PasteboardMonitor, settings: AppSettings) {
        self.store = store
        self.monitor = monitor
        self.settings = settings
    }

    // MARK: - Open / close

    func open() {
        guard !isOpen else { return }
        selectedID = visibleItems.first?.id
        isOpen = true
        onOpenChange?(true)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        searchVisible = false
        searchText = ""
        onOpenChange?(false)
    }

    func toggle() { isOpen ? close() : open() }

    func openSettings() {
        close()
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
            try? await Task.sleep(for: .seconds(0.6)) // let the "Copied" check show
            if copiedID == item.id { withAnimation(.easeOut(duration: 0.2)) { copiedID = nil } }
            if settings.closeAfterCopy { close() }
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
}

/// The dropdown shown under the menu bar icon.
struct PanelView: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 6) {
            HeaderView()
            ClipboardListView()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(width: PanelModel.size.width, height: PanelModel.size.height)
        .background(shape.fill(.black.opacity(0.94)))
        .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
        .clipShape(shape)
        .preferredColorScheme(.dark)
    }
}
