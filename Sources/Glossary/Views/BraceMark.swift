import AppKit
import SwiftUI

/// The Vibecabulary mark: `{v}` with an optional blinking text cursor after the v.
/// Laid out in a 100-unit box so it matches the app icon and menu bar glyph.
struct BraceMark: View {
    var size: CGFloat = 64
    var cursor = true
    @Environment(\.glossaryTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if cursor && !reduceMotion {
            // Blinks at the macOS caret rate; TimelineView pauses while the view is off screen.
            TimelineView(.periodic(from: .now, by: 0.53)) { context in
                let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.53) % 2
                mark(cursorVisible: phase == 0)
            }
        } else {
            mark(cursorVisible: cursor)
        }
    }

    private func mark(cursorVisible: Bool) -> some View {
        Canvas { context, canvas in
            let u = canvas.width / 100
            func draw(_ text: Text, centerX: CGFloat, baseline: CGFloat) {
                let resolved = context.resolve(text)
                let measured = resolved.measure(in: canvas)
                let top = baseline * u - resolved.firstBaseline(in: canvas)
                context.draw(resolved, in: CGRect(x: centerX * u - measured.width / 2, y: top,
                                                  width: measured.width, height: measured.height))
            }
            let brace = Font.custom("Menlo", size: 54 * u)
            draw(Text("{").font(brace).foregroundColor(theme.accent), centerX: cursor ? 18 : 21, baseline: 68)
            draw(Text("}").font(brace).foregroundColor(theme.accent), centerX: cursor ? 82 : 79, baseline: 68)
            draw(Text("v").font(.system(size: 52 * u, design: .serif).italic()).foregroundColor(theme.textPrimary),
                 centerX: cursor ? 40 : 50, baseline: 66)
            if cursorVisible {
                context.fill(Path(roundedRect: CGRect(x: 60 * u, y: 33 * u, width: 4 * u, height: 36 * u),
                                  cornerRadius: u),
                             with: .color(theme.accent))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// `{vibe}cabulary` in monospace, braces in the theme's accent.
struct Wordmark: View {
    var size: CGFloat = 15
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        (Text("{").foregroundColor(theme.accent)
            + Text("vibe").foregroundColor(theme.textPrimary)
            + Text("}").foregroundColor(theme.accent)
            + Text("cabulary").foregroundColor(theme.textPrimary))
            .font(.custom("Menlo", size: size))
            .accessibilityLabel("Vibecabulary")
    }
}

extension NSImage {
    /// The menu bar glyph: bold `{v}` as a template image, so macOS tints it for light and dark menu bars.
    static func braceMarkTemplate(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { rect in
            let u = rect.width / 100
            func draw(_ s: String, _ font: NSFont, centerX: CGFloat, baseline: CGFloat) {
                let text = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.black])
                let width = text.size().width
                text.draw(at: NSPoint(x: centerX * u - width / 2, y: baseline * u - font.ascender))
            }
            let brace = NSFont(name: "Menlo-Bold", size: 64 * u) ?? .monospacedSystemFont(ofSize: 64 * u, weight: .bold)
            let serif = NSFont.systemFont(ofSize: 60 * u, weight: .bold).fontDescriptor
                .withDesign(.serif)?.withSymbolicTraits([.italic, .bold])
            let v = serif.flatMap { NSFont(descriptor: $0, size: 60 * u) } ?? .boldSystemFont(ofSize: 60 * u)
            draw("{", brace, centerX: 17, baseline: 74)
            draw("}", brace, centerX: 83, baseline: 74)
            draw("v", v, centerX: 50, baseline: 72)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vibecabulary"
        return image
    }
}
