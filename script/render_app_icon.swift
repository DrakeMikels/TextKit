#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let iconsetURL = rootURL.appendingPathComponent("dist/AppIcon.iconset", isDirectory: true)

let iconSpecs: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for spec in iconSpecs {
    let image = renderIcon(size: spec.size)
    let destinationURL = iconsetURL.appendingPathComponent(spec.name)
    try writePNG(image: image, to: destinationURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    fputs("iconutil failed with status \(iconutil.terminationStatus)\n", stderr)
    exit(Int32(iconutil.terminationStatus))
}

private func renderIcon(size: Int) -> NSImage {
    let canvasSize = NSSize(width: size, height: size)

    return NSImage(size: canvasSize, flipped: false) { rect in
        let outerRect = rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02)
        let cornerRadius = rect.width * 0.23
        let outerPath = NSBezierPath(
            roundedRect: outerRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.37, blue: 0.58, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.67, blue: 0.73, alpha: 1),
        ])
        gradient?.draw(in: outerPath, angle: -44)

        let washPath = NSBezierPath(
            roundedRect: outerRect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05),
            xRadius: rect.width * 0.17,
            yRadius: rect.height * 0.17
        )
        NSColor.white.withAlphaComponent(0.065).setFill()
        washPath.fill()

        let glowRect = NSRect(
            x: outerRect.minX + rect.width * 0.10,
            y: outerRect.midY + rect.height * 0.10,
            width: outerRect.width - rect.width * 0.20,
            height: rect.height * 0.24
        )
        let glowPath = NSBezierPath(
            roundedRect: glowRect,
            xRadius: rect.width * 0.12,
            yRadius: rect.height * 0.12
        )
        NSColor.white.withAlphaComponent(0.12).setFill()
        glowPath.fill()

        NSColor.white.withAlphaComponent(0.12).setStroke()
        outerPath.lineWidth = max(2, rect.width * 0.022)
        outerPath.stroke()

        let chipRect = NSRect(
            x: rect.width * 0.18,
            y: rect.height * 0.20,
            width: rect.width * 0.64,
            height: rect.height * 0.60
        )
        let chipPath = NSBezierPath(
            roundedRect: chipRect,
            xRadius: rect.width * 0.16,
            yRadius: rect.height * 0.16
        )
        NSColor.white.withAlphaComponent(0.17).setFill()
        chipPath.fill()

        let innerChipPath = NSBezierPath(
            roundedRect: chipRect.insetBy(dx: rect.width * 0.025, dy: rect.height * 0.025),
            xRadius: rect.width * 0.13,
            yRadius: rect.height * 0.13
        )
        NSColor(calibratedWhite: 0.04, alpha: 0.20).setFill()
        innerChipPath.fill()

        let lineColor = NSColor.white.withAlphaComponent(0.96)
        let secondaryLineColor = NSColor.white.withAlphaComponent(0.82)
        let lineHeight = rect.height * 0.055
        let lineCorner = lineHeight / 2

        let textLine1 = NSBezierPath(
            roundedRect: NSRect(
                x: rect.width * 0.27,
                y: rect.height * 0.58,
                width: rect.width * 0.33,
                height: lineHeight
            ),
            xRadius: lineCorner,
            yRadius: lineCorner
        )
        lineColor.setFill()
        textLine1.fill()

        let textLine2 = NSBezierPath(
            roundedRect: NSRect(
                x: rect.width * 0.27,
                y: rect.height * 0.46,
                width: rect.width * 0.43,
                height: lineHeight
            ),
            xRadius: lineCorner,
            yRadius: lineCorner
        )
        secondaryLineColor.setFill()
        textLine2.fill()

        let textLine3 = NSBezierPath(
            roundedRect: NSRect(
                x: rect.width * 0.27,
                y: rect.height * 0.34,
                width: rect.width * 0.29,
                height: lineHeight
            ),
            xRadius: lineCorner,
            yRadius: lineCorner
        )
        secondaryLineColor.setFill()
        textLine3.fill()

        let accentCircleRect = NSRect(
            x: rect.width * 0.61,
            y: rect.height * 0.52,
            width: rect.width * 0.14,
            height: rect.width * 0.14
        )
        let accentCircle = NSBezierPath(ovalIn: accentCircleRect)
        NSColor(calibratedRed: 0.41, green: 0.98, blue: 0.88, alpha: 0.92).setFill()
        accentCircle.fill()

        drawSparkle(
            center: NSPoint(x: rect.width * 0.68, y: rect.height * 0.59),
            arm: rect.width * 0.037,
            color: NSColor(calibratedRed: 0.03, green: 0.16, blue: 0.23, alpha: 0.94)
        )

        return true
    }
}

private func drawSparkle(center: NSPoint, arm: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + arm))
    path.line(to: NSPoint(x: center.x + arm * 0.22, y: center.y + arm * 0.22))
    path.line(to: NSPoint(x: center.x + arm, y: center.y))
    path.line(to: NSPoint(x: center.x + arm * 0.22, y: center.y - arm * 0.22))
    path.line(to: NSPoint(x: center.x, y: center.y - arm))
    path.line(to: NSPoint(x: center.x - arm * 0.22, y: center.y - arm * 0.22))
    path.line(to: NSPoint(x: center.x - arm, y: center.y))
    path.line(to: NSPoint(x: center.x - arm * 0.22, y: center.y + arm * 0.22))
    path.close()
    color.setFill()
    path.fill()
}

private func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "TextKitIcon", code: 1)
    }

    try pngData.write(to: url)
}
