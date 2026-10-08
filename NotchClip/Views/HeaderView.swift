import SwiftUI

struct HeaderView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(NotchViewModel.self) private var model
    @State private var confirmingClear = false
    @State private var confirmTask: Task<Void, Never>?

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Text("Clipboard")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("\(store.items.count)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
                .padding(.trailing, 4)
            HeaderIconButton(systemName: model.pinnedOnly ? "pin.fill" : "pin", isActive: model.pinnedOnly,
                             help: "Show pinned only") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { model.pinnedOnly.toggle() }
            }

            Spacer(minLength: 0)

            if confirmingClear {
                Button("Confirm", action: clear)
                    .buttonStyle(PillButtonStyle(tint: .red))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HeaderIconButton(systemName: "trash", help: "Clear history (keeps pinned)") {
                    withAnimation(.easeOut(duration: 0.15)) { confirmingClear = true }
                    confirmTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.15)) { confirmingClear = false }
                    }
                }
                .disabled(store.items.allSatisfy(\.isPinned))
            }
        }
        .frame(height: 28)
    }

    private func clear() {
        confirmTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            store.clear()
            confirmingClear = false
        }
    }
}

struct HeaderIconButton: View {
    let systemName: String
    var isActive = false
    var help = ""
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(!isEnabled ? 0.25 : (hovering || isActive) ? 1 : 0.55))
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint == .white ? .black : .white)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.7 : 0.9)))
    }
}
