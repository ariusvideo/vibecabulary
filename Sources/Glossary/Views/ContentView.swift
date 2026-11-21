import GlossaryCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: GlossaryViewModel
    @ObservedObject private var store: GlossaryStore
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .readingRoom
    @FocusState private var fieldFocused: Bool

    init(model: GlossaryViewModel) {
        self.model = model
        self.store = model.store
    }

    private var theme: GlossaryTheme {
        var t = themeID.theme
        t.badges.tagOrder = store.availableTags
        return t
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if theme.accentStrip {
                LinearGradient(colors: [theme.accent, theme.formula], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
            } else {
                Divider().overlay(theme.separator)
            }
            HStack(spacing: 0) {
                ResultsList(model: model)
                    .frame(width: 230)
                Divider().overlay(theme.separator)
                DefinitionView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().overlay(theme.separator)
            footer
        }
        .frame(width: StatusItemController.popoverSize.width, height: StatusItemController.popoverSize.height)
        .background { ThemeBackground() }
        .overlay {
            if model.showingSettings {
                SettingsView(model: model)
                    .transition(.opacity)
            }
        }
        .environment(\.glossaryTheme, theme)
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: model.focusToken) { fieldFocused = true }
        .onAppear { fieldFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)
            TextField("Search \(store.document.terms.count) terms", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(theme.textPrimary)
                .focused($fieldFocused)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear (Esc)")
            }
            TodayCounter(count: model.lookupsToday)
            Button { model.showingSettings.toggle() } label: {
                Image(systemName: "gearshape").foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(theme.field)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(store.document.terms.count) terms · \(store.document.name)")
                .lineLimit(1)
                .truncationMode(.middle)
            if store.loadError != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(store.loadError ?? "")
            }
            Spacer()
            Text("↑↓ select  ⏎ open  esc clear")
                .foregroundStyle(theme.textTertiary)
            Button { model.copyCurrent() } label: {
                Label(model.copiedFlash ? "Copied" : "Copy", systemImage: model.copiedFlash ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.copiedFlash ? theme.accent : theme.textSecondary)
            .disabled(model.displayed == nil && model.selectedEntry == nil)
            .help("Copy term and definition (⌘C)")
        }
        .font(.system(size: 11))
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(theme.panel)
    }
}

/// The popover's backdrop: a flat color, or glass/material for themes that use it.
private struct ThemeBackground: View {
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        if theme.usesMaterial {
            if #available(macOS 26, *) {
                theme.background.glassEffect(.regular, in: Rectangle())
            } else {
                theme.background.background(.ultraThinMaterial)
            }
        } else {
            theme.background
        }
    }
}

/// The "N today" counter in the search bar: distinct terms opened today.
struct TodayCounter: View {
    let count: Int?
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        if let count {
            Text("\(count) today")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(theme.panel, in: Capsule())
                .help("Terms looked up today")
        }
    }
}
