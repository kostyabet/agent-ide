#!/usr/bin/env swift
// Generates Resources/AppIcon.icns with no external assets: a dark "mixing console"
// (пульт) — three channel faders with coloured tracks and capped knobs — so the app
// is easy to spot in Finder/Spotlight/Launchpad.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
let icns = root.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: a)
}
func squircle(_ r: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: r.width*0.225, yRadius: r.width*0.225)
}
func rr(_ r: NSRect, _ rad: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad) }
func withShadow(blur: CGFloat, dy: CGFloat, alpha: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: alpha)
    sh.shadowBlurRadius = blur; sh.shadowOffset = NSSize(width: 0, height: dy); sh.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func drawIcon(in r: NSRect) {
    let sq = squircle(r)
    // slate gradient background
    NSGradient(colors: [rgb(44,49,61), rgb(20,23,30)])!.draw(in: sq, angle: -90)
    // glossy top light
    NSGraphicsContext.saveGraphicsState()
    sq.addClip()
    NSGradient(colors: [NSColor(white: 1, alpha: 0.20), NSColor(white: 1, alpha: 0)])!
        .draw(in: NSRect(x: r.minX, y: r.midY, width: r.width, height: r.height/2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // three channel faders
    let colGap = r.width*0.24, startX = r.midX - colGap
    let trackH = r.height*0.56, trackW = r.width*0.045
    let capW = r.width*0.17, capH = r.height*0.055
    let pos: [CGFloat] = [0.74, 0.34, 0.56]
    let colors = [rgb(80,205,255), rgb(110,235,150), rgb(255,180,70)]
    for k in 0..<3 {
        let cx = startX + CGFloat(k)*colGap
        let bottom = r.midY - trackH/2
        rgb(0,0,0,0.35).setFill()
        rr(NSRect(x: cx-trackW/2, y: bottom, width: trackW, height: trackH), trackW*0.5).fill()
        let ky = bottom + trackH*pos[k]
        colors[k].setFill()
        rr(NSRect(x: cx-trackW/2, y: bottom, width: trackW, height: ky-bottom), trackW*0.5).fill()
        withShadow(blur: r.width*0.03, dy: -r.width*0.01, alpha: 0.4) {
            rgb(238,241,247).setFill()
            rr(NSRect(x: cx-capW/2, y: ky-capH/2, width: capW, height: capH), capH*0.3).fill()
        }
        rgb(255,255,255,0.5).setFill()
        rr(NSRect(x: cx-capW/2, y: ky+capH*0.08, width: capW, height: capH*0.34), capH*0.2).fill()
    }
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), inset = s*0.10
    drawIcon(in: NSRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset))
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
