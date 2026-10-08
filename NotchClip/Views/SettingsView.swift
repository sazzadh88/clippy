import AppKit
import KeyboardShortcuts
import SwiftUI

/// A plain NSWindow, since a SwiftUI `Settings` scene is awkward to open from an agent app.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings
    private let store: ClipboardStore

    init(settings: AppSettings, store: ClipboardStore) {
        self.settings = settings
        self.store = store
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings, store: store))
            let window = NSWindow(contentViewController: host)
            window.title = "NotchClip Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let store: ClipboardStore

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
                KeyboardShortcuts.Recorder("Toggle panel", name: .togglePanel)
            }

            Section("History") {
                Picker("Keep", selection: $settings.historyLimit) {
                    ForEach(ClipboardStore.limitOptions, id: \.self) { Text("\($0) items").tag($0) }
                }
                .onChange(of: settings.historyLimit) { _, limit in store.limit = limit }
                Toggle("Close the list after copying an item", isOn: $settings.closeAfterCopy)
                LabeledContent("Pinned items never count toward the limit.") {
                    Button("Clear History…", role: .destructive) { confirmClear = true }
                }
                .font(.callout)
            }

            Section {
                ForEach(settings.ignoredBundleIDs, id: \.self) { id in
                    HStack {
                        AppLabel(bundleID: id)
                        Spacer()
                        Button {
                            settings.ignoredBundleIDs.removeAll { $0 == id }
                        } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Stop ignoring")
                    }
                }
                Menu("Add Running App…") {
                    ForEach(addableApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            if let id = app.bundleIdentifier { settings.ignoredBundleIDs.append(id) }
                        }
                    }
                }
            } header: {
                Text("Ignored Apps")
            } footer: {
                Text("Copies made in these apps are never recorded.").font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Quit NotchClip") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clear() }
        } message: {
            Text("Pinned items are kept.")
        }
    }

    private var addableApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                && !settings.ignoredBundleIDs.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try LaunchAtLogin.set(on)
            launchError = LaunchAtLogin.needsApproval
                ? "Approve NotchClip in System Settings › General › Login Items." : nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

private struct AppLabel: View {
    /// Names for the default ignored apps, shown even when they aren't installed.
    private static let knownNames = [
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.bitwarden.desktop": "Bitwarden",
        "com.apple.keychainaccess": "Keychain Access",
        "com.apple.Passwords": "Passwords",
    ]

    let bundleID: String
    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack(spacing: 8) {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
            } else {
                Image(systemName: "app.dashed").frame(width: 18, height: 18).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? Self.knownNames[bundleID] ?? bundleID)
                if url == nil {
                    Text("Not installed").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
