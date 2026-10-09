import Foundation
import Testing
@testable import Clippy

@MainActor
struct ClipboardStoreTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "ClippyTests-\(UUID().uuidString)")

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

    @Test func searchMatchesTextFileNamesAndSourceApp() {
        let text = ClipItem(kind: .text, plainText: "Hello World", sourceAppName: "Notes", contentHash: "")
        let file = ClipItem(kind: .file, fileURLs: [URL(filePath: "/tmp/Report.PDF")], contentHash: "")
        #expect(text.matches("hello"))
        #expect(text.matches("NOTES"))
        #expect(!text.matches("report"))
        #expect(file.matches("report.pdf"))
        #expect(!file.matches("tmp")) // only the file name, not the full path
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

struct PopupPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let size = CGSize(width: 420, height: 480)

    @Test func belowCaretLeftAligned() {
        let origin = MenuBarController.popupOrigin(anchor: CGRect(x: 100, y: 700, width: 2, height: 16), size: size, visible: visible)
        #expect(origin == CGPoint(x: 100, y: 700 - 6 - 480))
    }

    @Test func flipsAboveWhenNoRoomBelow() {
        let origin = MenuBarController.popupOrigin(anchor: CGRect(x: 100, y: 100, width: 2, height: 16), size: size, visible: visible)
        #expect(origin == CGPoint(x: 100, y: 100 + 16 + 6))
    }

    @Test func staysOnScreenAtRightEdgeAndTop() {
        let origin = MenuBarController.popupOrigin(anchor: CGRect(x: 990, y: 300, width: 2, height: 16), size: size, visible: visible)
        // No room below → flips above (y 322), then clamped so the top stays on screen (800 - 480).
        #expect(origin == CGPoint(x: 1000 - 420 - 8, y: 800 - 480))
    }

    @Test func axRectFlipsToCocoa() {
        let r = Paster.cocoaRect(fromAX: CGRect(x: 10, y: 100, width: 2, height: 20), primaryScreenHeight: 900)
        #expect(r == CGRect(x: 10, y: 780, width: 2, height: 20))
    }
}
