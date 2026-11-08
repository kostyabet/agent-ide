#!/usr/bin/env swift
// Generates Resources/AppIcon.icns with no external assets: a rounded "squircle"
// with a deck-of-cards glyph, so the app is easy to spot in Finder/Spotlight/Launchpad.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
let icns = root.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // Rounded-rect background with a deep indigo→teal gradient (macOS icon grid inset).
    let inset = s * 0.10
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.55, blue: 0.56, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    // Three stacked "cards".
    let cardW = rect.width * 0.52
    let cardH = rect.height * 0.14
    let cx = rect.midX - cardW / 2
    let cys: [CGFloat] = [rect.midY + rect.height * 0.14,
                          rect.midY - rect.height * 0.02,
                          rect.midY - rect.height * 0.18]
    let alphas: [CGFloat] = [0.55, 0.78, 1.0]
    for (cy, a) in zip(cys, alphas) {
        let card = NSBezierPath(roundedRect: NSRect(x: cx, y: cy, width: cardW, height: cardH),
                                xRadius: cardH * 0.35, yRadius: cardH * 0.35)
        NSColor(white: 1, alpha: a).setFill()
        card.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
] {
    try! render(px).write(to: iconset.appendingPathComponent("\(name).png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("→ wrote \(icns.path)")
