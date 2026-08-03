import AppKit
import CoreText
import UniformTypeIdentifiers

// MARK: - Week export: styled attributed text + paginated PDF.
// The text CONTENT comes from Engine.weekToText — this file only handles
// presentation (styling, pagination) and never invents programming data.

enum WeekExporter {

    // MARK: attributed styling

    /// Styles the plain-text week export for PDF: bold header, bold day titles,
    /// monospaced set lines. Layout-only — the text is Engine.weekToText verbatim.
    static func attributedWeek(client: Client, program: Program, week: Week,
                               library: ExerciseLibrary) -> NSAttributedString {
        let text = Engine.weekToText(client: client, program: program, week: week, library: library)
        let out = NSMutableAttributedString()

        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black,
        ]
        let mono: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.black,
        ]
        let title: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .black),
            .foregroundColor: NSColor.black,
        ]
        let dayTitle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: NSColor.black,
        ]

        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let attrs: [NSAttributedString.Key: Any]
            if i == 0 {
                attrs = title
            } else if line.hasPrefix("  ") {
                attrs = mono                       // numbered set lines / attempt rows
            } else if line.isEmpty || i == 1 {
                attrs = body                       // subtitle + blank separators
            } else {
                attrs = dayTitle                   // day titles, MEET DAY ATTEMPTS, COACH NOTES, RPE guide
            }
            out.append(NSAttributedString(string: line + "\n", attributes: attrs))
            if i == 0 { out.append(NSAttributedString(string: "\n", attributes: body)) }
        }
        return out
    }

    // MARK: PDF rendering

    /// Professionally laid-out week PDF (tables, day bars, attempts grid).
    static func pdfData(client: Client, program: Program, week: Week,
                        library: ExerciseLibrary) -> Data? {
        WeekPDFLayout.render(client: client, program: program, week: week, library: library)
    }

    /// Suggested file name, e.g. "Sarah — Week 3.pdf"
    static func pdfFileName(client: Client, week: Week) -> String {
        let safe = client.name.replacingOccurrences(of: "/", with: "-")
        return "\(safe) — Week \(week.num).pdf"
    }

    /// Writes the PDF to a temp file for handing to the share sheet.
    static func writeTempPDF(client: Client, program: Program, week: Week,
                             library: ExerciseLibrary) -> URL? {
        guard let data = pdfData(client: client, program: program, week: week, library: library) else { return nil }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeakWeekShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(pdfFileName(client: client, week: week))
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return url
    }

    /// Save-panel export for coaches who file PDFs manually.
    static func savePDF(client: Client, program: Program, week: Week, library: ExerciseLibrary) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = pdfFileName(client: client, week: week)
        panel.title = "Export Week \(week.num) as PDF"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = pdfData(client: client, program: program, week: week, library: library) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
