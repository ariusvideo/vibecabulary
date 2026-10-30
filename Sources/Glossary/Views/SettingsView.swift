import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GlossaryViewModel
    @ObservedObject private var store: GlossaryStore
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .readingRoom
    @Environment(\.glossaryTheme) private var theme
    @State private var showingGuide = false

    init(model: GlossaryViewModel) {
        self.model = model
        self.store = model.store
    }

    var body: some View {
        ZStack {
            (theme.usesMaterial ? Color.black.opacity(0.45) : theme.background.opacity(0.85))
                .onTapGesture { model.showingSettings = false }
            Group {
                if showingGuide {
                    AIGuideView(model: model) { showingGuide = false }
                } else {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("Settings")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button("Done") { model.showingSettings = false }
                                .keyboardShortcut(.defaultAction)
                        }

                        section("Glossary file") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.document.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(store.sourceURL.path(percentEncoded: false))
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            HStack(spacing: 8) {
                                Button("Choose File…") { model.chooseFile() }
                                Button("Reveal in Finder") { store.revealInFinder() }
                                Button("Reload") { model.reload() }
                                if store.sourceURL != GlossaryStore.defaultFileURL {
                                    Button("Use Sample Glossary") { model.useDefault() }
                                }
                            }
                            Text("Accepts .json, .csv or .md files. Edits to the file load the next time the window opens.")
                                .help(AIGuideView.formatDetails)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(theme.accent)
                                Text("No file yet? Have an AI chatbot make one.")
                                    .font(.system(size: 12))
                                Spacer(minLength: 0)
                                Button("Make with AI…") { showingGuide = true }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                        }

                        section("General") {
                            Toggle("Launch at login", isOn: Binding(
                                get: { store.launchAtLogin },
                                set: { model.setLaunchAtLogin($0) }))
                            HStack {
                                Text("Open Vibecabulary from anywhere")
                                Spacer()
                                Text(HotKey.defaultDisplay)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.field, in: RoundedRectangle(cornerRadius: 4))
                            }
                            HStack {
                                Text("Recent lookups: \(store.recents.count)")
                                Spacer()
                                Button("Clear") { store.clearRecents(); model.query = "" }
                                    .disabled(store.recents.isEmpty)
                            }
                            HStack {
                                Text("Tag edits for this glossary: \(store.tagEditCount)")
                                    .help("Tags you changed in the app. They're stored apart from the glossary file.")
                                Spacer()
                                Button("Save to file") { model.saveTagEditsToFile() }
                                    .disabled(store.tagEditCount == 0 || !store.canSaveTagsToFile)
                                    .help(store.canSaveTagsToFile
                                          ? "Write these tags into the glossary file and clear the edits (the file is backed up first)"
                                          : "Only JSON glossaries can be saved to; CSV and Markdown edits stay in the app")
                                Button("Export…") { model.exportTagEdits() }
                                    .disabled(store.tagEditCount == 0)
                                Button("Reset") { model.resetTagEdits() }
                                    .disabled(store.tagEditCount == 0)
                            }
                        }

                        section("Theme") {
                            HStack(spacing: 8) {
                                ForEach(ThemeID.allCases) { id in
                                    ThemeSwatch(id: id, selected: id == themeID) { themeID = id }
                                }
                            }
                        }

                        if let error = store.loadError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orange)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let message = model.settingsMessage {
                            Label(message, systemImage: "checkmark.circle")
                                .foregroundStyle(theme.accent)
                                .font(.system(size: 12))
                        }

                        Spacer(minLength: 0)
                        HStack {
                            Spacer()
                            Button("Quit Vibecabulary") { NSApp.terminate(nil) }
                        }
                    }
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(theme.textPrimary)
            .padding(20)
            .frame(width: 500, height: 490)
            .background { cardBackground.clipShape(RoundedRectangle(cornerRadius: 12)) }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator))
        }
        .onDisappear { model.settingsMessage = nil; showingGuide = false }
    }

    /// Translucent themes get a near-opaque card so the settings stay readable over the list.
    @ViewBuilder private var cardBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.regularMaterial).overlay(Color(hex: 0x1E2026).opacity(0.8))
        } else {
            theme.panel
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
            content()
        }
    }
}

/// A miniature of a theme: background, list panel, selected row and accent, with the name below.
private struct ThemeSwatch: View {
    let id: ThemeID
    let selected: Bool
    let action: () -> Void
    @Environment(\.glossaryTheme) private var current

    var body: some View {
        let t = id.theme
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        RoundedRectangle(cornerRadius: 1).fill(t.textTertiary).frame(width: 22, height: 3)
                        RoundedRectangle(cornerRadius: 1).fill(t.accent).frame(width: 26, height: 5)
                        RoundedRectangle(cornerRadius: 1).fill(t.textTertiary).frame(width: 18, height: 3)
                    }
                    .padding(5)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(t.usesMaterial ? Color.white.opacity(0.10) : t.panel)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aa")
                            .font(.system(size: 11, weight: .semibold, design: t.headingDesign))
                            .foregroundStyle(t.textPrimary)
                        RoundedRectangle(cornerRadius: 1).fill(t.formula).frame(width: 20, height: 3)
                        RoundedRectangle(cornerRadius: 1).fill(t.textSecondary).frame(width: 26, height: 3)
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: 84, height: 50)
                .background(swatchBackground(t))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? current.accent : current.separator, lineWidth: selected ? 2 : 1))
                Text(id.displayName)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? current.textPrimary : current.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 84)
            }
        }
        .buttonStyle(.plain)
        .help(id.displayName)
    }

    private func swatchBackground(_ t: GlossaryTheme) -> AnyShapeStyle {
        t.usesMaterial
            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x3A4256), Color(hex: 0x1E2230)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(t.background)
    }
}
