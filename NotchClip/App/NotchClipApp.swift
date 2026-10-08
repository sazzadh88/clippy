import SwiftUI

@main
struct NotchClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Agent app: all UI lives in the notch panel and a manually managed settings window.
        Settings { EmptyView() }
    }
}
