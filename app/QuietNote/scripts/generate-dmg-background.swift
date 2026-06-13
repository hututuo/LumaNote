#!/usr/bin/env swift
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
let outputPath = args.indices.contains(0) ? args[0] : "support/dmg-background.png"

func numericArgument(_ index: Int, fallback: CGFloat) -> CGFloat {
    guard args.indices.contains(index), let value = Double(args[index]) else {
        return fallback
    }
    return CGFloat(value)
}

// Finder icon-view coordinates use the same logical units as AppleScript window
// bounds; the bitmap keeps that logical size while outputting Retina 2x pixels.
let canvasWidth = numericArgument(1, fallback: 840)
let canvasHeight = numericArgument(2, fallback: 600)
let pixelScale = max(0.25, numericArgument(3, fallback: 2))
let pixelWidth = max(1, Int((canvasWidth * pixelScale).rounded(.toNearestOrAwayFromZero)))
let pixelHeight = max(1, Int((canvasHeight * pixelScale).rounded(.toNearestOrAwayFromZero)))

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelWidth,
    pixelsHigh: pixelHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create bitmap")
}
bitmap.size = NSSize(width: canvasWidth, height: canvasHeight)

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create graphics context")
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xff) / 255
    let g = CGFloat((hex >> 8) & 0xff) / 255
    let b = CGFloat(hex & 0xff) / 255
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawText(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, align: NSTextAlignment = .left, lineHeight: CGFloat? = nil) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    text.draw(in: rect, withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

func drawCapsule(_ rect: NSRect, fill: NSColor, stroke: NSColor) {
    let path = roundedRect(rect, radius: rect.height / 2)
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func drawArrow(from start: CGPoint, to end: CGPoint) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(to: end, controlPoint1: CGPoint(x: start.x + 90, y: start.y + 34), controlPoint2: CGPoint(x: end.x - 110, y: end.y + 34))
    color(0x0F766E, 0.62).setStroke()
    path.lineWidth = 9
    path.lineCapStyle = .round
    path.stroke()

    let head = NSBezierPath()
    head.move(to: CGPoint(x: end.x - 28, y: end.y + 24))
    head.line(to: end)
    head.line(to: CGPoint(x: end.x - 30, y: end.y - 20))
    color(0x0F766E, 0.62).setStroke()
    head.lineWidth = 9
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    let shine = NSBezierPath()
    shine.move(to: CGPoint(x: start.x + 12, y: start.y + 10))
    shine.curve(to: CGPoint(x: end.x - 42, y: end.y + 8), controlPoint1: CGPoint(x: start.x + 92, y: start.y + 34), controlPoint2: CGPoint(x: end.x - 128, y: end.y + 33))
    NSColor.white.withAlphaComponent(0.42).setStroke()
    shine.lineWidth = 2
    shine.lineCapStyle = .round
    shine.stroke()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true

let bounds = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
let bg = NSGradient(colors: [
    color(0xF8FBFF),
    color(0xECF8F7),
    color(0xF7F2FF)
])!
bg.draw(in: bounds, angle: 135)

let baseWidth: CGFloat = 720
let baseHeight: CGFloat = 460
let contentScale = min(canvasWidth / baseWidth, canvasHeight / baseHeight)
let contentOffsetX = (canvasWidth - baseWidth * contentScale) / 2
let contentOffsetY = (canvasHeight - baseHeight * contentScale) / 2
context.cgContext.saveGState()
context.cgContext.translateBy(x: contentOffsetX, y: contentOffsetY)
context.cgContext.scaleBy(x: contentScale, y: contentScale)

for item in [
    (NSRect(x: -60, y: 250, width: 220, height: 220), color(0x7DD3FC, 0.18)),
    (NSRect(x: 560, y: 300, width: 230, height: 230), color(0xC4B5FD, 0.17)),
    (NSRect(x: 270, y: -90, width: 260, height: 210), color(0x5EEAD4, 0.14))
] {
    item.1.setFill()
    NSBezierPath(ovalIn: item.0).fill()
}

let mainPanel = roundedRect(NSRect(x: 34, y: 34, width: 652, height: 392), radius: 34)
NSColor.white.withAlphaComponent(0.48).setFill()
mainPanel.fill()
color(0xFFFFFF, 0.76).setStroke()
mainPanel.lineWidth = 1.4
mainPanel.stroke()

let innerPanel = roundedRect(NSRect(x: 54, y: 64, width: 612, height: 332), radius: 26)
NSColor.white.withAlphaComponent(0.30).setFill()
innerPanel.fill()
color(0x0F172A, 0.08).setStroke()
innerPanel.lineWidth = 1
innerPanel.stroke()

drawText("拖到右侧完成安装", rect: NSRect(x: 70, y: 342, width: 580, height: 28), size: 18, weight: .medium, color: color(0x334155, 0.72), align: .center)

let leftCard = roundedRect(NSRect(x: 98, y: 190, width: 170, height: 92), radius: 24)
NSColor.white.withAlphaComponent(0.36).setFill()
leftCard.fill()
color(0xFFFFFF, 0.8).setStroke()
leftCard.lineWidth = 1
leftCard.stroke()

let rightCard = roundedRect(NSRect(x: 452, y: 190, width: 170, height: 92), radius: 24)
NSColor.white.withAlphaComponent(0.36).setFill()
rightCard.fill()
color(0xFFFFFF, 0.8).setStroke()
rightCard.lineWidth = 1
rightCard.stroke()

drawArrow(from: CGPoint(x: 294, y: 236), to: CGPoint(x: 426, y: 236))

let warningRect = NSRect(x: 78, y: 66, width: 564, height: 88)
let warningPanel = roundedRect(warningRect, radius: 22)
color(0x0F172A, 0.06).setFill()
warningPanel.fill()
color(0xFFFFFF, 0.70).setStroke()
warningPanel.lineWidth = 1
warningPanel.stroke()

drawCapsule(NSRect(x: 100, y: 120, width: 90, height: 24), fill: color(0x0F766E, 0.13), stroke: color(0x0F766E, 0.18))
drawText("首次打开", rect: NSRect(x: 112, y: 124, width: 66, height: 17), size: 12, weight: .semibold, color: color(0x0F766E, 0.88), align: .center)

drawText("提示“未知开发者”时不要删除 App", rect: NSRect(x: 206, y: 122, width: 410, height: 20), size: 13.5, weight: .semibold, color: color(0x0F3B57, 0.86))
drawText("系统设置 → 隐私与安全 → 滑到最底下找到 LumaNote", rect: NSRect(x: 100, y: 94, width: 520, height: 20), size: 12.5, weight: .medium, color: color(0x334155, 0.76), align: .center)
drawText("点“仍要打开”，再确认“打开”", rect: NSRect(x: 100, y: 74, width: 520, height: 20), size: 12.5, weight: .medium, color: color(0x334155, 0.76), align: .center)

let textureColor = color(0xFFFFFF, 0.22)
for x in stride(from: 50, through: 670, by: 26) {
    textureColor.setStroke()
    let p = NSBezierPath()
    p.move(to: CGPoint(x: x, y: 56))
    p.line(to: CGPoint(x: x + 70, y: 420))
    p.lineWidth = 0.45
    p.stroke()
}

context.cgContext.restoreGState()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.95]) else {
    fatalError("Unable to render PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
