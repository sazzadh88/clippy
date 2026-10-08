import AppKit
import SwiftUI

struct ClipboardListView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(PasteboardMonitor.self) private var monitor
    @Environment(NotchViewModel.self) private var model
    /// Flips once on appear; each row animates in with its own small delay (stagger).
    @State private var revealed = false

    var body: some View {
        let (pinned, recent) = model.sections

        VStack(spacing: 8) {
            if monitor.accessDenied { AccessDeniedCard() }

            if pinned.isEmpty && recent.isEmpty {
                EmptyStateView(message: emptyMessage)
            } else {
                ScrollViewReader { proxy in
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
                    .onChange(of: model.selectedID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) }
                    }
                }
            }
        }
        .onAppear { revealed = true }
    }

    private var emptyMessage: (symbol: String, text: String) {
        if !model.searchText.isEmpty { return ("magnifyingglass", "No matches") }
        if model.pinnedOnly { return ("pin.slash", "No pinned items") }
        return ("clipboard", "Copy something to see it here")
    }

    private func rows(_ items: [ClipItem], startIndex: Int, now: Date) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
            ClipboardRowView(item: item, now: now, imageURL: store.imageURL(for: item),
                             isSelected: model.selectedID == item.id,
                             isCopied: model.copiedID == item.id,
                             onCopy: { model.copy(item, plainTextOnly: $0) },
                             onTogglePin: { model.togglePin(item) },
                             onDelete: { model.delete(item) })
                .id(item.id)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                        removal: .opacity.combined(with: .offset(x: -24))))
                .stagger(revealed: revealed, index: startIndex + offset)
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
    let message: (symbol: String, text: String)
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: message.symbol)
                .font(.system(size: 26, weight: .light))
            Text(message.text)
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
