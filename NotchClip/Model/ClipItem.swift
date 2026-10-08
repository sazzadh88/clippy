import CryptoKit
import Foundation

enum ClipKind: String, Codable, Sendable {
    case file, image, url, richText, text, color
}

struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var kind: ClipKind
    /// Text, URL string, or color hex ("#RRGGBB"), depending on `kind`.
    var plainText: String?
    var rtfData: Data?
    var imageFileName: String?
    var fileURLs: [URL]?
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt = Date()
    var isPinned = false
    var contentHash: String
}

/// Content read from a pasteboard, before it becomes a stored `ClipItem`.
struct CapturedClip: Sendable {
    var kind: ClipKind
    var plainText: String?
    var rtfData: Data?
    var imagePNG: Data?
    var fileURLs: [URL]?

    /// Hash of the user-visible payload, so the same content copied from different apps
    /// (or as rich vs. plain text) dedupes to one item.
    var contentHash: String {
        var hasher = SHA256()
        switch kind {
        case .file: hasher.update(data: Data(("file:" + (fileURLs ?? []).map(\.path).joined(separator: "\n")).utf8))
        case .image: hasher.update(data: Data("image:".utf8)); hasher.update(data: imagePNG ?? Data())
        case .url: hasher.update(data: Data(("url:" + (plainText ?? "")).utf8))
        case .color: hasher.update(data: Data(("color:" + (plainText ?? "")).utf8))
        case .text, .richText: hasher.update(data: Data(("text:" + (plainText ?? "")).utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
