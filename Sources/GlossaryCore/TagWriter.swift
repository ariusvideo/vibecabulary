import Foundation

/// Writes tag edits into a JSON glossary file in place. Works on the raw JSON so every other
/// field and every entry, including ones the loader would skip, is kept as it was.
public enum TagWriter {
    public enum WriteError: LocalizedError {
        case notJSON
        case unrecognizedLayout

        public var errorDescription: String? {
            switch self {
            case .notJSON: "Only JSON glossaries can be saved to. CSV and Markdown edits stay in the app."
            case .unrecognizedLayout: "The file isn’t a glossary JSON with a list of terms."
            }
        }
    }

    /// Applies `edits` (term -> tags; empty removes the tags) to the JSON at `url`.
    /// Returns how many entries changed. Writes atomically.
    @discardableResult
    public static func write(_ edits: [String: [String]], toJSONAt url: URL) throws -> Int {
        guard url.pathExtension.lowercased() == "json" else { throw WriteError.notJSON }
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        var changed = 0

        func update(_ terms: [Any]) -> [Any] {
            terms.map { item in
                guard var entry = item as? [String: Any], let term = entry["term"] as? String,
                      let tags = edits[term] else { return item }
                if tags.isEmpty { entry["tags"] = nil } else { entry["tags"] = tags }
                changed += 1
                return entry
            }
        }

        let output: Any
        if var doc = root as? [String: Any], let terms = doc["terms"] as? [Any] {
            doc["terms"] = update(terms)
            output = doc
        } else if let terms = root as? [Any] {
            output = update(terms)
        } else {
            throw WriteError.unrecognizedLayout
        }
        let data = try JSONSerialization.data(withJSONObject: output,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
        return changed
    }
}
