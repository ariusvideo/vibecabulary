import Foundation

/// Tag changes made in the app, kept apart from the glossary files so regenerating or
/// swapping a glossary never loses them. Edits are stored per glossary file, then per term.
/// An empty tag list means "tag removed".
public struct TagEdits: Codable, Equatable, Sendable {
    public var glossaries: [String: [String: [String]]]

    public init(glossaries: [String: [String: [String]]] = [:]) {
        self.glossaries = glossaries
    }

    /// The key edits are stored under for a glossary file.
    public static func key(for url: URL) -> String { url.standardizedFileURL.path }

    public func edits(for key: String) -> [String: [String]] { glossaries[key] ?? [:] }

    public func isEdited(_ term: String, in key: String) -> Bool { glossaries[key]?[term] != nil }

    /// Records `tags` for `term`. Setting a term back to its tags in the file drops the edit.
    public mutating func set(_ tags: [String], for term: String, original: [String], in key: String) {
        var forFile = glossaries[key] ?? [:]
        forFile[term] = tags == original ? nil : tags
        glossaries[key] = forFile.isEmpty ? nil : forFile
    }

    public mutating func reset(_ key: String) { glossaries[key] = nil }

    /// Drops edits that the file now agrees with (for example after the tags were saved into it
    /// or merged into the master data). Returns true if anything was dropped.
    @discardableResult
    public mutating func prune(_ key: String, against document: GlossaryDocument) -> Bool {
        guard let forFile = glossaries[key] else { return false }
        let fileTags = Dictionary(document.terms.map { ($0.term, $0.tags) }, uniquingKeysWith: { a, _ in a })
        let kept = forFile.filter { fileTags[$0.key] != $0.value }
        guard kept.count != forFile.count else { return false }
        glossaries[key] = kept.isEmpty ? nil : kept
        return true
    }

    /// `document` with this file's edits applied. Edits for terms no longer in the file are ignored.
    public func apply(to document: GlossaryDocument, key: String) -> GlossaryDocument {
        let forFile = edits(for: key)
        guard !forFile.isEmpty else { return document }
        var out = document
        for i in out.terms.indices {
            if let tags = forFile[out.terms[i].term] { out.terms[i].tags = tags }
        }
        return out
    }

    /// Edits that still match a term in `document`.
    public func count(in key: String, document: GlossaryDocument) -> Int {
        let terms = Set(document.terms.map(\.term))
        return edits(for: key).keys.filter(terms.contains).count
    }

    /// JSON in the `tools/tags.json` shape (term -> tag), with `null` for removed tags,
    /// so the edits can be merged into the master data.
    public func exportJSON(for key: String) throws -> Data {
        var out: [String: String?] = [:]
        for (term, tags) in edits(for: key) { out[term] = .some(tags.first) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(out)
    }
}
