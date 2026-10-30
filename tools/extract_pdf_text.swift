// Writes the text of a PDF to stdout, one "=== PAGE n" marker per page.
// Usage: swift tools/extract_pdf_text.swift <file.pdf> > out.txt
import Foundation
import PDFKit

guard CommandLine.arguments.count > 1,
      let doc = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    FileHandle.standardError.write("usage: extract_pdf_text.swift <file.pdf>\n".data(using: .utf8)!)
    exit(1)
}
for i in 0..<doc.pageCount {
    print("=== PAGE \(i + 1)")
    print(doc.page(at: i)?.string ?? "")
}
