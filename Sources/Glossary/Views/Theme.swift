import SwiftUI

/// The five looks. The raw value is what `@AppStorage("theme")` stores.
enum ThemeID: String, CaseIterable, Identifiable {
    case readingRoom
    case readingRoomLight
    case liquidGlass
    case studyDeck
    case midnightAurora

    static let storageKey = "theme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .readingRoom: "Reading room"
        case .readingRoomLight: "Reading room light"
        case .liquidGlass: "Liquid Glass"
        case .studyDeck: "Study deck"
        case .midnightAurora: "Midnight aurora"
        }
    }

    var theme: GlossaryTheme {
        switch self {
        case .readingRoom: .readingRoom
        case .readingRoomLight: .readingRoomLight
        case .liquidGlass: .liquidGlass
        case .studyDeck: .studyDeck
        case .midnightAurora: .midnightAurora
        }
    }

    /// The saved theme, for AppKit code that can't use `@AppStorage`.
    static var stored: ThemeID {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ThemeID.init) ?? .readingRoom
    }
}

/// Every color, font and shape decision the views make, so no view hard-codes a palette.
struct GlossaryTheme: Sendable {
    enum SelectionStyle: Sendable {
        /// Tinted row with an accent bar on the left edge.
        case leftBar
        case fill
        case outline
    }

    /// How the definition pane frames an entry.
    enum EntryStyle: Sendable {
        /// Straight on the page, like a dictionary.
        case page
        /// A card with a top border in the entry's first tag color.
        case card
    }

    var isLight = false

    // Colors
    var background: Color
    var panel: Color
    var field: Color
    var separator: Color
    var textPrimary: Color
    var textSecondary: Color
    var textTertiary: Color
    var accent: Color
    var selection: Color
    var highlight: Color
    var formula: Color

    // Fonts
    var headingDesign: Font.Design = .default
    var bodyDesign: Font.Design = .default

    // Style
    var cornerRadius: CGFloat = 6
    var selectionStyle: SelectionStyle = .fill
    var entryStyle: EntryStyle = .page
    /// Replaces the line under the search bar with an accent-to-formula gradient strip.
    var accentStrip = false
    /// Draws a material (Liquid Glass on macOS 26+) behind the content; `background` is then a tint.
    var usesMaterial = false

    var badges: BadgePalette = .dark

    var colorScheme: ColorScheme { isLight ? .light : .dark }

    func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: headingDesign)
    }

    func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: bodyDesign)
    }
}

// MARK: - The five themes

extension GlossaryTheme {
    static let readingRoom = GlossaryTheme(
        background: Color(hex: 0x1F1C19),
        panel: Color(hex: 0x24211D),
        field: Color(hex: 0x2A2622),
        separator: Color.white.opacity(0.08),
        textPrimary: Color(hex: 0xEEE6DA),
        textSecondary: Color(hex: 0xB5AA9A),
        textTertiary: Color(hex: 0x8C8172),
        accent: Color(hex: 0xD9A35B),
        selection: Color(hex: 0xD9A35B).opacity(0.14),
        highlight: Color(hex: 0xF2C47E),
        formula: Color(hex: 0xEBC891),
        headingDesign: .serif,
        selectionStyle: .leftBar)

    static let readingRoomLight = GlossaryTheme(
        isLight: true,
        background: Color(hex: 0xF7F1E5),
        panel: Color(hex: 0xEFE7D7),
        field: Color(hex: 0xFBF8F1),
        separator: Color.black.opacity(0.10),
        textPrimary: Color(hex: 0x2A241E),
        textSecondary: Color(hex: 0x5C5248),
        textTertiary: Color(hex: 0x76695B),
        accent: Color(hex: 0x95600F),
        selection: Color(hex: 0xC98A2E).opacity(0.16),
        highlight: Color(hex: 0x8A4F00),
        formula: Color(hex: 0x6E4609),
        headingDesign: .serif,
        selectionStyle: .leftBar,
        badges: .light)

    static let liquidGlass = GlossaryTheme(
        background: Color(hex: 0x16171C).opacity(0.6),
        panel: Color.white.opacity(0.04),
        field: Color.white.opacity(0.06),
        separator: Color.white.opacity(0.12),
        textPrimary: Color.white.opacity(0.95),
        textSecondary: Color.white.opacity(0.74),
        textTertiary: Color.white.opacity(0.55),
        accent: Color(hex: 0x6CB8FF),
        selection: Color.white.opacity(0.14),
        highlight: Color(hex: 0x9FD2FF),
        formula: Color(hex: 0xB9DEFF),
        cornerRadius: 10,
        selectionStyle: .fill,
        usesMaterial: true)

    static let studyDeck = GlossaryTheme(
        background: Color(hex: 0x14161F),
        panel: Color(hex: 0x191C27),
        field: Color(hex: 0x1F2230),
        separator: Color.white.opacity(0.08),
        textPrimary: Color(hex: 0xE8E9F2),
        textSecondary: Color(hex: 0xA3A6BC),
        textTertiary: Color(hex: 0x7A7E97),
        accent: Color(hex: 0x9D8CFF),
        selection: Color(hex: 0x9D8CFF).opacity(0.22),
        highlight: Color(hex: 0x4FD8C4),
        formula: Color(hex: 0x4FD8C4),
        cornerRadius: 10,
        selectionStyle: .fill,
        entryStyle: .card)

    static let midnightAurora = GlossaryTheme(
        background: Color(hex: 0x0D0E14),
        panel: Color(hex: 0x11121A),
        field: Color(hex: 0x161823),
        separator: Color.white.opacity(0.07),
        textPrimary: Color(hex: 0xE9E8F5),
        textSecondary: Color(hex: 0xA09EB8),
        textTertiary: Color(hex: 0x77758F),
        accent: Color(hex: 0x7C5CFF),
        selection: Color(hex: 0x7C5CFF).opacity(0.10),
        highlight: Color(hex: 0xA996FF),
        formula: Color(hex: 0x3FD9C2),
        cornerRadius: 8,
        selectionStyle: .outline,
        accentStrip: true)
}

// MARK: - Badges

/// Solid badge fills. Badge text is always dark, so every fill is light enough to keep contrast high.
struct BadgePalette: Sendable {
    var text: Color
    /// Fills for a glossary's tags in order: the first tag gets the first fill, and so on.
    var tagFills: [Color]
    /// Fills for tags past the ordered ones, picked by a stable hash of the tag name.
    var extraFills: [Color]
    var sourceFills: [Color]
    /// The current glossary's tags in display order; set by ContentView.
    var tagOrder: [String] = []

    func fill(forTag tag: String) -> Color {
        if let i = tagOrder.firstIndex(of: tag), i < tagFills.count { return tagFills[i] }
        return extraFills[Self.stableIndex(tag, count: extraFills.count)]
    }

    func fill(forSource source: String) -> Color {
        sourceFills[Self.stableIndex(source.lowercased(), count: sourceFills.count)]
    }

    /// FNV-1a; `String.hashValue` is seeded per launch, so this keeps a color the same every time.
    static func stableIndex(_ s: String, count: Int) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in s.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3 }
        return Int(hash % UInt64(count))
    }

    static let dark = BadgePalette(
        text: Color(hex: 0x1A1714),
        tagFills: [0xA9C8FF, 0xFFB0CB, 0xFFD47E, 0xC4E68F, 0x8FDDEE, 0xCDB6FF, 0xFFB58C, 0x8FEBC9].map { Color(hex: $0) },
        extraFills: [0xE6D3A8, 0xB8D4D0, 0xE3BFE8, 0xD2D6A4].map { Color(hex: $0) },
        sourceFills: [0xC9CCD6, 0xDCD3C6, 0xF0B76A].map { Color(hex: $0) })

    /// Slightly deeper fills so badges still stand out on cream paper; the text stays dark.
    static let light = BadgePalette(
        text: Color(hex: 0x1F1A15),
        tagFills: [0x93B6F2, 0xF29BB9, 0xF2C25C, 0xADD575, 0x76CBDD, 0xB9A0F2, 0xF29E70, 0x72D9B3].map { Color(hex: $0) },
        extraFills: [0xD9C48F, 0x9CC2BC, 0xD3A6DA, 0xC0C585].map { Color(hex: $0) },
        sourceFills: [0xBCC0CC, 0xD3C7B4, 0xE8A64F].map { Color(hex: $0) })
}

/// A solid badge with dark text, for a tag or a source.
struct Badge: View {
    let label: String
    let fill: Color
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.badges.text)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(fill, in: RoundedRectangle(cornerRadius: 4))
    }
}

struct SourceBadge: View {
    let source: String?
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        if let source, let label = Self.label(for: source) {
            Badge(label: label, fill: theme.badges.fill(forSource: source))
        }
    }

    static func label(for source: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Environment

private struct GlossaryThemeKey: EnvironmentKey {
    static let defaultValue = GlossaryTheme.readingRoom
}

extension EnvironmentValues {
    var glossaryTheme: GlossaryTheme {
        get { self[GlossaryThemeKey.self] }
        set { self[GlossaryThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
