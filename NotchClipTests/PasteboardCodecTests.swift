import AppKit
import Testing
@testable import NotchClip

@MainActor
struct PasteboardCodecTests {
    /// Private pasteboard, so tests never touch the user's clipboard.
    let pb = NSPasteboard.withUniqueName()

    private func tinyPNG() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func plainText() {
        pb.clearContents()
        pb.setString("hello", forType: .string)
        let clip = PasteboardCodec.read(pb)
        #expect(clip?.kind == .text)
        #expect(clip?.plainText == "hello")
    }

    @Test func whitespaceOnlyIsIgnored() {
        pb.clearContents()
        pb.setString("  \n\t ", forType: .string)
        #expect(PasteboardCodec.read(pb) == nil)
    }

    @Test func oversizedTextIsIgnored() {
        pb.clearContents()
        pb.setString(String(repeating: "a", count: PasteboardCodec.maxTextBytes + 1), forType: .string)
        #expect(PasteboardCodec.read(pb) == nil)
    }

    @Test func concealedTypeIsSkipped() {
        pb.clearContents()
        pb.setString("hunter2", forType: .string)
        pb.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        #expect(PasteboardCodec.read(pb) == nil)
    }

    @Test func richTextKeepsRTFAndShowsPlain() {
        let rtf = NSAttributedString(string: "bold").rtf(from: NSRange(location: 0, length: 4), documentAttributes: [:])!
        pb.clearContents()
        pb.setData(rtf, forType: .rtf)
        let clip = PasteboardCodec.read(pb)
        #expect(clip?.kind == .richText)
        #expect(clip?.plainText == "bold")
        #expect(clip?.rtfData == rtf)
    }

    @Test func urlTypeAndBareURLText() {
        pb.clearContents()
        pb.setString("https://example.com/a", forType: .URL)
        #expect(PasteboardCodec.read(pb)?.kind == .url)

        pb.clearContents()
        pb.setString("  https://example.com/b?q=1 ", forType: .string)
        #expect(PasteboardCodec.read(pb)?.plainText == "https://example.com/b?q=1")

        pb.clearContents()
        pb.setString("see https://example.com", forType: .string)
        #expect(PasteboardCodec.read(pb)?.kind == .text)
    }

    @Test func fileURLsWinOverEverything() {
        pb.clearContents()
        pb.writeObjects([URL(filePath: "/tmp/a.txt"), URL(filePath: "/tmp/b.txt")] as [NSURL])
        pb.setString("a.txt", forType: .string)
        let clip = PasteboardCodec.read(pb)
        #expect(clip?.kind == .file)
        #expect(clip?.fileURLs?.count == 2)
    }

    @Test func imageWinsOverText() {
        pb.clearContents()
        pb.setData(tinyPNG(), forType: .png)
        pb.setString("caption", forType: .string)
        #expect(PasteboardCodec.read(pb)?.kind == .image)
    }

    @Test func tiffIsConvertedToPNG() throws {
        let tiff = try #require(NSImage(data: tinyPNG())?.tiffRepresentation)
        pb.clearContents()
        pb.setData(tiff, forType: .tiff)
        let png = try #require(PasteboardCodec.read(pb)?.imagePNG)
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func color() {
        pb.clearContents()
        pb.writeObjects([NSColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1)])
        let clip = PasteboardCodec.read(pb)
        #expect(clip?.kind == .color)
        #expect(clip?.plainText == "#FF8000")
    }

    @Test func writeRoundTripsEveryKind() {
        let items: [ClipItem] = [
            ClipItem(kind: .text, plainText: "t", contentHash: ""),
            ClipItem(kind: .url, plainText: "https://example.com", contentHash: ""),
            ClipItem(kind: .color, plainText: "#112233", contentHash: ""),
            ClipItem(kind: .file, fileURLs: [URL(filePath: "/tmp/x")], contentHash: ""),
        ]
        for item in items {
            PasteboardCodec.write(item, imageData: nil, to: pb)
            let back = PasteboardCodec.read(pb)
            #expect(back?.kind == item.kind)
            if item.kind != .file { #expect(back?.plainText == item.plainText) }
        }
    }

    @Test func plainTextOnlyStripsRTF() {
        let item = ClipItem(kind: .richText, plainText: "x", rtfData: Data("{\\rtf1 x}".utf8), contentHash: "")
        PasteboardCodec.write(item, imageData: nil, plainTextOnly: true, to: pb)
        #expect(pb.data(forType: .rtf) == nil)
        #expect(pb.string(forType: .string) == "x")
    }
}
