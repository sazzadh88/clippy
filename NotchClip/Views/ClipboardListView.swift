import AppKit
import SwiftUI

struct ClipboardListView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(PasteboardMonitor.self) private var monitor
    @Environment(NotchViewModel.self) private var model
    /// Flips once on appear; each row animates in with its own small delay (stagger).
    @State private var revealed = false

    var body: some View {
        let visible = model.pinnedOnly ? store.items.filter(\.isPinned) : store.items
        let pinned = visible.filter(\.isPinned)
        let recent = visible.filter { !$0.isPinned }

        VStack(spacing: 8) {
            if monitor.accessDenied { AccessDeniedCard() }

            if visible.isEmpty {
                EmptyStateView(pinnedOnly: model.pinnedOnly)
            } else {
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        LazyVStack(spacing: 8) {
                            if !pinned.isEmpty {
                                SectionLabel(title: "Pinned")
                                rows(pinned, startIndex: 0, now: timeline.date)
                                if !recent.isEmpty { SectionLabel(title: "Recent") }
                            }
                            rows(recent, startIndex: pinned.count, now: timeline.date)
                        }
                        .padding(.bottom, 8)
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .onAppear { revealed = true }
    }

    private func rows(_ items: [ClipItem], startIndex: Int, now: Date) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
            ClipboardRowView(item: item, now: now, imageURL: store.imageURL(for: item),
                             onCopy: { copy(item, plainTextOnly: $0) },
                             onTogglePin: { withAnimation(.rowSpring) { store.togglePin(id: item.id) } },
                             onDelete: { withAnimation(.rowSpring) { store.remove(id: item.id) } })
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                        removal: .opacity.combined(with: .offset(x: -24))))
                .stagger(revealed: revealed, index: startIndex + offset)
        }
    }

    private func copy(_ item: ClipItem, plainTextOnly: Bool) {
        withAnimation(.rowSpring) { monitor.copy(item, plainTextOnly: plainTextOnly) }
        if model.collapseAfterCopy {
            Task {
                try? await Task.sleep(for: .seconds(0.9)) // let the "Copied" morph play
                model.collapse()
            }
        }
    }
}

extension Animation {
    static var rowSpring: Animation {
        Motion.reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.85)
    }
}

private extension View {
    func stagger(revealed: Bool, index: Int) -> some View {
        let delay = 0.09 + Double(min(index, 10)) * 0.025
        return opacity(revealed ? 1 : 0)
            .offset(y: revealed || Motion.reduceMotion ? 0 : 6)
            .animation(.easeOut(duration: 0.22).delay(delay), value: revealed)
    }
}

private struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.35))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 2)
    }
}

private struct EmptyStateView: View {
    let pinnedOnly: Bool
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: pinnedOnly ? "pin.slash" : "clipboard")
                .font(.system(size: 26, weight: .light))
            Text(pinnedOnly ? "No pinned items" : "Copy something to see it here")
                .font(.system(size: 12))
        }
        .foregroundStyle(.white.opacity(0.35))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AccessDeniedCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Clipboard access is turned off")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Open System Settings › Privacy & Security › Paste from Other Apps and set NotchClip to Allow.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.orange.opacity(0.12)))
    }
}
