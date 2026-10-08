import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@MainActor @Observable
final class AppSettings {
    static let defaultIgnoredBundleIDs = [
        "com.1password.1password", "com.agilebits.onepassword7", // 1Password 8 / 7
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
    ]

    @ObservationIgnored private let defaults: UserDefaults

    var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: "historyLimit") } }
    var closeAfterCopy: Bool { didSet { defaults.set(closeAfterCopy, forKey: "closeAfterCopy") } }
    var ignoredBundleIDs: [String] { didSet { defaults.set(ignoredBundleIDs, forKey: "ignoredBundleIDs") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let limit = defaults.integer(forKey: "historyLimit")
        historyLimit = ClipboardStore.limitOptions.contains(limit) ? limit : 100
        closeAfterCopy = defaults.object(forKey: "closeAfterCopy") as? Bool ?? true
        ignoredBundleIDs = defaults.stringArray(forKey: "ignoredBundleIDs") ?? Self.defaultIgnoredBundleIDs
    }
}
