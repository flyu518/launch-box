#!/usr/bin/env swift

import AppKit
import Foundation

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "generate_app_icon",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "\(executable) failed"]
        )
    }
}

func drawIcon(size: CGFloat) -> NSImage {
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

    NSColor.white.withAlphaComponent(0.24).setStroke()
    background.lineWidth = max(2, iconSize * 0.012)
    background.stroke()

    drawGrid(in: rect, size: iconSize)

    image.unlockFocus()
    return image
}

func drawGrid(in rect: NSRect, size: CGFloat) {
    let cell = size * 0.15
    let gap = size * 0.095
    let total = cell * 3 + gap * 2
    let originX = rect.midX - total / 2
    let originY = rect.midY - total / 2

    NSColor.white.withAlphaComponent(0.92).setFill()

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

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "generate_app_icon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"]
        )
    }

    try png.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift /path/to/AppIcon.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default
try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let tempDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("launch-box-icon-\(UUID().uuidString)", isDirectory: true)
let iconsetURL = tempDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: tempDirectory) }

let baseURL = tempDirectory.appendingPathComponent("base-1024.png")
try writePNG(drawIcon(size: 1024), to: baseURL)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in specs {
    try run(
        "/usr/bin/sips",
        [
            "-z",
            "\(size)",
            "\(size)",
            baseURL.path,
            "--out",
            iconsetURL.appendingPathComponent(filename).path
        ]
    )
}

try run(
    "/usr/bin/iconutil",
    [
        "-c",
        "icns",
        iconsetURL.path,
        "-o",
        outputURL.path
    ]
)
