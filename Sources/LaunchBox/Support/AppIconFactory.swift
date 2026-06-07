import AppKit

enum AppIconFactory {
    static func dockIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let iconSize = size * 0.82
        let inset = (size - iconSize) / 2
        let rect = NSRect(x: inset, y: inset, width: iconSize, height: iconSize)
        let radius = iconSize * 0.22
        let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        NSGradient(colors: [
            NSColor(calibratedRed: 0.22, green: 0.74, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.28, green: 0.35, blue: 0.98, alpha: 1.0),
            NSColor(calibratedRed: 0.67, green: 0.33, blue: 0.95, alpha: 1.0)
        ])?.draw(in: background, angle: -35)

        NSColor.white.withAlphaComponent(0.26).setStroke()
        background.lineWidth = max(2, iconSize * 0.012)
        background.stroke()

        drawGrid(in: rect, color: .white, alpha: 0.92)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func menuBarIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        drawGrid(in: NSRect(x: 0, y: 0, width: size, height: size), color: .labelColor, alpha: 1.0)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawGrid(in rect: NSRect, color: NSColor, alpha: CGFloat) {
        let side = rect.width
        let cell = side * 0.15
        let gap = side * 0.095
        let total = cell * 3 + gap * 2
        let originX = rect.midX - total / 2
        let originY = rect.midY - total / 2

        color.withAlphaComponent(alpha).setFill()

        for row in 0..<3 {
            for column in 0..<3 {
                let x = originX + CGFloat(column) * (cell + gap)
                let y = originY + CGFloat(row) * (cell + gap)
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: y, width: cell, height: cell),
                    xRadius: cell * 0.28,
                    yRadius: cell * 0.28
                ).fill()
            }
        }
    }
}
