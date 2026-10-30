import GlossaryCore
import SwiftUI

struct DefinitionView: View {
    @ObservedObject var model: GlossaryViewModel
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        ZStack {
            if let entry = model.displayed {
                ScrollView {
                    framed(entry, content: entryContent(entry))
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(entry.id)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity))
            } else {
                placeholder
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.displayed?.id)
    }

    private func entryContent(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header(entry)
            VStack(alignment: .leading, spacing: 14) {
                FormattedText(text: entry.definition, size: 14)
                ForEach(entry.notes, id: \.self) { note in
                    NoteView(note: note)
                }
            }
            .textSelection(.enabled)
            if !entry.related.isEmpty {
                seeAlso(entry)
            }
        }
    }

    /// Study deck puts the entry on a card topped with its tag color; the other themes print it on the page.
    @ViewBuilder
    private func framed(_ entry: GlossaryEntry, content: some View) -> some View {
        switch theme.entryStyle {
        case .page:
            content
        case .card:
            let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.panel, in: shape)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(entry.tags.first.map { theme.badges.fill(forTag: $0) } ?? theme.accent)
                        .frame(height: 3)
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(theme.separator))
        }
    }

    private func header(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 5) {
                TagEditor(model: model, entry: entry)
                SourceBadge(source: entry.source)
            }
            .padding(.bottom, 2)
            Text(entry.term)
                .font(theme.heading(24))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let citation = entry.citation, !citation.isEmpty {
                Text(citation)
                    .font(theme.body(12))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
            }
            if !entry.aliases.isEmpty {
                Text("Also: " + entry.aliases.joined(separator: " · "))
                    .font(theme.body(11))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    /// "See also" as inline accent links that wrap with the text.
    private func seeAlso(_ entry: GlossaryEntry) -> some View {
        var text = AttributedString("See also  ")
        text.foregroundColor = theme.textTertiary
        for (i, name) in entry.related.enumerated() {
            var link = AttributedString(name)
            link.link = Self.url(for: name)
            link.foregroundColor = theme.accent
            text += link
            if i < entry.related.count - 1 {
                var dot = AttributedString(" · ")
                dot.foregroundColor = theme.textTertiary
                text += dot
            }
        }
        return Text(text)
            .font(theme.body(13))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if let name = Self.term(from: url) { model.openRelated(name) }
                return .handled
            })
    }

    private static func url(for term: String) -> URL? {
        var c = URLComponents()
        c.scheme = "glossary"
        c.host = "term"
        c.queryItems = [URLQueryItem(name: "name", value: term)]
        return c.url
    }

    private static func term(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "name" }?.value
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                BraceMark(size: 72)
                Wordmark()
            }
            .padding(.bottom, 6)
            Text(model.selectedEntry == nil ? "Type to search, or ↓ to browse" : "Press ⏎ or double-click to open")
                .font(theme.body(13))
                .foregroundStyle(theme.textSecondary)
            TermOfTheDay(entry: model.termOfTheDay) { _ in model.openTermOfTheDay() }
                .padding(.top, 14)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The entry's tag badge, which opens a menu to change it. An untagged entry shows "+ Tag".
private struct TagEditor: View {
    @ObservedObject var model: GlossaryViewModel
    let entry: GlossaryEntry
    @Environment(\.glossaryTheme) private var theme
    @State private var addingNew = false
    @State private var newTag = ""

    @State private var choosing = false

    // A plain button + popover rather than `Menu`: macOS draws menu labels as monochrome
    // text, which strips the badge's solid fill.
    var body: some View {
        HStack(spacing: 4) {
            Button { choosing = true } label: { label }
                .buttonStyle(.plain)
                .help("Change this term’s tag")
                .popover(isPresented: $choosing, arrowEdge: .bottom) { tagList }
                .popover(isPresented: $addingNew, arrowEdge: .bottom) { newTagField }
            if model.store.isTagEdited(entry) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .help("Tag changed in the app. Settings → Tag edits to save, export or reset.")
            }
        }
    }

    private var tagList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(model.store.availableTags, id: \.self) { tag in
                TagChoice(selected: entry.tags.first == tag) {
                    Badge(label: tag, fill: theme.badges.fill(forTag: tag))
                } action: {
                    model.setTag(tag, for: entry)
                    choosing = false
                }
            }
            Divider().padding(.vertical, 4)
            TagChoice(selected: false) { Text("New tag…") } action: {
                choosing = false
                newTag = ""
                // Let the list close before the field opens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { addingNew = true }
            }
            if !entry.tags.isEmpty {
                TagChoice(selected: false) { Text("Remove tag") } action: {
                    model.setTag(nil, for: entry)
                    choosing = false
                }
            }
        }
        .font(.system(size: 12))
        .padding(8)
        .frame(minWidth: 170, alignment: .leading)
    }

    @ViewBuilder private var label: some View {
        if let tag = entry.tags.first {
            HStack(spacing: 4) {
                ForEach(entry.tags, id: \.self) { Badge(label: $0, fill: theme.badges.fill(forTag: $0)) }
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .accessibilityLabel("Tag: \(tag)")
        } else {
            Text("+ Tag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.separator))
        }
    }

    private var newTagField: some View {
        HStack(spacing: 6) {
            TextField("Tag name", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .onSubmit(save)
            Button("Add", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
    }

    private func save() {
        guard !newTag.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.setTag(newTag, for: entry)
        addingNew = false
    }
}

/// One row in the tag list: a checkmark column, then the content, with a hover highlight.
private struct TagChoice<Content: View>: View {
    let selected: Bool
    @ViewBuilder let content: () -> Content
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(selected ? 1 : 0)
                content()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The day's featured term in the empty definition pane; click to open it.
struct TermOfTheDay: View {
    let entry: GlossaryEntry?
    let open: (GlossaryEntry) -> Void
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        if let entry {
            Button { open(entry) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Term of the day")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.accent)
                    Text(entry.term)
                        .font(theme.heading(16))
                        .foregroundStyle(theme.textPrimary)
                    if let tag = entry.tags.first {
                        Badge(label: tag, fill: theme.badges.fill(forTag: tag))
                    }
                    Text(entry.definition)
                        .font(theme.body(12))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: 300, alignment: .leading)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).strokeBorder(theme.separator))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Body text that pulls a leading formula into a callout.
private struct FormattedText: View {
    let text: String
    let size: CGFloat
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        let parts = Formula.split(text)
        VStack(alignment: .leading, spacing: 10) {
            if let formula = parts.formula {
                FormulaCallout(formula: formula)
            }
            if !parts.rest.isEmpty {
                Text(parts.rest)
                    .font(theme.body(size))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FormulaCallout: View {
    let formula: String
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
        VStack(alignment: .leading, spacing: 4) {
            Text("Formula")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(theme.formula.opacity(0.8))
            Text(formula)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.formula)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.formula.opacity(theme.isLight ? 0.10 : 0.08), in: shape)
        .overlay(shape.strokeBorder(theme.formula.opacity(0.30)))
    }
}

/// Finds formulas: a definition that opens with a ratio like `TP / (TP + FP)`, or a note that opens with "Formula:".
enum Formula {
    // Uppercase terms joined by operators, then "/ ( … )", e.g. "TP / (TP + FP)" or "FN / (FN + TP)".
    private static let leadingRatio = try! Regex(#"^[A-Z]{1,4}(\s*[+\-*×]\s*[A-Z]{1,4})*\s*/\s*\([^)]*\)"#)

    static func split(_ text: String) -> (formula: String?, rest: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let match = trimmed.prefixMatch(of: leadingRatio) {
            return (String(trimmed[match.range]), remainder(trimmed[match.range.upperBound...]))
        }
        let label = "Formula:"
        if trimmed.lowercased().hasPrefix(label.lowercased()) {
            let body = trimmed.dropFirst(label.count).trimmingCharacters(in: .whitespaces)
            // The formula runs to the end of its sentence; anything after is ordinary prose.
            if let end = body.range(of: ". ") {
                return (String(body[..<end.lowerBound]), String(body[end.upperBound...]))
            }
            return (body.hasSuffix(".") ? String(body.dropLast()) : body, "")
        }
        return (nil, text)
    }

    private static func remainder(_ s: Substring) -> String {
        var rest = s.drop { $0 == "." || $0 == " " }
        while rest.last == " " { rest = rest.dropLast() }
        return String(rest)
    }
}

private struct NoteView: View {
    let note: GlossaryEntry.Note
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Course note")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(theme.accent)
                if let citation = note.citation, !citation.isEmpty {
                    Text(citation)
                        .font(theme.body(11))
                        .italic()
                        .foregroundStyle(theme.textSecondary)
                }
            }
            FormattedText(text: note.text, size: 13)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(theme.isLight ? 0.08 : 0.07), in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.accent.opacity(0.7)).frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }
}

/// Wraps children onto new lines when they run out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
