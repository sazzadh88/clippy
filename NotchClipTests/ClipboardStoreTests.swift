import Foundation
import Testing
@testable import NotchClip

@MainActor
struct ClipboardStoreTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "NotchClipTests-\(UUID().uuidString)")

    private func text(_ s: String) -> CapturedClip { CapturedClip(kind: .text, plainText: s) }
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])

    @Test func dedupeMovesExistingItemToTop() {
        let store = ClipboardStore(directory: dir)
        store.add(text("a"))
        store.add(text("b"))
        let originalA = store.items[1]
        store.add(text("a"))

        #expect(store.items.map(\.plainText) == ["a", "b"])
        #expect(store.items[0].id == originalA.id)
    }

    @Test func richAndPlainTextWithSameContentDedupe() {
        let store = ClipboardStore(directory: dir)
        store.add(CapturedClip(kind: .richText, plainText: "hi", rtfData: Data("{\\rtf1 hi}".utf8)))
        store.add(text("hi"))
        #expect(store.items.count == 1)
    }

    @Test func limitEvictsOldestUnpinnedAndSparesPinned() {
        let store = ClipboardStore(directory: dir, limit: 2)
        store.add(text("old-pinned"))
        store.togglePin(id: store.items[0].id)
        store.add(text("1"))
        store.add(text("2"))
        store.add(text("3"))

        #expect(store.items.map(\.plainText) == ["3", "2", "old-pinned"])
    }

    @Test func evictionDeletesImageFile() throws {
        let store = ClipboardStore(directory: dir, limit: 1)
        store.add(CapturedClip(kind: .image, imagePNG: png))
        let imageURL = try #require(store.imageURL(for: store.items[0]))
        #expect(FileManager.default.fileExists(atPath: imageURL.path))

        store.add(text("evicts the image"))
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test func clearKeepsPinned() {
        let store = ClipboardStore(directory: dir)
        store.add(text("pinned"))
        store.togglePin(id: store.items[0].id)
        store.add(text("gone"))
        store.clear()
        #expect(store.items.map(\.plainText) == ["pinned"])
    }

    @Test func persistenceRoundTrip() throws {
        let store = ClipboardStore(directory: dir)
        store.add(text("hello"), sourceBundleID: "com.apple.TextEdit", sourceName: "TextEdit")
        store.add(CapturedClip(kind: .file, fileURLs: [URL(filePath: "/tmp/a.txt")]))
        store.add(CapturedClip(kind: .image, imagePNG: png))
        store.togglePin(id: store.items[2].id)
        store.saveNow()

        let reloaded = ClipboardStore(directory: dir)
        #expect(reloaded.items == store.items)
        let imageURL = try #require(reloaded.imageURL(for: reloaded.items[0]))
        #expect(try Data(contentsOf: imageURL) == png)
    }

    @Test func corruptHistoryIsBackedUpNotOverwritten() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appending(path: "history.json"))
        let store = ClipboardStore(directory: dir)
        #expect(store.items.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("history.corrupt-") })
    }
}
