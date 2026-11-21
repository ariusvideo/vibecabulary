# Vibecabulary

`{vibe}cabulary`: a menu bar glossary for anything you're learning. Vibe coded, proudly.

Click the `{v}` in the menu bar, or press **⌥⌘G**, and start typing. Bring your own glossary (JSON, CSV or Markdown),
or have any AI chatbot make one for you from your notes. Requires macOS 14 or later; a universal app for Apple silicon and Intel Macs.

| Key | Action |
|---|---|
| type | live matches on term name, aliases, then definition text (2+ chars) |
| ↓ / ↑ | move through results (wraps); on an empty field, list all terms A–Z starting at the first (↓) or last (↑) |
| ⏎ or double-click | show the definition |
| ⌘C | copy term + definition (when no text is selected in the field) |
| ⌘, | settings: choose glossary file, reload, launch at login |
| Esc | clear the field, then back to recents, then close |

## Build and install
Needs only the Swift toolchain (Xcode Command Line Tools); no Xcode project. Bundle ID `com.vibecabulary.app`.
```
scripts/build-app.sh            # release build -> build/Vibecabulary.app -> /Applications
swift run GlossaryChecks        # search/importer checks (CLT has no XCTest)
```

## Glossary files
The app starts with a small study-skills sample (`Resources/sample-glossary.json`, copied to
`~/Library/Application Support/Vibecabulary/` on first launch). Use your own with Settings → Choose File….
Settings → Choose File… accepts:
- **JSON** (canonical): `{"name", "version", "tags", "terms": [{"term", "definition", "aliases", "source", "citation", "notes": [{"text", "citation"}], "related", "tags"}]}`. Only `term` and `definition` are required.
- **CSV**: header with `term,definition` (optional `aliases` separated by `;`, `source`, `citation`).
- **Markdown**: `## Term` headings with the definition below, or `- **Term**: definition` lines.

Edits to the file are picked up the next time the popover opens.

### Making a glossary with an AI chatbot
Settings → **Make with AI…** copies a ready-made prompt (JSON, CSV or Markdown) to paste into any chatbot. The chatbot asks
for your terms, writes the file in the right format and explains how to save it; then choose it with Choose File….
The prompt text lives in `Sources/GlossaryCore/GlossaryPrompt.swift`, and `GlossaryChecks` loads the example embedded in
each prompt, so the prompt can't drift from what the importers accept.

## Tags and tag edits
Entries may carry `tags`, shown as colored badges. Glossaries without tags work normally, and the
tag editor then offers a few general starters (Key term, Review, Confusing, Mastered).
A JSON glossary can list its tags at the top level (`"tags": ["Week 1", "Week 2", …]`) to set the order
they're listed in; badge colors follow that order. Without it, tags are listed A–Z.
Click a term's tag badge (or "+ Tag") to change it. Edits are stored per glossary file in
`~/Library/Application Support/Vibecabulary/tag-edits.json`, never in the glossary itself, so replacing the glossary file keeps them.
Settings → Tag edits → **Save to file** writes them into the glossary JSON (backed up first to
`Application Support/Vibecabulary/Backups/`) and clears them; CSV and Markdown glossaries keep edits in the app.
**Export…** writes them as `{term: tag}` (`null` = removed).

## Themes
Five looks in Settings → Theme: Reading room (default), Reading room light, Liquid Glass, Study deck and Midnight aurora.

## License
MIT. See `LICENSE`.
