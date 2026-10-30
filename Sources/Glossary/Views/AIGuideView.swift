import AppKit
import GlossaryCore
import SwiftUI

/// Settings page that walks someone through making a glossary file with any AI chatbot:
/// pick a format, copy the prompt, then choose the file the chatbot produced.
struct AIGuideView: View {
    @ObservedObject var model: GlossaryViewModel
    let close: () -> Void
    @AppStorage("aiPromptFormat") private var format: GlossaryPrompt.Format = .json
    @State private var copied = false
    @Environment(\.glossaryTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { close() } label: {
                    Label("Settings", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Make a glossary with AI")
                    .font(theme.heading(18))
                Text("Any AI chatbot (ChatGPT, Claude, Gemini, Copilot and others) can turn your notes or a list of terms into a file this app opens.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step(1, "Choose a format") {
                Picker("Format", selection: $format) {
                    ForEach(GlossaryPrompt.Format.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                Text(format.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step(2, "Copy the prompt into a new chat") {
                HStack(spacing: 10) {
                    Button(action: copy) {
                        Label(copied ? "Copied" : "Copy Prompt", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundStyle(theme.onAccent)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Copy the prompt for \(format.displayName) to the clipboard")
                    Text("The chatbot asks for your terms. Paste a list or notes, or just name a subject.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            step(3, "Save the reply as a .\(format.fileExtension) file and choose it") {
                Button("Choose File…") {
                    model.chooseFile()
                    if model.settingsMessage != nil { close() }
                }
            }

            DisclosureGroup("Writing the file yourself? Format details") {
                Text(Self.formatDetails)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .font(.system(size: 11))
            .foregroundStyle(theme.textTertiary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt preview")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                ScrollView {
                    Text(GlossaryPrompt.text(for: format))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(theme.field, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.separator))
            }
        }
        .onChange(of: format) { copied = false }
    }

    static let formatDetails = """
        JSON (preferred): {"name": "…", "terms": [{"term": "…", "definition": "…"}]}. Optional per term: \
        aliases, related, tags (lists of text), source, citation, and notes ([{"text": "…", "citation": "…"}]).
        CSV: a header row with term and definition columns; optional aliases (separated by ;), source and citation.
        Markdown: ## Term headings with the definition below, or - **Term**: definition lines.
        """

    private func step<Content: View>(_ number: Int, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 18, height: 18)
                .background(theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .medium))
                content()
            }
        }
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(GlossaryPrompt.text(for: format), forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}

extension GlossaryTheme {
    /// Black or white, whichever contrasts more with `accent` (WCAG relative luminance).
    var onAccent: Color {
        guard let c = NSColor(accent).usingColorSpace(.sRGB) else { return .white }
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.039_28 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
        return luminance > 0.179 ? Color(hex: 0x14120F) : .white
    }
}
