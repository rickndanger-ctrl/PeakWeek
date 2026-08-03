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
    static func attributedWeek(client: Client, program: Program, week: Week) -> NSAttributedString {
        let text = Engine.weekToText(client: client, program: program, week: week)
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

    /// Paginated US-Letter PDF via CTFramesetter — no print panel, fully headless.
    static func pdfData(client: Client, program: Program, week: Week) -> Data? {
        let attr = attributedWeek(client: client, program: program, week: week)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter, 72 dpi
        let textRect = pageRect.insetBy(dx: 54, dy: 54)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        var location = 0
        repeat {
            ctx.beginPDFPage(nil)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            ctx.endPDFPage()
            if visible.length == 0 { break }     // safety: never loop on unrenderable content
            location = visible.location + visible.length
        } while location < attr.length
        ctx.closePDF()
        return data as Data
    }

    /// Suggested file name, e.g. "Sarah — Week 3.pdf"
    static func pdfFileName(client: Client, week: Week) -> String {
        let safe = client.name.replacingOccurrences(of: "/", with: "-")
        return "\(safe) — Week \(week.num).pdf"
    }

    /// Writes the PDF to a temp file for handing to the share sheet.
    static func writeTempPDF(client: Client, program: Program, week: Week) -> URL? {
        guard let data = pdfData(client: client, program: program, week: week) else { return nil }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeakWeekShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(pdfFileName(client: client, week: week))
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return url
    }

    /// Save-panel export for coaches who file PDFs manually.
    static func savePDF(client: Client, program: Program, week: Week) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = pdfFileName(client: client, week: week)
        panel.title = "Export Week \(week.num) as PDF"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = pdfData(client: client, program: program, week: week) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
