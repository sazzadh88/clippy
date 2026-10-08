import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@MainActor @Observable
final class AppSettings {
    enum DisplayChoice: String, CaseIterable, Identifiable {
        case builtIn, mouse
        var id: Self { self }
        var title: String { self == .builtIn ? "Built-in display" : "Display with mouse" }
    }

    static let defaultIgnoredBundleIDs = [
        "com.1password.1password", "com.agilebits.onepassword7", // 1Password 8 / 7
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
    ]

    @ObservationIgnored private let defaults: UserDefaults

    var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: "historyLimit") } }
    var collapseAfterCopy: Bool { didSet { defaults.set(collapseAfterCopy, forKey: "collapseAfterCopy") } }
    var displayChoice: DisplayChoice { didSet { defaults.set(displayChoice.rawValue, forKey: "displayChoice") } }
    var ignoredBundleIDs: [String] { didSet { defaults.set(ignoredBundleIDs, forKey: "ignoredBundleIDs") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let limit = defaults.integer(forKey: "historyLimit")
        historyLimit = ClipboardStore.limitOptions.contains(limit) ? limit : 100
        collapseAfterCopy = defaults.object(forKey: "collapseAfterCopy") as? Bool ?? true
        displayChoice = defaults.string(forKey: "displayChoice").flatMap(DisplayChoice.init) ?? .builtIn
        ignoredBundleIDs = defaults.stringArray(forKey: "ignoredBundleIDs") ?? Self.defaultIgnoredBundleIDs
    }
}
