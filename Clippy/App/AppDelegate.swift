import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var store: ClipboardStore?
    private var monitor: PasteboardMonitor?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run hosted in the app; don't touch the real clipboard or history.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        migrateFromNotchClip()
        let settings = AppSettings()
        let store = ClipboardStore(limit: settings.historyLimit)
        let monitor = PasteboardMonitor(store: store, settings: settings)
        monitor.start()
        let settingsWindow = SettingsWindowController(settings: settings, store: store)
        let controller = MenuBarController(store: store, monitor: monitor, settings: settings)
        controller.model.onOpenSettings = { settingsWindow.show() }
        self.store = store
        self.monitor = monitor
        self.settingsWindow = settingsWindow
        menuBarController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.saveNow()
    }

    /// The app used to be called NotchClip (bundle ID `in.f9x.NotchClip`). Carry over its history
    /// folder and preferences once, without overwriting anything Clippy already has.
    /// ponytail: one-time migration; delete once nobody runs a NotchClip build.
    private func migrateFromNotchClip() {
        let fm = FileManager.default
        let oldDirectory = URL.applicationSupportDirectory.appending(path: "NotchClip", directoryHint: .isDirectory)
        if fm.fileExists(atPath: oldDirectory.path), !fm.fileExists(atPath: ClipboardStore.defaultDirectory.path) {
            try? fm.moveItem(at: oldDirectory, to: ClipboardStore.defaultDirectory)
        }

        let defaults = UserDefaults.standard
        if let bundleID = Bundle.main.bundleIdentifier,
           defaults.persistentDomain(forName: bundleID) == nil,
           let old = defaults.persistentDomain(forName: "in.f9x.NotchClip") {
            defaults.setPersistentDomain(old, forName: bundleID)
        }
    }
}
