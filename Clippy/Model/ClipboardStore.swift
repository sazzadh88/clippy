import Foundation
import Observation

@MainActor @Observable
final class ClipboardStore {
    static let limitOptions = [50, 100, 200, 500]
    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Clippy", directoryHint: .isDirectory)
    }

    /// Newest first. Pinned items stay in this list; views split them into a section.
    private(set) var items: [ClipItem] = []
    /// Max number of unpinned items. Pinned items never count toward it.
    var limit: Int { didSet { enforceLimit() } }

    let directory: URL
    var historyURL: URL { directory.appending(path: "history.json") }
    var imagesURL: URL { directory.appending(path: "images", directoryHint: .isDirectory) }

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(directory: URL = ClipboardStore.defaultDirectory, limit: Int = 100) {
        self.directory = directory
        self.limit = limit
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Mutations

    func add(_ clip: CapturedClip, sourceBundleID: String? = nil, sourceName: String? = nil) {
        let hash = clip.contentHash
        if let existing = items.first(where: { $0.contentHash == hash }) {
            bump(id: existing.id)
            return
        }

        var item = ClipItem(kind: clip.kind, plainText: clip.plainText, rtfData: clip.rtfData,
                            fileURLs: clip.fileURLs, sourceAppBundleID: sourceBundleID,
                            sourceAppName: sourceName, contentHash: hash)
        if let png = clip.imagePNG {
            let name = "\(item.id.uuidString).png"
            do {
                try png.write(to: imagesURL.appending(path: name), options: .atomic)
                item.imageFileName = name
            } catch {
                return // can't keep an image item without its image
            }
        }
        items.insert(item, at: 0)
        enforceLimit()
        scheduleSave()
    }

    /// Moves an item to the top with a fresh timestamp.
    func bump(id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.createdAt = Date()
        items.insert(item, at: 0)
        scheduleSave()
    }

    func remove(id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        deleteImage(of: items.remove(at: index))
        scheduleSave()
    }

    func togglePin(id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        enforceLimit()
        scheduleSave()
    }

    /// Removes all unpinned items.
    func clear() {
        items.filter { !$0.isPinned }.forEach(deleteImage)
        items.removeAll { !$0.isPinned }
        scheduleSave()
    }

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFileName.map { imagesURL.appending(path: $0) }
    }

    private func enforceLimit() {
        var unpinned = 0
        var evicted: [ClipItem] = []
        items.removeAll { item in
            guard !item.isPinned else { return false }
            unpinned += 1
            guard unpinned > limit else { return false }
            evicted.append(item)
            return true
        }
        evicted.forEach(deleteImage)
        if !evicted.isEmpty { scheduleSave() }
    }

    private func deleteImage(of item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Persistence

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try JSONEncoder().encode(items).write(to: historyURL, options: .atomic)
        } catch {
            NSLog("Clippy: failed to save history: \(error)")
        }
    }

    private func load() {
        defer { removeOrphanedImages() }
        guard let data = try? Data(contentsOf: historyURL) else { return }
        do {
            items = try JSONDecoder().decode([ClipItem].self, from: data)
        } catch {
            // Keep the unreadable file instead of overwriting it on the next save.
            let backup = directory.appending(path: "history.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: historyURL, to: backup)
            NSLog("Clippy: history unreadable, moved to \(backup.lastPathComponent): \(error)")
        }
    }

    private func removeOrphanedImages() {
        let referenced = Set(items.compactMap(\.imageFileName))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesURL.path)) ?? []
        for name in files where !referenced.contains(name) {
            try? FileManager.default.removeItem(at: imagesURL.appending(path: name))
        }
    }
}
