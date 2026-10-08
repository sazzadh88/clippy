import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchController = NotchWindowController()
    }
}
