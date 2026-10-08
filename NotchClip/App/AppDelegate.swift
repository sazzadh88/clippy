import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var store: ClipboardStore?
    private var monitor: PasteboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run hosted in the app; don't touch the real clipboard or history.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let store = ClipboardStore()
        let monitor = PasteboardMonitor(store: store)
        monitor.start()
        self.store = store
        self.monitor = monitor
        notchController = NotchWindowController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.saveNow()
    }
}
