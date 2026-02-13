#!/usr/bin/env swift
// generate-icon.swift — Create the ClawAPI app icon
// Uses the same shield.lefthalf.filled.badge.checkmark SF Symbol from the Welcome screen
// on a red gradient background (matching OpenClaw's red)

import Cocoa
import CoreGraphics

// OpenClaw-style red
let primaryRed = NSColor(red: 0.91, green: 0.22, blue: 0.22, alpha: 1.0)      // #E83838
let darkRed    = NSColor(red: 0.72, green: 0.12, blue: 0.12, alpha: 1.0)      // #B81F1F
let lightRed   = NSColor(red: 0.96, green: 0.40, blue: 0.35, alpha: 1.0)      // #F56659

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size

    // ── Background: rounded square (macOS icon shape) ──
    let inset = s * 0.08
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient fill: dark red at bottom → lighter red at top
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [darkRed.cgColor, primaryRed.cgColor, lightRed.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: s / 2, y: inset),
            end: CGPoint(x: s / 2, y: s - inset),
            options: []
        )
    }
    context.restoreGState()

    // ── Subtle border ──
    context.saveGState()
    context.addPath(bgPath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
    context.setLineWidth(s * 0.01)
    context.strokePath()
    context.restoreGState()

    // ── SF Symbol: shield.lefthalf.filled.badge.checkmark ──
    // This is the same symbol used on the Welcome/Start screen
    let symbolName = "shield.lefthalf.filled.badge.checkmark"
    let symbolSize = s * 0.52
    let pointSize = symbolSize

    // Create the symbol image with hierarchical rendering
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white, .white.withAlphaComponent(0.7)]))

    guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
        print("Failed to load SF Symbol: \(symbolName)")
        image.unlockFocus()
        return image
    }

    // Get the symbol's actual rendered size
    let symbolRep = symbolImage.representations.first
    let renderedWidth = symbolRep?.size.width ?? symbolSize
    let renderedHeight = symbolRep?.size.height ?? symbolSize

    // Center the symbol in the icon
    let symbolX = (s - renderedWidth) / 2
    let symbolY = (s - renderedHeight) / 2

    // Draw with shadow for depth
    context.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    shadow.shadowBlurRadius = s * 0.03
    shadow.set()

    symbolImage.draw(
        in: NSRect(x: symbolX, y: symbolY, width: renderedWidth, height: renderedHeight),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, size: Int, to path: String) {
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaFirst,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap rep for \(size)x\(size)")
        return
    }

    bitmapRep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for \(size)x\(size)")
        return
    }

    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("  Saved \(size)x\(size) → \(path)")
    } catch {
        print("  Error saving \(path): \(error)")
    }
}

// ── Main ──

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let iconsetDir = "\(scriptDir)/AppIcon.iconset"

try? FileManager.default.removeItem(atPath: iconsetDir)
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

print("Generating icon with shield.lefthalf.filled.badge.checkmark...")

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

let masterImage = drawIcon(size: 1024)

for entry in sizes {
    let path = "\(iconsetDir)/\(entry.name).png"
    savePNG(masterImage, size: entry.pixels, to: path)
}

print("Converting to .icns...")

let icnsPath = "\(scriptDir)/AppIcon.icns"
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", icnsPath, iconsetDir]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✓ Created \(icnsPath)")
    try? FileManager.default.removeItem(atPath: iconsetDir)
    print("✓ Cleaned up .iconset directory")
} else {
    print("✗ iconutil failed with status \(process.terminationStatus)")
}

// Also save a preview PNG
let previewDir = "/tmp/icon-preview"
try? FileManager.default.createDirectory(atPath: previewDir, withIntermediateDirectories: true)
savePNG(masterImage, size: 512, to: "\(previewDir)/icon.png")
print("✓ Preview saved to \(previewDir)/icon.png")
