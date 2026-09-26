import AppKit

// Renders the Vitals app icon at 1024×1024: a dark rounded-rect tile with a
// glowing cyan→magenta pulse/heartbeat waveform. Output path is argv[1].

let size = 1024.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background rounded tile with vertical gradient.
let inset = 40.0
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = CGPath(roundedRect: rect, cornerWidth: 220, cornerHeight: 220, transform: nil)
ctx.saveGState()
ctx.addPath(path)
ctx.clip()
let bgColors = [NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 1).cgColor] as CFArray
let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Subtle inner stroke.
ctx.addPath(path)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
ctx.setLineWidth(4)
ctx.strokePath()

// Heartbeat / pulse waveform.
let midY = size * 0.5
let points: [CGPoint] = [
    CGPoint(x: 0.16, y: 0.50), CGPoint(x: 0.30, y: 0.50), CGPoint(x: 0.38, y: 0.50),
    CGPoint(x: 0.44, y: 0.68), CGPoint(x: 0.52, y: 0.24), CGPoint(x: 0.60, y: 0.78),
    CGPoint(x: 0.67, y: 0.42), CGPoint(x: 0.72, y: 0.50), CGPoint(x: 0.84, y: 0.50),
].map { CGPoint(x: $0.x * size, y: size - ($0.y * size)) }
_ = midY

let wave = CGMutablePath()
wave.move(to: points[0])
for p in points.dropFirst() { wave.addLine(to: p) }

// Glow pass.
ctx.saveGState()
ctx.setLineWidth(46)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.31, blue: 0.85, alpha: 0.55).cgColor)
ctx.setShadow(offset: .zero, blur: 60, color: NSColor(calibratedRed: 0.4, green: 0.8, blue: 1.0, alpha: 0.9).cgColor)
ctx.addPath(wave)
ctx.strokePath()
ctx.restoreGState()

// Bright gradient stroke on top (clip to a thick stroked version of the path).
ctx.saveGState()
let stroked = wave.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 10)
ctx.addPath(stroked)
ctx.clip()
let lineColors = [NSColor(calibratedRed: 0.23, green: 0.78, blue: 1.0, alpha: 1).cgColor,
                  NSColor(calibratedRed: 1.0, green: 0.31, blue: 0.85, alpha: 1).cgColor] as CFArray
let lineGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: lineColors, locations: [0, 1])!
ctx.drawLinearGradient(lineGrad, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
