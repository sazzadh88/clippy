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
}
