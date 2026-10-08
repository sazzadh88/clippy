import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    /// True when the user must approve the login item in System Settings › General › Login Items.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Throws if the system refuses (e.g. the app isn't in /Applications or isn't signed).
    static func set(_ enabled: Bool) throws {
        enabled ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
    }
}
