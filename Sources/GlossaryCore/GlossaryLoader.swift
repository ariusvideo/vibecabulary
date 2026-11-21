import Foundation

public enum GlossaryLoadError: LocalizedError, Equatable {
    case unsupportedType(String)
    case unreadable(String)
    case invalid(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext): "Unsupported file type “.\(ext)”. Use .json, .csv or .md."
        case .unreadable(let why): "Couldn’t read the file: \(why)"
        case .invalid(let why): "The file isn’t a valid glossary: \(why)"
        case .empty: "The file has no terms with both a term and a definition."
        }
    }
}

/// Reads a glossary from JSON (canonical), CSV or Markdown.
public enum GlossaryLoader {
    public static let supportedExtensions = ["json", "csv", "md", "markdown"]

    public static func load(from url: URL) throws -> GlossaryDocument {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { throw GlossaryLoadError.unsupportedType(ext) }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw GlossaryLoadError.unreadable(error.localizedDescription)
        }
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let doc: GlossaryDocument
        switch ext {
        case "json": doc = try decodeJSON(text)
        case "csv": doc = GlossaryDocument(name: fallbackName, terms: CSVImporter.entries(from: text))
        default: doc = MarkdownImporter.document(from: text, fallbackName: fallbackName)
        }
        return try validated(doc)
    }

    public static func decodeJSON(_ text: String) throws -> GlossaryDocument {
        let data = Data(text.utf8)
        do {
            return try JSONDecoder().decode(GlossaryDocument.self, from: data)
        } catch let DecodingError.keyNotFound(key, ctx) {
            throw GlossaryLoadError.invalid("missing “\(key.stringValue)” at \(path(ctx))")
        } catch let DecodingError.typeMismatch(_, ctx) {
            throw GlossaryLoadError.invalid("wrong value type at \(path(ctx))")
        } catch {
            // A bare array of terms is accepted too.
            if let terms = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
                return GlossaryDocument(name: "Glossary", terms: terms)
            }
            throw GlossaryLoadError.invalid(error.localizedDescription)
        }
    }

    private static func path(_ ctx: DecodingError.Context) -> String {
        let p = ctx.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
        return p.isEmpty ? "top level" : p
    }

    /// Trims fields, drops incomplete entries, and keeps the first of any duplicate terms.
    public static func validated(_ doc: GlossaryDocument) throws -> GlossaryDocument {
        var seen = Set<String>()
        var out = doc
        out.terms = doc.terms.compactMap { entry in
            var e = entry
            e.term = e.term.trimmingCharacters(in: .whitespacesAndNewlines)
            e.definition = e.definition.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !e.term.isEmpty, !e.definition.isEmpty else { return nil }
            guard seen.insert(SearchEngine.normalize(e.term)).inserted else { return nil }
            return e
        }
        if out.terms.isEmpty { throw GlossaryLoadError.empty }
        return out
    }
}
