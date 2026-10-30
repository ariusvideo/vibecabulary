import Foundation

public struct SearchResult: Identifiable, Hashable, Sendable {
    /// Lower raw value ranks higher.
    public enum Match: Int, Comparable, Sendable {
        case prefix, wordPrefix, contains, alias, definition
        public static func < (a: Match, b: Match) -> Bool { a.rawValue < b.rawValue }
    }

    public let entry: GlossaryEntry
    public let match: Match
    /// For alias matches, the alias that matched. For definition matches, a short excerpt.
    public let detail: String?

    public var id: String { entry.id }
}

public struct SearchEngine: Sendable {
    /// Definition text is only searched once the query has this many characters.
    public static let minDefinitionQueryLength = 2
    public static let snippetRadius = 40

    private struct Indexed: Sendable {
        let entry: GlossaryEntry
        let term: String
        let words: [String]
        let aliases: [String]
        let definition: String
    }

    private let index: [Indexed]
    /// All entries sorted A–Z by normalized term.
    public let alphabetical: [GlossaryEntry]

    public init(entries: [GlossaryEntry]) {
        let indexed = entries.map { e in
            let term = Self.normalize(e.term)
            return Indexed(entry: e, term: term, words: Self.words(term),
                           aliases: e.aliases.map(Self.normalize), definition: Self.normalize(e.definition))
        }.sorted { Self.ordered($0.term, $1.term) }
        index = indexed
        alphabetical = indexed.map(\.entry)
    }

    /// Case-, diacritic- and curly-quote-insensitive form used for matching and ordering.
    public static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
    }

    static func words(_ normalized: String) -> [String] {
        normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static func ordered(_ a: String, _ b: String) -> Bool {
        a.localizedStandardCompare(b) == .orderedAscending
    }

    public func browse(ascending: Bool) -> [GlossaryEntry] {
        ascending ? alphabetical : alphabetical.reversed()
    }

    public func entry(named name: String) -> GlossaryEntry? {
        let n = Self.normalize(name)
        return index.first { $0.term == n }?.entry ?? index.first { $0.aliases.contains(n) }?.entry
    }

    public func search(_ query: String) -> [SearchResult] {
        let q = Self.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }
        let qWords = Self.words(q)
        var results: [SearchResult] = []
        for item in index {
            if item.term.hasPrefix(q) {
                results.append(SearchResult(entry: item.entry, match: .prefix, detail: nil))
            } else if !qWords.isEmpty && Self.wordsMatch(qWords, item.words) {
                results.append(SearchResult(entry: item.entry, match: .wordPrefix, detail: nil))
            } else if item.term.contains(q) {
                results.append(SearchResult(entry: item.entry, match: .contains, detail: nil))
            } else if let i = item.aliases.firstIndex(where: { $0.hasPrefix(q) || $0.contains(q) }) {
                results.append(SearchResult(entry: item.entry, match: .alias, detail: item.entry.aliases[i]))
            } else if q.count >= Self.minDefinitionQueryLength, item.definition.contains(q) {
                results.append(SearchResult(entry: item.entry, match: .definition,
                                            detail: Self.snippet(item.entry.definition, around: query)))
            }
        }
        // `index` is already A–Z, and the sort is stable, so ties stay alphabetical.
        return results.enumerated().sorted {
            $0.element.match != $1.element.match ? $0.element.match < $1.element.match : $0.offset < $1.offset
        }.map(\.element)
    }

    /// Every query word is a prefix of some word in the term ("sup vec" -> "support vector").
    static func wordsMatch(_ queryWords: [String], _ termWords: [String]) -> Bool {
        queryWords.allSatisfy { qw in termWords.contains { $0.hasPrefix(qw) } }
    }

    /// A one-line excerpt of `text` centered on the first match of `query`.
    public static func snippet(_ text: String, around query: String) -> String? {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = flat.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        let start = flat.index(r.lowerBound, offsetBy: -snippetRadius, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(r.upperBound, offsetBy: snippetRadius, limitedBy: flat.endIndex) ?? flat.endIndex
        var s = String(flat[start..<end]).trimmingCharacters(in: .whitespaces)
        if start > flat.startIndex { s = "…" + s }
        if end < flat.endIndex { s += "…" }
        return s
    }
}
