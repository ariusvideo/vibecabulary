import Foundation
import GlossaryCore

/// One-time move from the app's old identity ("Glossary", com.stevengladney.glossary) to Vibecabulary:
/// moves the Application Support folder, copies settings across from the old bundle ID, and rewrites
/// saved file paths that pointed into the old folder. Safe to call on every launch.
@MainActor
enum LegacyMigration {
    static let oldBundleID = "com.stevengladney.glossary"
    private static let doneKey = "migratedFromGlossary"

    static var oldSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glossary", isDirectory: true)
    }

    static func run() {
        let fm = FileManager.default
        let oldDir = oldSupportDirectory.path
        let newDir = GlossaryStore.supportDirectory.path
        if !fm.fileExists(atPath: newDir), fm.fileExists(atPath: oldDir) {
            do {
                try fm.moveItem(atPath: oldDir, toPath: newDir)
                rewriteTagEditKeys(from: oldDir, to: newDir)
            } catch {
                NSLog("Vibecabulary: couldn't move \(oldDir): \(error.localizedDescription)")
            }
        }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        for (key, value) in defaults.persistentDomain(forName: oldBundleID) ?? [:]
        where !key.hasPrefix("NS") && defaults.object(forKey: key) == nil {
            if let path = value as? String {
                defaults.set(moved(path, from: oldDir, to: newDir), forKey: key)
            } else {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: doneKey)
    }

    /// Tag edits are keyed by glossary file path, so keys inside the old folder must follow it.
    private static func rewriteTagEditKeys(from oldDir: String, to newDir: String) {
        let url = GlossaryStore.tagEditsURL
        guard let data = try? Data(contentsOf: url),
              var edits = try? JSONDecoder().decode(TagEdits.self, from: data) else { return }
        edits.glossaries = Dictionary(uniqueKeysWithValues: edits.glossaries.map { (moved($0.key, from: oldDir, to: newDir), $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let out = try? encoder.encode(edits) { try? out.write(to: url, options: .atomic) }
    }

    private static func moved(_ path: String, from oldDir: String, to newDir: String) -> String {
        path.hasPrefix(oldDir + "/") ? newDir + path.dropFirst(oldDir.count) : path
    }
}
