import SwiftUI
import Testing

@testable import MyCuKey

// In-process SwiftUI snapshot testing. ImageRenderer rasterizes a view so its
// pixels can be pinned against a committed reference under __Snapshots__/, no
// extension lifecycle and no external dependency. Run with SNAPSHOT_RECORD=1 to
// (re)write references; that run records an Issue so a left-on record mode can't
// mask a regression.

private enum Cfg {
    static let pixelMismatchRatio = 0.02  // channels allowed to differ
    static let channelTolerance = 12  // per-channel 0–255 delta treated as equal
    static let scale: CGFloat = 2
}

@MainActor
func assertSnapshot(
    of view: some View,
    size: CGSize,
    colorScheme: ColorScheme = .light,
    named name: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let data = renderPNG(of: view, size: size, colorScheme: colorScheme) else {
        Issue.record("could not render snapshot '\(name)'", sourceLocation: sourceLocation)
        return
    }

    let url = referenceURL(named: name)
    let recording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

    if recording || !FileManager.default.fileExists(atPath: url.path) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
        Issue.record(
            "recorded reference '\(name)'; re-run without SNAPSHOT_RECORD",
            sourceLocation: sourceLocation)
        return
    }

    guard let reference = try? Data(contentsOf: url) else {
        Issue.record("missing reference '\(name)'", sourceLocation: sourceLocation)
        return
    }

    if let diff = pixelDiff(data, reference) {
        try? data.write(to: url.deletingPathExtension().appendingPathExtension("failure.png"))
        Issue.record("snapshot '\(name)' differs (\(diff))", sourceLocation: sourceLocation)
    }
}

@MainActor
private func renderPNG(of view: some View, size: CGSize, colorScheme: ColorScheme) -> Data? {
    let renderer = ImageRenderer(
        content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme))
    renderer.scale = Cfg.scale
    renderer.proposedSize = ProposedViewSize(size)
    return renderer.uiImage?.pngData()
}

/// nil when images match within tolerance, else a human-readable reason.
private func pixelDiff(_ lhs: Data, _ rhs: Data) -> String? {
    guard let a = decodeRGBA(lhs), let b = decodeRGBA(rhs) else { return "undecodable" }
    guard a.w == b.w, a.h == b.h else { return "size \(a.w)x\(a.h) vs \(b.w)x\(b.h)" }

    var mismatched = 0
    for i in a.bytes.indices where abs(Int(a.bytes[i]) - Int(b.bytes[i])) > Cfg.channelTolerance {
        mismatched += 1
    }
    let ratio = a.bytes.isEmpty ? 0 : Double(mismatched) / Double(a.bytes.count)
    return ratio > Cfg.pixelMismatchRatio
        ? String(format: "%.2f%% of channels differ", ratio * 100) : nil
}

private func decodeRGBA(_ data: Data) -> (bytes: [UInt8], w: Int, h: Int)? {
    guard let image = UIImage(data: data)?.cgImage else { return nil }
    let w = image.width
    let h = image.height
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    guard
        let ctx = CGContext(
            data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (bytes, w, h)
}

private func referenceURL(named name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__/\(name).png")
}
