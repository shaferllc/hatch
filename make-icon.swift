#!/usr/bin/env swift
// Generates AppIcon.icns: an open deck hatch on a night-blue squircle with
// warm light pouring out of the opening.
// Usage: swift make-icon.swift  (run from the hatch dir)

import AppKit
import Foundation

let here    = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = here.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func makePNG(size px: Int) -> Data? {
    let pf = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)
    else { return nil }
    rep.size = NSSize(width: pf, height: pf)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx

    // Squircle background: deep night-sea blue.
    let radius = pf * 0.225
    let squircle = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: pf, height: pf),
                                xRadius: radius, yRadius: radius)
    squircle.addClip()
    NSGradient(colors: [
        NSColor(red: 0.10, green: 0.22, blue: 0.34, alpha: 1),   // top: slate teal
        NSColor(red: 0.03, green: 0.08, blue: 0.16, alpha: 1),   // bottom: near-black navy
    ])!.draw(in: NSRect(x: 0, y: 0, width: pf, height: pf), angle: -90)

    // Isometric hatch opening: a 2:1 diamond low on the deck.
    let cx = pf * 0.50
    let cy = pf * 0.34
    let hw = pf * 0.30            // half-width of the diamond
    let hh = hw * 0.52            // half-height (iso squash)
    let top    = NSPoint(x: cx,      y: cy + hh)
    let right  = NSPoint(x: cx + hw, y: cy)
    let bottom = NSPoint(x: cx,      y: cy - hh)
    let left   = NSPoint(x: cx - hw, y: cy)

    // Light beam rising from the opening, fading with height.
    let beam = NSBezierPath()
    beam.move(to: NSPoint(x: cx - hw * 0.80, y: cy + hh * 0.30))
    beam.line(to: NSPoint(x: cx - hw * 1.18, y: pf * 0.86))
    beam.line(to: NSPoint(x: cx + hw * 1.18, y: pf * 0.86))
    beam.line(to: NSPoint(x: cx + hw * 0.80, y: cy + hh * 0.30))
    beam.close()
    NSGraphicsContext.saveGraphicsState()
    beam.addClip()
    NSGradient(colors: [
        NSColor(red: 1.00, green: 0.88, blue: 0.55, alpha: 0.55),
        NSColor(red: 1.00, green: 0.90, blue: 0.60, alpha: 0.0),
    ])!.draw(in: beam.bounds, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Soft glow around the opening.
    let glow = NSBezierPath()
    glow.move(to: NSPoint(x: cx, y: cy + hh * 1.9))
    glow.line(to: NSPoint(x: cx + hw * 1.45, y: cy))
    glow.line(to: NSPoint(x: cx, y: cy - hh * 1.9))
    glow.line(to: NSPoint(x: cx - hw * 1.45, y: cy))
    glow.close()
    NSColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 0.16).setFill()
    glow.fill()

    // The opening itself: bright warm light.
    let opening = NSBezierPath()
    opening.move(to: top); opening.line(to: right)
    opening.line(to: bottom); opening.line(to: left)
    opening.close()
    NSGraphicsContext.saveGraphicsState()
    opening.addClip()
    NSGradient(colors: [
        NSColor(red: 1.00, green: 0.98, blue: 0.90, alpha: 1),   // hot center-top
        NSColor(red: 1.00, green: 0.76, blue: 0.32, alpha: 1),   // amber bottom
    ])!.draw(in: opening.bounds, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Coaming (raised rim) around the opening.
    let rim = NSBezierPath()
    rim.move(to: top); rim.line(to: right)
    rim.line(to: bottom); rim.line(to: left)
    rim.close()
    rim.lineWidth = max(1, pf * 0.018)
    rim.lineJoinStyle = .round
    NSColor(red: 0.55, green: 0.68, blue: 0.78, alpha: 0.9).setStroke()
    rim.stroke()

    // Open lid: hinged on the upper-left edge (left→top), swung up and back.
    let lift = NSPoint(x: -hw * 0.52, y: hh * 2.9)
    let lid = NSBezierPath()
    lid.move(to: left)
    lid.line(to: top)
    lid.line(to: NSPoint(x: top.x + lift.x, y: top.y + lift.y))
    lid.line(to: NSPoint(x: left.x + lift.x, y: left.y + lift.y))
    lid.close()
    NSGraphicsContext.saveGraphicsState()
    lid.addClip()
    NSGradient(colors: [
        NSColor(red: 0.62, green: 0.74, blue: 0.83, alpha: 1),   // lit underside near opening
        NSColor(red: 0.30, green: 0.42, blue: 0.54, alpha: 1),
    ])!.draw(in: lid.bounds, angle: 155)
    NSGraphicsContext.restoreGraphicsState()
    lid.lineWidth = max(1, pf * 0.014)
    lid.lineJoinStyle = .round
    NSColor(red: 0.75, green: 0.84, blue: 0.90, alpha: 0.9).setStroke()
    lid.stroke()

    // Two plank lines on the lid for texture (skip at tiny sizes).
    if px >= 64 {
        for t in [0.38, 0.68] {
            let f = CGFloat(t)
            let a = NSPoint(x: left.x + lift.x * f, y: left.y + lift.y * f)
            let b = NSPoint(x: top.x + lift.x * f, y: top.y + lift.y * f)
            let plank = NSBezierPath()
            plank.move(to: a); plank.line(to: b)
            plank.lineWidth = max(0.5, pf * 0.006)
            NSColor(red: 0.16, green: 0.26, blue: 0.36, alpha: 0.7).setStroke()
            plank.stroke()
        }
    }

    return rep.representation(using: .png, properties: [:])
}

for (name, px) in sizes {
    guard let data = makePNG(size: px) else { continue }
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path,
                  "-o", here.appendingPathComponent("AppIcon.icns").path]
try proc.run()
proc.waitUntilExit()
print("Wrote AppIcon.icns")
