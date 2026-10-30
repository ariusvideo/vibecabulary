import Foundation

/// One glossary term. Only `term` and `definition` are required in the JSON file.
public struct GlossaryEntry: Codable, Hashable, Identifiable, Sendable {
    public struct Note: Codable, Hashable, Sendable {
        public var text: String
        public var citation: String?

        public init(text: String, citation: String? = nil) {
            self.text = text
            self.citation = citation
        }
    }

    public var term: String
    public var aliases: [String]
    public var definition: String
    /// "PMI", "Course", or any label another glossary wants to show as a badge.
    public var source: String?
    public var citation: String?
    public var notes: [Note]
    public var related: [String]
    /// Study-area labels such as "Foundations" or "Phase II", shown as badges.
    public var tags: [String]

    public var id: String { term }

    public init(term: String, definition: String, aliases: [String] = [], source: String? = nil,
                citation: String? = nil, notes: [Note] = [], related: [String] = [], tags: [String] = []) {
        self.term = term
        self.definition = definition
        self.aliases = aliases
        self.source = source
        self.citation = citation
        self.notes = notes
        self.related = related
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case term, aliases, definition, source, citation, notes, related, tags
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term)
        definition = try c.decode(String.self, forKey: .definition)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        source = try c.decodeIfPresent(String.self, forKey: .source)
        citation = try c.decodeIfPresent(String.self, forKey: .citation)
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        related = try c.decodeIfPresent([String].self, forKey: .related) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(term, forKey: .term)
        if !aliases.isEmpty { try c.encode(aliases, forKey: .aliases) }
        try c.encode(definition, forKey: .definition)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(citation, forKey: .citation)
        if !notes.isEmpty { try c.encode(notes, forKey: .notes) }
        if !related.isEmpty { try c.encode(related, forKey: .related) }
        if !tags.isEmpty { try c.encode(tags, forKey: .tags) }
    }

    /// Plain-text form used by Copy.
    public var copyText: String {
        var parts = ["\(term): \(definition)"]
        for note in notes {
            parts.append("Note" + (note.citation.map { " (\($0))" } ?? "") + ": " + note.text)
        }
        if let citation { parts.append("Source: " + [source, citation].compactMap { $0 }.joined(separator: ", ")) }
        return parts.joined(separator: "\n")
    }
}

public struct GlossaryDocument: Codable, Sendable {
    public var name: String
    public var version: String?
    public var terms: [GlossaryEntry]

    public init(name: String, version: String? = nil, terms: [GlossaryEntry]) {
        self.name = name
        self.version = version
        self.terms = terms
    }
}
