// Renders the Vibecabulary app icon ({v}: amber braces, cream italic v, charcoal tile) into an .iconset folder.
// Sizes of 32 px and under use bold weights so the strokes survive.
// Usage: swift tools/make_icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func serifItalic(_ size: CGFloat, bold: Bool) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular).fontDescriptor
    let traits: NSFontDescriptor.SymbolicTraits = bold ? [.italic, .bold] : [.italic]
    return (base.withDesign(.serif)?.withSymbolicTraits(traits)).flatMap { NSFont(descriptor: $0, size: size) }
        ?? NSFont.systemFont(ofSize: size)
}

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: size)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

    // The tile follows the macOS icon grid: 80% of the canvas, corner radius 22% of the tile.
    let inset = size * 0.1
    let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.22, yRadius: tile.width * 0.22)
    NSGradient(starting: color(0x26221F), ending: color(0x1B1916))!.draw(in: path, angle: 90)

    // Glyph positions are fractions of the tile, matching the approved design.
    let bold = px <= 32
    let u = tile.width
    func draw(_ s: String, _ font: NSFont, _ fill: NSColor, centerX: CGFloat, baseline: CGFloat) {
        let text = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: fill])
        let width = text.size().width
        text.draw(at: NSPoint(x: tile.minX + centerX * u - width / 2, y: tile.minY + baseline * u - font.ascender))
    }
    let brace = NSFont(name: bold ? "Menlo-Bold" : "Menlo-Regular", size: 0.5 * u)!
    draw("{", brace, color(0xD9A35B), centerX: 0.2065, baseline: 0.674)
    draw("}", brace, color(0xD9A35B), centerX: 0.7935, baseline: 0.674)
    draw("v", serifItalic(0.5 * u, bold: bold), color(0xEEE6DA), centerX: 0.5, baseline: 0.652)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
