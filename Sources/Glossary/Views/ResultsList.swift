import GlossaryCore
import SwiftUI

struct ResultsList: View {
    @ObservedObject var model: GlossaryViewModel
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = sectionTitle {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.top, 9)
                    .padding(.bottom, 4)
            }
            if model.rows.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.panel)
    }

    private var sectionTitle: String? {
        switch model.mode {
        case .recents: model.rows.isEmpty ? nil : "Recent"
        case .browse: "All terms A–Z"
        case .search: model.rows.isEmpty ? nil : "\(model.rows.count) match\(model.rows.count == 1 ? "" : "es")"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.mode == .search {
                Text("No matches").foregroundStyle(theme.textSecondary)
            } else {
                Text("Start typing a term.").foregroundStyle(theme.textSecondary)
                Text("↓ browse from A\n↑ browse from Z").foregroundStyle(theme.textTertiary)
            }
        }
        .font(.system(size: 12))
        .padding(12)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                        RowView(row: row, query: model.query, selected: index == model.selection)
                            .id(row.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                model.selection = index
                                model.open(row.entry)
                            }
                            .simultaneousGesture(TapGesture().onEnded { model.selection = index })
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .onChange(of: model.selection) {
                guard let i = model.selection, model.rows.indices.contains(i) else { return }
                proxy.scrollTo(model.rows[i].id)
            }
            .onChange(of: model.mode) {
                guard let i = model.selection, model.rows.indices.contains(i) else { return }
                proxy.scrollTo(model.rows[i].id)
            }
        }
    }
}

private struct RowView: View {
    let row: ResultRow
    let query: String
    let selected: Bool
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(row.entry.term)
                    .font(theme.body(13, weight: selected ? .medium : .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let tag = row.entry.tags.first {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.badges.fill(forTag: tag))
                        .frame(width: 7, height: 7)
                        .help(row.entry.tags.joined(separator: ", "))
                }
            }
            if let detail = row.detail {
                Text(highlighted(row.match == .alias ? "also: \(detail)" : detail))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background { if selected { selectionBackground } }
    }

    @ViewBuilder private var selectionBackground: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
        switch theme.selectionStyle {
        case .leftBar:
            Rectangle().fill(theme.selection)
                .overlay(alignment: .leading) { Rectangle().fill(theme.accent).frame(width: 3) }
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .fill:
            shape.fill(theme.selection)
        case .outline:
            shape.fill(theme.selection)
                .overlay(shape.strokeBorder(theme.accent, lineWidth: 1.5))
        }
    }

    private func highlighted(_ text: String) -> AttributedString {
        var s = AttributedString(text)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty,
              let r = text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]),
              let ar = Range(r, in: s) else { return s }
        s[ar].foregroundColor = theme.highlight
        s[ar].font = .system(size: 11, weight: .semibold)
        return s
    }
}
