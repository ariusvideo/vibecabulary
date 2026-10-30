import Foundation

/// A prompt people paste into any AI chatbot so it turns their terms into a file this app can open.
/// Each format's example is checked by GlossaryChecks to load cleanly, so the prompt can't drift from the importers.
public enum GlossaryPrompt {
    public enum Format: String, CaseIterable, Identifiable, Sendable {
        case json, csv, markdown

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .json: "JSON"
            case .csv: "CSV"
            case .markdown: "Markdown"
            }
        }

        public var fileExtension: String {
            switch self {
            case .json: "json"
            case .csv: "csv"
            case .markdown: "md"
            }
        }

        /// One line on what the format keeps, for the format picker.
        public var summary: String {
            switch self {
            case .json: "Recommended. Keeps aliases, related terms, tags, sources and notes."
            case .csv: "Easy to edit in a spreadsheet, and long lists can continue across replies. Keeps aliases and sources."
            case .markdown: "Easy to read and edit by hand. Keeps terms and definitions only."
            }
        }
    }

    public static func text(for format: Format) -> String {
        """
        I want to build a glossary file for a Mac glossary app that looks up terms and definitions. \
        Please help me make it by following these steps.

        STEP 1: GATHER THE TERMS
        Ask me for my terms. I might paste a list, my notes or a document, or just name a subject. \
        If I only name a subject, suggest a list of terms first and wait for my OK before writing definitions. \
        Also ask what I want to call the glossary.

        STEP 2: WRITE THE DEFINITIONS
        - Write each definition in one to three plain sentences.
        - When I give you a definition, keep my wording. Fix only typos.
        - Never invent sources, page numbers or citations. Include them only when I give them to you.

        STEP 3: OUTPUT THE FILE
        Put the whole glossary in a single code block, in exactly this format:

        ```\(format.fileExtension)
        \(example(for: format))
        ```

        \(rules(for: format))

        STEP 4: TELL ME HOW TO SAVE IT
        After the code block, tell me how to save it as a plain-text file whose name ends in \
        .\(format.fileExtension) (for example my-glossary.\(format.fileExtension)):
        - If you can create downloadable files, also offer it as a download.
        - Otherwise: copy the code block, open TextEdit, choose Format > Make Plain Text, paste, \
        and save with a name ending in .\(format.fileExtension).
        Then tell me to open the glossary app's Settings, click Choose File… and pick the file.

        Start with Step 1 now.
        """
    }

    private static func rules(for format: Format) -> String {
        switch format {
        case .json:
            """
            Rules for the JSON:
            - "name" (the glossary's title) and "terms" are required. Every term needs "term" and "definition".
            - Every other field is optional. Leave a field out rather than leaving it empty.
            - "aliases": other names or abbreviations someone might search for.
            - "related": other terms in this same glossary, spelled exactly like their "term".
            - "tags": one or two short category labels, used the same way across the glossary.
            - "source" and "citation": only when I give you a source (for example a book and page).
            - "notes": extra tips, each written as {"text": "..."}. Start a note with "Formula:" to show a formula.
            - No duplicate terms. The output must be valid JSON: straight double quotes, no comments, no trailing commas.
            - If the glossary is too long for one reply, stop and suggest that I switch to the CSV format, \
            which can continue across several replies.
            """
        case .csv:
            """
            Rules for the CSV:
            - The first line must be exactly: term,definition,aliases,source,citation
            - One term per line. "term" and "definition" are required. Leave the other columns empty when unknown.
            - "aliases": other names or abbreviations, separated by semicolons.
            - "source" and "citation": only when I give you a source (for example a book and page).
            - Wrap any field that contains a comma, a double quote or a line break in double quotes, \
            and write a double quote inside a field as two double quotes ("").
            - No duplicate terms.
            - If the glossary is too long for one reply, stop at the end of a complete line and continue \
            in your next reply without repeating the header line, so I can paste the parts together.
            """
        case .markdown:
            """
            Rules for the Markdown:
            - The first line is "# " followed by the glossary's title.
            - Each term is a "## " heading, with its definition as a paragraph below it.
            - No other headings, no tables, no duplicate terms.
            """
        }
    }

    /// A small, complete file in `format`. Shown inside the prompt, and checked to load.
    public static func example(for format: Format) -> String {
        switch format {
        case .json:
            """
            {
              "name": "Intro to Statistics",
              "terms": [
                {
                  "term": "mean",
                  "aliases": ["average"],
                  "definition": "The sum of all values divided by how many values there are.",
                  "related": ["median"],
                  "tags": ["Descriptive statistics"],
                  "source": "Course notes",
                  "citation": "Week 2",
                  "notes": [{"text": "Formula: sum of values / number of values."}]
                },
                {
                  "term": "median",
                  "definition": "The middle value when the values are sorted. Outliers affect it less than the mean.",
                  "related": ["mean"],
                  "tags": ["Descriptive statistics"]
                }
              ]
            }
            """
        case .csv:
            """
            term,definition,aliases,source,citation
            mean,The sum of all values divided by how many values there are.,average,Course notes,Week 2
            median,"The middle value when the values are sorted. Outliers affect it less than the mean, so it suits skewed data.",,,
            """
        case .markdown:
            """
            # Intro to Statistics

            ## mean
            The sum of all values divided by how many values there are.

            ## median
            The middle value when the values are sorted. Outliers affect it less than the mean.
            """
        }
    }
}
