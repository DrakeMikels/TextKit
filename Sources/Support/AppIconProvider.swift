import AppKit

enum AppIconProvider {
    static func applicationIconImage() -> NSImage {
        guard
            let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let image = NSImage(contentsOf: url)
        else {
            return fallbackApplicationIcon()
        }

        image.isTemplate = false
        return image
    }

    static func menuBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let lineColor = NSColor.labelColor
            let accentColor = NSColor.labelColor
            let lineHeight = rect.height * 0.12
            let lineCorner = lineHeight / 2
            let startX = rect.minX + rect.width * 0.10

            drawRoundedLine(
                in: NSRect(x: startX, y: rect.maxY - rect.height * 0.34, width: rect.width * 0.52, height: lineHeight),
                radius: lineCorner,
                color: lineColor
            )
            drawRoundedLine(
                in: NSRect(x: startX, y: rect.midY - lineHeight / 2, width: rect.width * 0.68, height: lineHeight),
                radius: lineCorner,
                color: lineColor
            )
            drawRoundedLine(
                in: NSRect(x: startX, y: rect.minY + rect.height * 0.22, width: rect.width * 0.46, height: lineHeight),
                radius: lineCorner,
                color: lineColor
            )

            drawSparkle(
                center: NSPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.28),
                arm: rect.width * 0.16,
                color: accentColor
            )
            return true
        }

        image.isTemplate = true
        return image
    }

    private static func fallbackApplicationIcon() -> NSImage {
        let image = NSImage(
            systemSymbolName: "text.quote",
            accessibilityDescription: "TextKit"
        ) ?? NSImage(size: NSSize(width: 512, height: 512))
        image.size = NSSize(width: 512, height: 512)
        image.isTemplate = false
        return image
    }

    private static func drawRoundedLine(in rect: NSRect, radius: CGFloat, color: NSColor) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: radius,
            yRadius: radius
        )
        color.setFill()
        path.fill()
    }

    private static func drawSparkle(center: NSPoint, arm: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x, y: center.y + arm))
        path.line(to: NSPoint(x: center.x + arm * 0.26, y: center.y + arm * 0.26))
        path.line(to: NSPoint(x: center.x + arm, y: center.y))
        path.line(to: NSPoint(x: center.x + arm * 0.26, y: center.y - arm * 0.26))
        path.line(to: NSPoint(x: center.x, y: center.y - arm))
        path.line(to: NSPoint(x: center.x - arm * 0.26, y: center.y - arm * 0.26))
        path.line(to: NSPoint(x: center.x - arm, y: center.y))
        path.line(to: NSPoint(x: center.x - arm * 0.26, y: center.y + arm * 0.26))
        path.close()
        color.setFill()
        path.fill()
    }
}
