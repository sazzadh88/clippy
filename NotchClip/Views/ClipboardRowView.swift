import AppKit
import ImageIO
import SwiftUI

struct ClipboardRowView: View {
    let item: ClipItem
    let now: Date
    let imageURL: URL?
    let onCopy: (_ plainTextOnly: Bool) -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(bundleID: item.sourceAppBundleID)
            ClipPreview(item: item, imageURL: imageURL)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(hovering ? 0.12 : 0.08))
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture { copy(plainTextOnly: false) }
        .contextMenu {
            Button("Copy") { copy(plainTextOnly: false) }
            Button("Copy as Plain Text") { copy(plainTextOnly: true) }
                .disabled(item.kind == .image)
            Button(item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder private var trailing: some View {
        ZStack(alignment: .trailing) {
            if copied {
                Label("Copied", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if hovering {
                HStack(spacing: 2) {
                    HeaderIconButton(systemName: item.isPinned ? "pin.slash" : "pin",
                                     help: item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
                    HeaderIconButton(systemName: "xmark", help: "Delete", action: onDelete)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 9))
                    }
                    Text(relativeTime(from: item.createdAt, to: now))
                        .font(.system(size: 10.5).monospacedDigit())
                }
                .foregroundStyle(.white.opacity(0.45))
                .transition(.opacity)
            }
        }
        .frame(minWidth: 52, alignment: .trailing)
    }

    private func copy(plainTextOnly: Bool) {
        onCopy(plainTextOnly)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.2)) { copied = false }
        }
    }
}

func relativeTime(from date: Date, to now: Date) -> String {
    let s = max(0, Int(now.timeIntervalSince(date)))
    switch s {
    case ..<60: return "now"
    case ..<3600: return "\(s / 60)m"
    case ..<86400: return "\(s / 3600)h"
    default: return "\(s / 86400)d"
    }
}

// MARK: - Previews per kind

private struct ClipPreview: View {
    let item: ClipItem
    let imageURL: URL?

    private static let primary = Color.white.opacity(0.9)
    private static let secondary = Color.white.opacity(0.45)

    var body: some View {
        switch item.kind {
        case .text, .richText:
            let text = item.plainText ?? ""
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(looksLikeCode(text) ? .system(size: 12, design: .monospaced) : .system(size: 12.5))
                .foregroundStyle(Self.primary)
                .lineLimit(2)
                .truncationMode(.tail)

        case .url:
            let url = URL(string: item.plainText ?? "")
            let rest = url.map { $0.path() + ($0.query().map { "?" + $0 } ?? "") } ?? ""
            (Text(url?.host() ?? item.plainText ?? "").fontWeight(.semibold).foregroundStyle(Self.primary)
             + Text(rest == "/" ? "" : rest).foregroundStyle(Self.secondary))
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)

        case .image:
            if let imageURL, let thumb = IconCache.thumbnail(for: imageURL) {
                HStack(spacing: 8) {
                    let aspect = thumb.pixelSize.width / max(thumb.pixelSize.height, 1)
                    Image(nsImage: thumb.image)
                        .resizable()
                        .frame(width: min(120, 44 * aspect), height: min(44, 120 / aspect))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("\(Int(thumb.pixelSize.width)) × \(Int(thumb.pixelSize.height))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Self.secondary)
                }
            } else {
                Text("Image unavailable").font(.system(size: 12)).foregroundStyle(Self.secondary)
            }

        case .file:
            let urls = item.fileURLs ?? []
            HStack(spacing: 6) {
                if let first = urls.first {
                    Image(nsImage: IconCache.fileIcon(path: first.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(first.lastPathComponent)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Self.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if urls.count > 1 {
                    Text("+\(urls.count - 1) more")
                        .font(.system(size: 11))
                        .foregroundStyle(Self.secondary)
                }
            }

        case .color:
            let hex = item.plainText ?? ""
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: PasteboardCodec.color(hex: hex) ?? .clear))
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    .frame(width: 22, height: 22)
                Text(hex)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Self.primary)
            }
        }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let markers = ["{", "}", ";", "=>", "->", "()", "</", "\t", "    "]
        return markers.contains { text.contains($0) }
    }
}

private struct AppIconView: View {
    let bundleID: String?
    var body: some View {
        Group {
            if let bundleID, let icon = IconCache.appIcon(bundleID: bundleID) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Caches (generated once, reused while scrolling)

@MainActor
enum IconCache {
    final class Thumbnail {
        let image: NSImage
        let pixelSize: CGSize
        init(image: NSImage, pixelSize: CGSize) { self.image = image; self.pixelSize = pixelSize }
    }

    private static let thumbnails = NSCache<NSURL, Thumbnail>()
    private static let icons = NSCache<NSString, NSImage>()

    /// Downsampled with ImageIO, so a 5K screenshot never gets decoded at full size.
    static func thumbnail(for url: URL) -> Thumbnail? {
        if let cached = thumbnails.object(forKey: url as NSURL) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 240,
              ] as CFDictionary)
        else { return nil }
        let thumb = Thumbnail(image: NSImage(cgImage: cg, size: .zero),
                              pixelSize: CGSize(width: width, height: height))
        thumbnails.setObject(thumb, forKey: url as NSURL)
        return thumb
    }

    static func appIcon(bundleID: String) -> NSImage? {
        let key = "app:\(bundleID)" as NSString
        if let cached = icons.object(forKey: key) { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons.setObject(icon, forKey: key)
        return icon
    }

    static func fileIcon(path: String) -> NSImage {
        let key = "file:\(path)" as NSString
        if let cached = icons.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons.setObject(icon, forKey: key)
        return icon
    }
}
