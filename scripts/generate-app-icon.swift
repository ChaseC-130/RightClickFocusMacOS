#!/usr/bin/env swift

import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output.iconset>\n", stderr)
    Foundation.exit(1)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSpecs: [(name: String, pixels: Int)] = [
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

for spec in iconSpecs {
    let image = makeIcon(pixels: spec.pixels)
    let url = iconsetURL.appendingPathComponent(spec.name)
    try writePNG(image, to: url)
}

func makeIcon(pixels: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Could not create icon graphics context.\n", stderr)
        Foundation.exit(1)
    }

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels))
    context.clear(canvas)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels), y: CGFloat(pixels))

    let iconRect = CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
    let roundedRect = CGPath(
        roundedRect: iconRect,
        cornerWidth: 0.22,
        cornerHeight: 0.22,
        transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -0.025),
        blur: 0.055,
        color: cgColor(0x000000, alpha: 0.28)
    )
    context.addPath(roundedRect)
    context.setFillColor(cgColor(0x0B1020, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect)
    context.clip()

    let backgroundGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            cgColor(0x38D996, alpha: 1),
            cgColor(0x1E7CFF, alpha: 1),
            cgColor(0x18213A, alpha: 1)
        ] as CFArray,
        locations: [0.0, 0.52, 1.0]
    )!
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: 0.08, y: 0.94),
        end: CGPoint(x: 0.92, y: 0.05),
        options: []
    )

    context.setFillColor(cgColor(0xFFFFFF, alpha: 0.13))
    context.fillEllipse(in: CGRect(x: -0.12, y: 0.62, width: 0.62, height: 0.42))
    context.setFillColor(cgColor(0xFFFFFF, alpha: 0.08))
    context.fillEllipse(in: CGRect(x: 0.55, y: -0.08, width: 0.56, height: 0.38))

    context.restoreGState()

    drawFocusRings(in: context)
    drawCursor(in: context)

    guard let image = context.makeImage() else {
        fputs("Could not create final icon image.\n", stderr)
        Foundation.exit(1)
    }

    return image
}

func drawFocusRings(in context: CGContext) {
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -0.012),
        blur: 0.02,
        color: cgColor(0x000000, alpha: 0.24)
    )

    let center = CGPoint(x: 0.68, y: 0.62)

    context.setStrokeColor(cgColor(0xFFFFFF, alpha: 0.88))
    context.setLineWidth(0.036)
    context.strokeEllipse(in: CGRect(x: center.x - 0.16, y: center.y - 0.16, width: 0.32, height: 0.32))

    context.setStrokeColor(cgColor(0xD7FFF0, alpha: 0.96))
    context.setLineWidth(0.018)
    context.strokeEllipse(in: CGRect(x: center.x - 0.083, y: center.y - 0.083, width: 0.166, height: 0.166))

    context.setFillColor(cgColor(0xFFFFFF, alpha: 0.94))
    context.fillEllipse(in: CGRect(x: center.x - 0.027, y: center.y - 0.027, width: 0.054, height: 0.054))
    context.restoreGState()
}

func drawCursor(in context: CGContext) {
    let cursor = CGMutablePath()
    cursor.move(to: CGPoint(x: 0.29, y: 0.78))
    cursor.addLine(to: CGPoint(x: 0.29, y: 0.25))
    cursor.addLine(to: CGPoint(x: 0.43, y: 0.39))
    cursor.addLine(to: CGPoint(x: 0.51, y: 0.19))
    cursor.addLine(to: CGPoint(x: 0.62, y: 0.24))
    cursor.addLine(to: CGPoint(x: 0.54, y: 0.45))
    cursor.addLine(to: CGPoint(x: 0.75, y: 0.45))
    cursor.closeSubpath()

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0.012, height: -0.018),
        blur: 0.025,
        color: cgColor(0x000000, alpha: 0.34)
    )
    context.addPath(cursor)
    context.setFillColor(cgColor(0xFFFFFF, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(cursor)
    context.setStrokeColor(cgColor(0x10213D, alpha: 0.22))
    context.setLineWidth(0.012)
    context.strokePath()
    context.restoreGState()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

func cgColor(_ hex: Int, alpha: CGFloat) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255.0,
        green: CGFloat((hex >> 8) & 0xFF) / 255.0,
        blue: CGFloat(hex & 0xFF) / 255.0,
        alpha: alpha
    )
}
