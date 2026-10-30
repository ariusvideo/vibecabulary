import AppKit
import Carbon.HIToolbox
import Combine
import GlossaryCore
import UniformTypeIdentifiers

/// What the left-hand list is showing.
enum ListMode: Equatable {
    case recents
    /// Every term, A–Z.
    case browse
    case search
}

/// One row in the results list.
struct ResultRow: Identifiable, Hashable {
    let entry: GlossaryEntry
    let match: SearchResult.Match?
    let detail: String?
    var id: String { entry.id }
}

@MainActor
final class GlossaryViewModel: ObservableObject {
    let store: GlossaryStore

    @Published var query = "" { didSet { if query != oldValue { queryChanged() } } }
    @Published private(set) var mode: ListMode = .recents
    @Published private(set) var rows: [ResultRow] = []
    @Published var selection: Int?
    @Published private(set) var displayed: GlossaryEntry?
    @Published var showingSettings = false
    @Published var settingsMessage: String?
    @Published private(set) var focusToken = 0
    @Published private(set) var copiedFlash = false

    var closePopover: () -> Void = {}
    var pinPopover: (Bool) -> Void = { _ in }

    private var cancellables: Set<AnyCancellable> = []

    init(store: GlossaryStore) {
        self.store = store
        store.$engine.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.glossaryChanged() }
        }.store(in: &cancellables)
        showRecents()
    }

    var selectedEntry: GlossaryEntry? {
        guard let selection, rows.indices.contains(selection) else { return nil }
        return rows[selection].entry
    }

    // MARK: Popover lifecycle

    func willShow() {
        store.reloadIfChanged()
        store.objectWillChange.send() // refresh the "today" count and term of the day after midnight
        showingSettings = false
        if query.isEmpty { showRecents() }
        focusToken += 1
    }

    // MARK: List contents

    private func queryChanged() {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            showRecents()
            return
        }
        mode = .search
        rows = store.engine.search(query).map { ResultRow(entry: $0.entry, match: $0.match, detail: $0.detail) }
        selection = rows.isEmpty ? nil : 0
    }

    private func showRecents() {
        mode = .recents
        rows = store.recentEntries.map { ResultRow(entry: $0, match: nil, detail: nil) }
        selection = nil
    }

    /// Lists every term A–Z, selecting the first (↓) or the last (↑).
    private func browse(selectLast: Bool = false) {
        mode = .browse
        rows = store.engine.alphabetical.map { ResultRow(entry: $0, match: nil, detail: nil) }
        selection = rows.isEmpty ? nil : (selectLast ? rows.count - 1 : 0)
    }

    private func glossaryChanged() {
        // Keep the selected row selected (e.g. after a tag edit), if it still exists.
        let selectedTerm = selectedEntry?.term
        switch mode {
        case .recents: showRecents()
        case .browse: browse()
        case .search: queryChanged()
        }
        if let selectedTerm, let i = rows.firstIndex(where: { $0.entry.term == selectedTerm }) { selection = i }
        if let shown = displayed { displayed = store.engine.entry(named: shown.term) }
    }

    // MARK: Actions

    /// ↓ / ↑. With an empty field and no list yet, lists every term A–Z and starts
    /// at the first term (↓) or the last (↑).
    func moveSelection(down: Bool) {
        if query.isEmpty && mode == .recents {
            browse(selectLast: !down)
            return
        }
        guard !rows.isEmpty else { return }
        guard let current = selection else {
            selection = down ? 0 : rows.count - 1
            return
        }
        selection = (current + (down ? 1 : -1) + rows.count) % rows.count
    }

    func select(_ entry: GlossaryEntry) {
        selection = rows.firstIndex { $0.entry == entry }
    }

    func openSelection() {
        if let entry = selectedEntry { open(entry) }
    }

    func open(_ entry: GlossaryEntry) {
        displayed = entry
        store.addRecent(entry)
    }

    var termOfTheDay: GlossaryEntry? { store.termOfTheDay }
    var lookupsToday: Int { store.lookupsToday }

    func openTermOfTheDay() {
        guard let entry = store.termOfTheDay else { return }
        open(entry)
        select(entry)
    }

    func openRelated(_ name: String) {
        guard let entry = store.engine.entry(named: name) else { return }
        open(entry)
        select(entry)
    }

    func copyCurrent() {
        guard let entry = displayed ?? selectedEntry else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.copyText, forType: .string)
        copiedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.copiedFlash = false }
    }

    func escape() {
        if showingSettings {
            showingSettings = false
        } else if !query.isEmpty {
            query = ""
        } else if mode != .recents {
            showRecents()
        } else {
            closePopover()
        }
        focusToken += 1
    }

    // MARK: Keyboard

    /// Returns true when the key was handled and should not reach the text field.
    func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if Int(event.keyCode) == kVK_Escape {
            escape()
            return true
        }
        if mods.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c" where !fieldHasSelectedText:
                copyCurrent()
                return true
            case ",":
                showingSettings.toggle()
                return true
            case "w":
                closePopover()
                return true
            default:
                return false
            }
        }
        guard !showingSettings, mods.isDisjoint(with: [.command, .option, .control]) else { return false }
        switch Int(event.keyCode) {
        case kVK_DownArrow:
            moveSelection(down: true)
            return true
        case kVK_UpArrow:
            moveSelection(down: false)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            openSelection()
            return true
        default:
            return false
        }
    }

    private var fieldHasSelectedText: Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }

    // MARK: Settings

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Glossary File"
        panel.message = "JSON, CSV (term, definition columns) or Markdown"
        panel.allowedContentTypes = GlossaryLoader.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.sourceURL.deletingLastPathComponent()
        pinPopover(true)
        let response = panel.runModal()
        pinPopover(false)
        guard response == .OK, let url = panel.url else { return }
        settingsMessage = store.load(url) ? "Loaded \(store.document.terms.count) terms." : nil
    }

    // MARK: Tag edits

    /// Replaces `entry`'s tag; nil removes it.
    func setTag(_ tag: String?, for entry: GlossaryEntry) {
        let cleaned = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setTags(cleaned.map { $0.isEmpty ? [] : [$0] } ?? [], for: entry)
    }

    func resetTagEdits() {
        let n = store.tagEditCount
        store.resetTagEdits()
        settingsMessage = "Reset \(n) tag edit\(n == 1 ? "" : "s")."
    }

    func saveTagEditsToFile() {
        do {
            let n = try store.saveTagEditsToFile()
            settingsMessage = "Saved \(n) tag change\(n == 1 ? "" : "s") into \(store.sourceURL.lastPathComponent). A backup is in Application Support/Vibecabulary/Backups."
        } catch {
            settingsMessage = "Couldn’t save: \(error.localizedDescription)"
        }
    }

    func exportTagEdits() {
        let panel = NSSavePanel()
        panel.title = "Export Tag Edits"
        panel.nameFieldStringValue = "tag-edits-export.json"
        panel.allowedContentTypes = [.json]
        pinPopover(true)
        let response = panel.runModal()
        pinPopover(false)
        guard response == .OK, let url = panel.url else { return }
        do {
            try store.exportTagEdits(to: url)
            settingsMessage = "Exported \(store.tagEditCount) tag edits."
        } catch {
            settingsMessage = "Couldn’t export: \(error.localizedDescription)"
        }
    }

    func reload() {
        store.reload()
        settingsMessage = store.loadError == nil ? "Reloaded \(store.document.terms.count) terms." : nil
    }

    func useDefault() {
        store.useDefaultGlossary()
        settingsMessage = store.loadError == nil ? "Using the bundled sample glossary." : nil
    }

    func setLaunchAtLogin(_ on: Bool) {
        settingsMessage = store.setLaunchAtLogin(on)
    }
}
