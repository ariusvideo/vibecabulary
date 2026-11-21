import AppKit
import GlossaryCore
import ServiceManagement

/// Loads the glossary file, remembers which one is in use, and keeps recent lookups.
@MainActor
final class GlossaryStore: ObservableObject {
    @Published private(set) var document = GlossaryDocument(name: "Glossary", terms: [])
    @Published private(set) var engine = SearchEngine(entries: [])
    @Published private(set) var sourceURL: URL
    @Published private(set) var loadError: String?
    @Published private(set) var recents: [String]
    @Published private(set) var lookups: LookupLog
    @Published private(set) var tagEdits: TagEdits
    /// The glossary as the file has it, before tag edits are applied.
    private var fileDocument = GlossaryDocument(name: "Glossary", terms: [])

    static let maxRecents = 10
    private static let pathKey = "glossaryPath"
    private static let recentsKey = "recentTerms"
    private static let lookupsKey = "lookups"
    private var loadedModificationDate: Date?

    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vibecabulary", isDirectory: true)
    }

    static var defaultFileURL: URL { supportDirectory.appendingPathComponent("sample-glossary.json") }
    static var tagEditsURL: URL { supportDirectory.appendingPathComponent("tag-edits.json") }

    /// The CPMAI tags, offered as starters when a glossary has no tags of its own.
    /// Offered when a glossary has no tags of its own.
    static let starterTags = ["Key term", "Review", "Confusing", "Mastered"]

    init() {
        let defaults = UserDefaults.standard
        recents = defaults.stringArray(forKey: Self.recentsKey) ?? []
        lookups = defaults.data(forKey: Self.lookupsKey)
            .flatMap { try? JSONDecoder().decode(LookupLog.self, from: $0) } ?? LookupLog()
        tagEdits = (try? Data(contentsOf: Self.tagEditsURL))
            .flatMap { try? JSONDecoder().decode(TagEdits.self, from: $0) } ?? TagEdits()
        sourceURL = defaults.string(forKey: Self.pathKey).map { URL(fileURLWithPath: $0) } ?? Self.defaultFileURL
        installBundledGlossaryIfNeeded()
        if !load(sourceURL), sourceURL != Self.defaultFileURL {
            // The chosen file is gone or broken: fall back to the bundled sample glossary.
            let error = loadError
            if load(Self.defaultFileURL) { loadError = error }
        }
    }

    /// First launch: copy the bundled sample glossary into Application Support.
    private func installBundledGlossaryIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: Self.defaultFileURL.path),
              let bundled = Bundle.main.url(forResource: "sample-glossary", withExtension: "json") else { return }
        try? fm.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
        try? fm.copyItem(at: bundled, to: Self.defaultFileURL)
    }

    /// Loads `url`. On failure the previous glossary stays in use and `loadError` explains why.
    @discardableResult
    func load(_ url: URL) -> Bool {
        do {
            fileDocument = try GlossaryLoader.load(from: url)
            sourceURL = url
            if tagEdits.prune(TagEdits.key(for: url), against: fileDocument) { persistTagEdits() }
            applyTagEdits()
            loadError = nil
            loadedModificationDate = Self.modificationDate(url)
            UserDefaults.standard.set(url.path, forKey: Self.pathKey)
            return true
        } catch {
            loadError = "\(url.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }

    func reload() { load(sourceURL) }

    private func applyTagEdits() {
        document = tagEdits.apply(to: fileDocument, key: TagEdits.key(for: sourceURL))
        engine = SearchEngine(entries: document.terms)
    }

    // MARK: Tag edits

    private var editKey: String { TagEdits.key(for: sourceURL) }

    /// Tags offered in the editor and used for badge colors: those this glossary uses
    /// (its declared order, then A–Z), or the starters if it has none.
    var availableTags: [String] {
        let tags = document.orderedTags
        return tags.isEmpty ? Self.starterTags : tags
    }

    func isTagEdited(_ entry: GlossaryEntry) -> Bool { tagEdits.isEdited(entry.term, in: editKey) }

    var tagEditCount: Int { tagEdits.count(in: editKey, document: fileDocument) }

    /// Sets `entry`'s tags (an empty list removes them) and saves the edit.
    func setTags(_ tags: [String], for entry: GlossaryEntry) {
        let original = fileDocument.terms.first { $0.term == entry.term }?.tags ?? []
        tagEdits.set(tags, for: entry.term, original: original, in: editKey)
        saveTagEdits()
    }

    func resetTagEdits() {
        tagEdits.reset(editKey)
        saveTagEdits()
    }

    var canSaveTagsToFile: Bool { sourceURL.pathExtension.lowercased() == "json" }

    /// Writes this glossary's tag edits into the file itself (after backing it up), then clears them.
    /// Returns how many terms changed.
    func saveTagEditsToFile() throws -> Int {
        let backups = Self.supportDirectory.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = backups.appendingPathComponent(
            "\(sourceURL.deletingPathExtension().lastPathComponent) \(stamp).json")
        try FileManager.default.copyItem(at: sourceURL, to: backup)
        let changed = try TagWriter.write(tagEdits.edits(for: editKey), toJSONAt: sourceURL)
        tagEdits.reset(editKey)
        persistTagEdits()
        reload()
        return changed
    }

    func exportTagEdits(to url: URL) throws {
        try tagEdits.exportJSON(for: editKey).write(to: url, options: .atomic)
    }

    private func saveTagEdits() {
        persistTagEdits()
        applyTagEdits()
    }

    private func persistTagEdits() {
        try? FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(tagEdits) { try? data.write(to: Self.tagEditsURL, options: .atomic) }
    }

    /// Picks up edits made to the file since it was loaded.
    func reloadIfChanged() {
        if Self.modificationDate(sourceURL) != loadedModificationDate { reload() }
    }

    private static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    func useDefaultGlossary() {
        installBundledGlossaryIfNeeded()
        load(Self.defaultFileURL)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
    }

    // MARK: Recents

    var recentEntries: [GlossaryEntry] {
        recents.compactMap { engine.entry(named: $0) }
    }

    func addRecent(_ entry: GlossaryEntry) {
        recents.removeAll { $0 == entry.term }
        recents.insert(entry.term, at: 0)
        if recents.count > Self.maxRecents { recents.removeLast(recents.count - Self.maxRecents) }
        UserDefaults.standard.set(recents, forKey: Self.recentsKey)
        lookups.record(entry.term, on: StudyStats.dayKey(Date()))
        UserDefaults.standard.set(try? JSONEncoder().encode(lookups), forKey: Self.lookupsKey)
    }

    // MARK: Study stats

    /// Distinct terms opened today.
    var lookupsToday: Int { lookups.count(on: StudyStats.dayKey(Date())) }

    /// One term per calendar day, stable for the whole day.
    var termOfTheDay: GlossaryEntry? {
        let all = engine.alphabetical
        return StudyStats.dailyIndex(dayKey: StudyStats.dayKey(Date()), count: all.count).map { all[$0] }
    }

    func clearRecents() {
        recents = []
        UserDefaults.standard.removeObject(forKey: Self.recentsKey)
    }

    // MARK: Launch at login

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message, or nil on success.
    func setLaunchAtLogin(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            objectWillChange.send()
            return nil
        } catch {
            objectWillChange.send()
            return "Couldn’t change Launch at Login: \(error.localizedDescription)"
        }
    }
}
