import Foundation

/// CSV with a header row: `term,definition[,aliases,source,citation]` (any order).
/// Without a recognizable header, column 1 is the term and column 2 the definition.
/// Aliases are separated by semicolons.
public enum CSVImporter {
    public static func entries(from text: String) -> [GlossaryEntry] {
        var rows = parse(text)
        guard !rows.isEmpty else { return [] }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var col = ["term": 0, "definition": 1]
        if header.contains("term") && header.contains("definition") {
            col = [:]
            for (i, name) in header.enumerated() where col[name] == nil { col[name] = i }
            rows.removeFirst()
        }
        func field(_ row: [String], _ name: String) -> String? {
            guard let i = col[name], i < row.count else { return nil }
            let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        return rows.compactMap { row in
            guard let term = field(row, "term"), let def = field(row, "definition") else { return nil }
            let aliases = field(row, "aliases")?.split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } ?? []
            return GlossaryEntry(term: term, definition: def, aliases: aliases,
                                 source: field(row, "source"), citation: field(row, "citation"))
        }
    }

    /// RFC 4180: quoted fields may contain commas, newlines and doubled quotes.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = text.makeIterator()
        var pending: Character? = nil
        while let c = pending ?? chars.next() {
            pending = nil
            if inQuotes {
                if c == "\"" {
                    let next = chars.next()
                    if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                } else {
                    field.append(c)
                }
                continue
            }
            switch c {
            case "\"": inQuotes = true
            case ",": row.append(field); field = ""
            case "\n", "\r\n", "\r":
                row.append(field); field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
            default: field.append(c)
            }
        }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
}

/// Markdown in either form:
///   `## Term` headings with the definition below, or
///   `- **Term**: definition` (also `—`, `–` or `.` after the bold term) list items.
/// A leading `# Title` names the glossary.
public enum MarkdownImporter {
    public static func document(from text: String, fallbackName: String) -> GlossaryDocument {
        var name = fallbackName
        var entries: [GlossaryEntry] = []
        var heading: String? = nil
        var body: [String] = []

        func flush() {
            if let h = heading {
                let def = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                entries.append(GlossaryEntry(term: h, definition: def))
            }
            heading = nil
            body = []
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") && entries.isEmpty && heading == nil {
                name = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("## ") || line.hasPrefix("### ") {
                flush()
                heading = stripMarkup(String(line.drop(while: { $0 == "#" })))
            } else if heading == nil, let item = listItem(line) {
                entries.append(item)
            } else if heading != nil {
                body.append(line.hasPrefix("- ") || line.hasPrefix("* ") ? "• " + stripMarkup(String(line.dropFirst(2)))
                                                                         : stripMarkup(line))
            }
        }
        flush()
        return GlossaryDocument(name: name, terms: entries)
    }

    private static let listPattern = try! NSRegularExpression(
        pattern: #"^[-*]\s+\*\*(.+?)\*\*\s*(?::|—|–|-|\.)?\s*(.+)$"#)

    static func listItem(_ line: String) -> GlossaryEntry? {
        let ns = line as NSString
        guard let m = listPattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        var term = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        if term.hasSuffix(":") { term.removeLast() }
        let def = stripMarkup(ns.substring(with: m.range(at: 2)))
        return GlossaryEntry(term: term, definition: def)
    }

    static func stripMarkup(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
