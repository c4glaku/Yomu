import AppKit

// A simple code-drawn placeholder emblem. Replace with the user's artwork later.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.96, green: 0.32, blue: 0.16, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor(srgbRed: 1, green: 0.96, blue: 0.89, alpha: 1).setFill()
let left = NSBezierPath()
left.move(to: NSPoint(x: 215, y: 724))
left.curve(to: NSPoint(x: 484, y: 670), controlPoint1: NSPoint(x: 330, y: 748), controlPoint2: NSPoint(x: 412, y: 720))
left.line(to: NSPoint(x: 484, y: 295))
left.curve(to: NSPoint(x: 215, y: 345), controlPoint1: NSPoint(x: 390, y: 345), controlPoint2: NSPoint(x: 301, y: 363))
left.close(); left.fill()
let right = NSBezierPath()
right.move(to: NSPoint(x: 540, y: 670))
right.curve(to: NSPoint(x: 809, y: 724), controlPoint1: NSPoint(x: 612, y: 720), controlPoint2: NSPoint(x: 694, y: 748))
right.line(to: NSPoint(x: 809, y: 345))
right.curve(to: NSPoint(x: 540, y: 295), controlPoint1: NSPoint(x: 723, y: 363), controlPoint2: NSPoint(x: 634, y: 345))
right.close(); right.fill()
NSColor(srgbRed: 0.96, green: 0.32, blue: 0.16, alpha: 0.5).setStroke()
for y in [450.0, 520.0, 590.0] {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 275, y: y + 35))
    line.curve(to: NSPoint(x: 421, y: y), controlPoint1: NSPoint(x: 335, y: y + 38), controlPoint2: NSPoint(x: 390, y: y + 17))
    line.lineWidth = 13; line.lineCapStyle = .round; line.stroke()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
