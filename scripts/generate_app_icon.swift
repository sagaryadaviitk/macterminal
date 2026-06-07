import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let pngURL = resources.appendingPathComponent("MacTerminal-1024.png")
let iconsetURL = resources.appendingPathComponent("MacTerminal.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawLine(points: [NSPoint], color: NSColor, width: CGFloat, lineCap: NSBezierPath.LineCapStyle = .round) {
    guard let first = points.first else {
        return
    }
    let path = NSBezierPath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.lineWidth = width
    path.lineCapStyle = lineCap
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

image.lockFocus()

NSGraphicsContext.current?.imageInterpolation = .high

let canvas = NSRect(origin: .zero, size: size)
let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.shadowBlurRadius = 52
shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
shadow.set()

drawRoundedRect(
    NSRect(x: 66, y: 54, width: 892, height: 916),
    radius: 205,
    fill: color(0x151b22),
    stroke: color(0x3c4651, alpha: 0.7),
    lineWidth: 8
)

NSShadow().set()

let body = NSRect(x: 116, y: 122, width: 792, height: 788)
drawRoundedRect(body, radius: 132, fill: color(0x10151b), stroke: color(0x55606b, alpha: 0.45), lineWidth: 5)

let titlebar = NSRect(x: 116, y: 742, width: 792, height: 168)
NSGraphicsContext.current?.saveGraphicsState()
let titlePath = NSBezierPath(roundedRect: titlebar, xRadius: 132, yRadius: 132)
titlePath.addClip()
color(0x25303a).setFill()
titlebar.fill()
NSBezierPath(rect: NSRect(x: 116, y: 742, width: 792, height: 78)).fill()
NSGraphicsContext.current?.restoreGraphicsState()

for (x, c) in [(202.0, 0xff5f57 as UInt32), (270.0, 0xffbd2e as UInt32), (338.0, 0x28c840 as UInt32)] {
    color(c).setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: 803, width: 36, height: 36)).fill()
}

let paneStroke = color(0x47515c, alpha: 0.65)
drawLine(points: [NSPoint(x: 512, y: 186), NSPoint(x: 512, y: 720)], color: paneStroke, width: 9, lineCap: .butt)
drawLine(points: [NSPoint(x: 550, y: 452), NSPoint(x: 848, y: 452)], color: paneStroke, width: 9, lineCap: .butt)

drawRoundedRect(NSRect(x: 166, y: 184, width: 296, height: 506), radius: 42, fill: color(0x0c1116), stroke: color(0x2d3741), lineWidth: 4)
drawRoundedRect(NSRect(x: 562, y: 498, width: 286, height: 192), radius: 42, fill: color(0x0c1116), stroke: color(0x2d3741), lineWidth: 4)
drawRoundedRect(NSRect(x: 562, y: 184, width: 286, height: 214), radius: 42, fill: color(0x0c1116), stroke: color(0x2d3741), lineWidth: 4)

let glow = NSShadow()
glow.shadowOffset = .zero
glow.shadowBlurRadius = 30
glow.shadowColor = color(0x35f28a, alpha: 0.52)
glow.set()
drawLine(points: [NSPoint(x: 222, y: 564), NSPoint(x: 310, y: 498), NSPoint(x: 222, y: 432)], color: color(0x45f58d), width: 48)
drawLine(points: [NSPoint(x: 334, y: 412), NSPoint(x: 424, y: 412)], color: color(0x7af7ff), width: 42)

NSShadow().set()
drawLine(points: [NSPoint(x: 620, y: 626), NSPoint(x: 674, y: 568), NSPoint(x: 728, y: 626), NSPoint(x: 804, y: 568)], color: color(0x8ed1ff), width: 24)
drawLine(points: [NSPoint(x: 620, y: 316), NSPoint(x: 728, y: 316), NSPoint(x: 728, y: 262), NSPoint(x: 804, y: 262)], color: color(0x45f58d), width: 24)

let highlight = NSBezierPath()
highlight.move(to: NSPoint(x: 236, y: 904))
highlight.curve(to: NSPoint(x: 800, y: 882), controlPoint1: NSPoint(x: 360, y: 962), controlPoint2: NSPoint(x: 640, y: 950))
highlight.lineWidth = 9
highlight.lineCapStyle = .round
color(0xffffff, alpha: 0.14).setStroke()
highlight.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon PNG")
}
try png.write(to: pngURL)

let iconSizes: [(name: String, pixels: Int)] = [
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

for iconSize in iconSizes {
    let scaled = NSImage(size: NSSize(width: iconSize.pixels, height: iconSize.pixels))
    scaled.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: iconSize.pixels, height: iconSize.pixels), from: canvas, operation: .copy, fraction: 1)
    scaled.unlockFocus()

    guard let tiff = scaled.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(iconSize.name)")
    }
    try png.write(to: iconsetURL.appendingPathComponent(iconSize.name))
}

print(pngURL.path)
