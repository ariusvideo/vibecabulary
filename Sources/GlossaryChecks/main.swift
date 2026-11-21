// Checks for GlossaryCore. Run with `swift run GlossaryChecks`.
// (Command Line Tools ship without XCTest or Swift Testing, so this is a plain executable.)
import Foundation
import GlossaryCore

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0

func expect(_ condition: Bool, _ message: String = "", line: Int = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("FAIL line \(line)\(message.isEmpty ? "" : ": " + message)")
    }
}

private let sample: [GlossaryEntry] = [
    GlossaryEntry(term: "precision", definition: "TP / (TP + FP)."),
    GlossaryEntry(term: "sensitivity (recall)", definition: "Proportion of actual positives found.",
                  aliases: ["sensitivity", "recall"]),
    GlossaryEntry(term: "predictive analytics", definition: "Uses historical data to forecast."),
    GlossaryEntry(term: "Specificity", definition: "TN / (TN + FP). Unlike precision, it looks at negatives."),
    GlossaryEntry(term: "support vector machine (SVM)", definition: "Finds the optimal hyperplane."),
    GlossaryEntry(term: "Bayes’ theorem", definition: "Prior knowledge of conditions."),
    GlossaryEntry(term: "4D task", definition: "Dull, dear, dangerous/dirty, demeaning."),
]

struct SearchTests {
    let engine = SearchEngine(entries: sample)

    func termPrefixRanksAboveDefinitionHits() {
        let r = engine.search("prec")
        expect(r.map(\.entry.term) == ["precision", "Specificity"])
        expect(r[0].match == .prefix)
        expect(r[1].match == .definition)
        expect(r[1].detail?.localizedCaseInsensitiveContains("precision") == true)
    }

    func caseAndQuoteInsensitive() {
        expect(engine.search("PRE").first?.entry.term == "precision")
        expect(engine.search("bayes' th").first?.entry.term == "Bayes’ theorem")
    }

    func wordPrefixAndAlias() {
        let words = engine.search("vec mach")
        expect(words.first?.entry.term == "support vector machine (SVM)")
        expect(words.first?.match == .wordPrefix)
        let alias = engine.search("svm")
        expect(alias.first?.entry.term == "support vector machine (SVM)")
    }

    func singleCharacterSkipsDefinitions() {
        expect(engine.search("t").allSatisfy { $0.match != .definition })
    }

    func browseOrders() {
        let az = engine.browse(ascending: true).map(\.term)
        expect(az.first == "4D task")
        expect(az.last == "support vector machine (SVM)")
        expect(engine.browse(ascending: false).map(\.term) == az.reversed())
    }

    func lookupByNameOrAlias() {
        expect(engine.entry(named: "Recall")?.term == "sensitivity (recall)")
        expect(engine.entry(named: "nope") == nil)
    }
}

struct ImporterTests {
    func csvWithHeaderQuotesAndNewlines() {
        let csv = #"""
        definition,term,aliases
        "A measure, with commas",accuracy,acc;ACC
        "Line one
        line two ""quoted""",epoch,
        ,missing term,
        """#
        let e = CSVImporter.entries(from: csv)
        expect(e.count == 2)
        expect(e[0].term == "accuracy")
        expect(e[0].definition == "A measure, with commas")
        expect(e[0].aliases == ["acc", "ACC"])
        expect(e[1].definition == "Line one\nline two \"quoted\"")
    }

    func csvWithoutHeader() {
        let e = CSVImporter.entries(from: "alpha,first letter\nbeta,second letter\n")
        expect(e.map(\.term) == ["alpha", "beta"])
    }

    func markdownHeadings() {
        let md = """
        # My Glossary

        ## Churn
        Customers who leave.
        - often monthly

        ## Drift
        Change over time.
        """
        let doc = MarkdownImporter.document(from: md, fallbackName: "x")
        expect(doc.name == "My Glossary")
        expect(doc.terms.map(\.term) == ["Churn", "Drift"])
        expect(doc.terms[0].definition == "Customers who leave.\n• often monthly")
    }

    func markdownListItems() {
        let md = "- **Hallucination** (M2 L42): A confident false output.\n- **RAG**: Retrieve then generate."
        let doc = MarkdownImporter.document(from: md, fallbackName: "Notes")
        expect(doc.name == "Notes")
        expect(doc.terms.map(\.term) == ["Hallucination", "RAG"])
        expect(doc.terms[1].definition == "Retrieve then generate.")
    }

    func jsonRoundTripAndValidation() throws {
        let doc = GlossaryDocument(name: "T", terms: sample + [GlossaryEntry(term: "PRECISION", definition: "dup")])
        let data = try JSONEncoder().encode(doc)
        let decoded = try GlossaryLoader.decodeJSON(String(decoding: data, as: UTF8.self))
        let valid = try GlossaryLoader.validated(decoded)
        expect(valid.terms.count == sample.count)
        expect(valid.terms[1].aliases == ["sensitivity", "recall"])
        do {
            _ = try GlossaryLoader.validated(GlossaryDocument(name: "E", terms: []))
            expect(false, "empty glossary should throw")
        } catch {
            expect(error as? GlossaryLoadError == .empty)
        }
    }

    func tagsRoundTrip() throws {
        let tagged = GlossaryEntry(term: "data drift", definition: "Inputs change over time.", tags: ["Phase VI", "Foundations"])
        let decoded = try JSONDecoder().decode(GlossaryEntry.self, from: JSONEncoder().encode(tagged))
        expect(decoded.tags == ["Phase VI", "Foundations"])
        expect(decoded == tagged)
        let untagged = try JSONEncoder().encode(GlossaryEntry(term: "epoch", definition: "One pass."))
        expect(!String(decoding: untagged, as: UTF8.self).contains("tags"), "empty tags should not be encoded")
        let bare = try GlossaryLoader.decodeJSON(#"{"name":"T","terms":[{"term":"a","definition":"b"}]}"#)
        expect(bare.terms[0].tags == [])
    }

    func declaredTagOrder() throws {
        let doc = try GlossaryLoader.decodeJSON(#"""
        {"name":"T","tags":["Zeta","Alpha","Unused","Zeta"],"terms":[
          {"term":"a","definition":"d","tags":["Alpha"]},{"term":"b","definition":"d","tags":["Beta"]},
          {"term":"c","definition":"d","tags":["Zeta"]}]}
        """#)
        expect(doc.orderedTags == ["Zeta", "Alpha", "Beta"], "\(doc.orderedTags)")
        let undeclared = GlossaryDocument(name: "T", terms: [GlossaryEntry(term: "a", definition: "d", tags: ["b10"]),
                                                             GlossaryEntry(term: "b", definition: "d", tags: ["b9"])])
        expect(undeclared.orderedTags == ["b9", "b10"])
        let encoded = String(decoding: try JSONEncoder().encode(undeclared), as: UTF8.self)
        expect(!encoded.contains("\"tags\":null"), "undeclared order should not be encoded")
    }

    /// The examples inside the AI prompt must load, or chatbots would copy a format the app rejects.
    func promptExamplesLoad() throws {
        let json = try GlossaryLoader.validated(GlossaryLoader.decodeJSON(GlossaryPrompt.example(for: .json)))
        expect(json.name == "Intro to Statistics")
        expect(json.terms.map(\.term) == ["mean", "median"])
        expect(json.terms[0].aliases == ["average"] && json.terms[0].notes.count == 1 && json.terms[0].tags.count == 1)
        let engine = SearchEngine(entries: json.terms)
        for entry in json.terms {
            for name in entry.related { expect(engine.entry(named: name) != nil, "prompt example: \(name)") }
        }
        let csv = CSVImporter.entries(from: GlossaryPrompt.example(for: .csv))
        expect(csv.map(\.term) == ["mean", "median"])
        expect(csv[0].aliases == ["average"] && csv[0].citation == "Week 2")
        expect(csv[1].definition.contains("mean, so"), "quoted comma should stay in the definition")
        let md = MarkdownImporter.document(from: GlossaryPrompt.example(for: .markdown), fallbackName: "x")
        expect(md.name == "Intro to Statistics")
        expect(md.terms.map(\.term) == ["mean", "median"])
        for format in GlossaryPrompt.Format.allCases {
            let prompt = GlossaryPrompt.text(for: format)
            expect(prompt.contains(GlossaryPrompt.example(for: format)), "\(format) prompt embeds its example")
            expect(prompt.contains("." + format.fileExtension))
        }
    }

    private var resources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
    }

    /// The glossary every build ships with.
    func bundledSampleGlossaryLoads() throws {
        let doc = try GlossaryLoader.load(from: resources.appendingPathComponent("sample-glossary.json"))
        expect(doc.terms.count >= 20)
        let engine = SearchEngine(entries: doc.terms)
        expect(engine.entry(named: "SRS")?.term == "spaced repetition")
        for entry in doc.terms {
            expect(!entry.tags.isEmpty, "untagged sample term \(entry.term)")
            for name in entry.related { expect(engine.entry(named: name) != nil, "\(entry.term) -> \(name)") }
        }
    }

    /// The personal CPMAI glossary is © PMI and never committed, so this runs only where the file exists.
    func cpmaiGlossaryLoadsIfPresent() throws {
        let url = resources.appendingPathComponent("cpmai-glossary.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let doc = try GlossaryLoader.load(from: url)
        expect(doc.terms.count > 350)
        let engine = SearchEngine(entries: doc.terms)
        expect(engine.search("spec").first?.entry.definition.hasPrefix("TN / (TN + FP)") == true)
        expect(engine.entry(named: "accuracy")?.notes.isEmpty == false)
        for entry in doc.terms {
            for name in entry.related { expect(engine.entry(named: name) != nil, "\(entry.term) -> \(name)") }
        }
        let known: Set<String> = ["Foundations", "Trustworthy AI", "Phase I", "Phase II", "Phase III",
                                  "Phase IV", "Phase V", "Phase VI"]
        for entry in doc.terms {
            expect(entry.tags.count == 1 && known.contains(entry.tags[0]), "tag on \(entry.term): \(entry.tags)")
        }
    }
}

struct StudyStatsTests {
    func dailyPickIsStablePerDay() {
        let a = StudyStats.dailyIndex(dayKey: "2026-10-25", count: 369)
        expect(a != nil && a == StudyStats.dailyIndex(dayKey: "2026-10-25", count: 369))
        let week = (20...26).compactMap { StudyStats.dailyIndex(dayKey: "2026-10-\($0)", count: 369) }
        expect(Set(week).count >= 6, "picks should vary across a week: \(week)")
        expect(StudyStats.dailyIndex(dayKey: "2026-10-25", count: 0) == nil)
    }

    func dayKeyUsesLocalMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let lateNight = cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 59))!
        expect(StudyStats.dayKey(lateNight, calendar: cal) == "2026-10-25")
        expect(StudyStats.dayKey(lateNight.addingTimeInterval(120), calendar: cal) == "2026-10-26")
    }

    func lookupLogCountsDistinctAndResets() {
        var log = LookupLog()
        log.record("precision", on: "2026-10-25")
        log.record("recall", on: "2026-10-25")
        log.record("precision", on: "2026-10-25")
        expect(log.count(on: "2026-10-25") == 2)
        expect(log.count(on: "2026-10-26") == 0)
        log.record("epoch", on: "2026-10-26")
        expect(log.count(on: "2026-10-26") == 1 && log.terms == ["epoch"])
    }
}

/// Glossaries from other sources may have no tags at all; nothing should depend on them.
func untaggedGlossariesWork() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("glossary-checks-\(getpid())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let files = [
        "plain.json": #"{"name": "Plain", "terms": [{"term": "churn", "definition": "Customers who leave."}]}"#,
        "plain.csv": "term,definition\nchurn,Customers who leave.\n",
        "plain.md": "## Churn\nCustomers who leave.\n",
    ]
    for (name, text) in files {
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let doc = try GlossaryLoader.load(from: url)
        expect(doc.terms.count == 1 && doc.terms[0].tags.isEmpty, "\(name) loads with no tags")
        let engine = SearchEngine(entries: doc.terms)
        expect(engine.search("chu").count == 1 && engine.browse(ascending: true).count == 1, "\(name) searchable")
        let data = try JSONEncoder().encode(doc.terms[0])
        expect(!String(decoding: data, as: UTF8.self).contains("tags"), "\(name): empty tags not written")
    }
}

struct TagEditTests {
    let doc = GlossaryDocument(name: "T", terms: [
        GlossaryEntry(term: "precision", definition: "d", tags: ["Phase I"]),
        GlossaryEntry(term: "epoch", definition: "d", tags: ["Phase IV"]),
        GlossaryEntry(term: "churn", definition: "d"),
    ])

    func editsApplyPerGlossary() {
        var edits = TagEdits()
        edits.set(["Phase V"], for: "precision", original: ["Phase I"], in: "/a.json")
        edits.set(["Phase II"], for: "churn", original: [], in: "/a.json")
        edits.set([], for: "epoch", original: ["Phase IV"], in: "/a.json")
        let a = edits.apply(to: doc, key: "/a.json")
        expect(a.terms.map(\.tags) == [["Phase V"], [], ["Phase II"]])
        expect(edits.apply(to: doc, key: "/b.json").terms.map(\.tags) == doc.terms.map(\.tags), "other file untouched")
        expect(edits.count(in: "/a.json", document: doc) == 3)
    }

    func revertingDropsTheEdit() {
        var edits = TagEdits()
        edits.set(["Phase V"], for: "precision", original: ["Phase I"], in: "/a.json")
        edits.set(["Phase I"], for: "precision", original: ["Phase I"], in: "/a.json")
        expect(edits.glossaries.isEmpty)
    }

    func staleEditsIgnoredAndResetWorks() throws {
        var edits = TagEdits()
        edits.set(["Phase V"], for: "gone term", original: [], in: "/a.json")
        expect(edits.apply(to: doc, key: "/a.json").terms.map(\.tags) == doc.terms.map(\.tags))
        expect(edits.count(in: "/a.json", document: doc) == 0)
        edits.set([], for: "epoch", original: ["Phase IV"], in: "/a.json")
        let json = String(decoding: try edits.exportJSON(for: "/a.json"), as: UTF8.self)
        expect(json.contains("\"epoch\" : null") && json.contains("\"gone term\" : \"Phase V\""), json)
        let roundTrip = try JSONDecoder().decode(TagEdits.self, from: JSONEncoder().encode(edits))
        expect(roundTrip == edits)
        edits.reset("/a.json")
        expect(edits.edits(for: "/a.json").isEmpty)
    }
}

func tagWriterSavesIntoJSON() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("glossary-writer-\(getpid()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let original = #"{"name": "T", "extra": 1, "terms": [{"term": "precision", "definition": "d", "tags": ["Phase I"], "custom": "kept"}, {"term": "epoch", "definition": "d", "tags": ["Phase IV"]}, {"term": "churn", "definition": "d"}, {"term": "", "definition": "invalid but kept"}]}"#
    try original.write(to: url, atomically: true, encoding: .utf8)
    let n = try TagWriter.write(["precision": ["Phase V"], "epoch": [], "churn": ["New"]], toJSONAt: url)
    expect(n == 3)
    let doc = try GlossaryLoader.load(from: url)
    expect(doc.terms.map(\.tags) == [["Phase V"], [], ["New"]], "\(doc.terms.map(\.tags))")
    let raw = try String(contentsOf: url, encoding: .utf8)
    expect(raw.contains("\"custom\" : \"kept\"") && raw.contains("invalid but kept") && raw.contains("\"extra\" : 1"),
           "other fields and entries preserved")
    var edits = TagEdits()
    edits.set(["Phase V"], for: "precision", original: ["Phase I"], in: "/k")
    edits.set(["Phase II"], for: "epoch", original: ["Phase IV"], in: "/k")
    expect(edits.prune("/k", against: doc) && edits.edits(for: "/k") == ["epoch": ["Phase II"]], "prune drops saved edits")
    do {
        try TagWriter.write([:], toJSONAt: URL(fileURLWithPath: "/tmp/x.csv"))
        expect(false, "CSV should be refused")
    } catch { expect(error is TagWriter.WriteError) }
}

let search = SearchTests()
search.termPrefixRanksAboveDefinitionHits()
search.caseAndQuoteInsensitive()
search.wordPrefixAndAlias()
search.singleCharacterSkipsDefinitions()
search.browseOrders()
search.lookupByNameOrAlias()
let importers = ImporterTests()
importers.csvWithHeaderQuotesAndNewlines()
importers.csvWithoutHeader()
importers.markdownHeadings()
importers.markdownListItems()
try importers.jsonRoundTripAndValidation()
try importers.tagsRoundTrip()
try importers.declaredTagOrder()
try importers.promptExamplesLoad()
try importers.bundledSampleGlossaryLoads()
try importers.cpmaiGlossaryLoadsIfPresent()
try untaggedGlossariesWork()
let tagEdits = TagEditTests()
tagEdits.editsApplyPerGlossary()
tagEdits.revertingDropsTheEdit()
try tagEdits.staleEditsIgnoredAndResetWorks()
try tagWriterSavesIntoJSON()
let study = StudyStatsTests()
study.dailyPickIsStablePerDay()
study.dayKeyUsesLocalMidnight()
study.lookupLogCountsDistinctAndResets()
print(failures == 0 ? "All \(checks) checks passed." : "\(failures) of \(checks) checks failed.")
exit(failures == 0 ? 0 : 1)
