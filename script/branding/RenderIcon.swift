import AppKit

// Standard app-icon packaging: keep the supplied mascot intact on its charcoal tile.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
guard let mascot = NSImage(contentsOf: source),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render the Cider app icon") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 208, yRadius: 208)
NSGradient(starting: NSColor(white: 0.18, alpha: 1), ending: NSColor(white: 0.065, alpha: 1))!.draw(in: tile, angle: -90)
NSColor(white: 1, alpha: 0.06).setStroke(); tile.lineWidth = 2; tile.stroke()
mascot.draw(in: NSRect(x: 38, y: 40, width: 948, height: 948))
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
