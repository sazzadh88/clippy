import SwiftUI

@main
struct ClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Agent app: all UI lives in the menu bar dropdown and a manually managed settings window.
        Settings { EmptyView() }
    }
}
