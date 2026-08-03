import AppKit
import CoreText

// MARK: - Professional week PDF: hand-rolled layout engine.
// Clean tables, hard edges, generous whitespace. This is the artifact the
// client receives — it has to read like a coach's letterhead, not a text dump.

enum WeekPDFLayout {

    // Page geometry (US Letter, 72 dpi)
    static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 54
    static var contentLeft: CGFloat { margin }
    static var contentRight: CGFloat { pageRect.width - margin }
    static var contentWidth: CGFloat { contentRight - contentLeft }

    // Column x-positions (right edges for right-aligned numeric columns)
    struct Cols {
        static let exercise = contentLeft + 10
        static let setsRepsCenter: CGFloat = 352
        static let pctCenter: CGFloat = 412
        static let loadRight: CGFloat = 506
        static let rpeCenter: CGFloat = 536
    }

    // Ink
    static let ink = NSColor.black
    static let gray = NSColor(white: 0.42, alpha: 1)
    static let faint = NSColor(white: 0.75, alpha: 1)
    static let barFill = NSColor(red: 0.09, green: 0.094, blue: 0.11, alpha: 1)

    static func phaseAccent(_ p: Phase) -> NSColor {
        switch p {
        case .acc: return NSColor(red: 0.239, green: 0.42, blue: 0.71, alpha: 1)
        case .trans: return NSColor(red: 0.863, green: 0.663, blue: 0.247, alpha: 1)
        case .real: return NSColor(red: 0.788, green: 0.275, blue: 0.235, alpha: 1)
        case .deload: return NSColor(red: 0.243, green: 0.557, blue: 0.361, alpha: 1)
        case .meet: return NSColor(white: 0.15, alpha: 1)
        }
    }

    // MARK: type

    static func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - renderer

    final class Renderer {
        let ctx: CGContext
        var y: CGFloat = 0                    // distance from top of page
        var pageOpen = false

        init(ctx: CGContext) { self.ctx = ctx }

        func beginPage() {
            ctx.beginPDFPage(nil)
            // PDF-native (bottom-up) CTM throughout; every primitive converts
            // its own top-down y exactly once. No CTM flipping — mixing the
            // two is how rects end up mirrored.
            y = margin
            pageOpen = true
        }

        func endPage() {
            guard pageOpen else { return }
            ctx.endPDFPage()
            pageOpen = false
        }

        /// Start a new page if fewer than `needed` points remain.
        func ensure(_ needed: CGFloat) {
            if !pageOpen { beginPage(); return }
            if y + needed > pageRect.height - margin {
                endPage()
                beginPage()
            }
        }

        // Text drawing (top-down coordinates; CTLine draws from baseline).
        @discardableResult
        func draw(_ string: String, x: CGFloat, at yTop: CGFloat, font: NSFont,
                  color: NSColor = WeekPDFLayout.ink, kern: CGFloat = 0,
                  align: NSTextAlignment = .left) -> CGSize {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .kern: kern,
            ]
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: string, attributes: attrs))
            let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
            var drawX = x
            switch align {
            case .center: drawX = x - bounds.width / 2
            case .right: drawX = x - bounds.width
            default: break
            }
            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.textPosition = CGPoint(x: drawX,
                                       y: pageRect.height - yTop - font.ascender)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
            return bounds.size
        }

        /// Word-wrapped paragraph; returns consumed height.
        @discardableResult
        func drawWrapped(_ string: String, x: CGFloat, width: CGFloat, at yTop: CGFloat,
                         font: NSFont, color: NSColor = WeekPDFLayout.ink,
                         lineSpacing: CGFloat = 2) -> CGFloat {
            let para = NSMutableParagraphStyle()
            para.lineSpacing = lineSpacing
            let attr = NSAttributedString(string: string, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: para,
            ])
            let setter = CTFramesetterCreateWithAttributedString(attr)
            let size = CTFramesetterSuggestFrameSizeWithConstraints(
                setter, CFRange(location: 0, length: 0), nil,
                CGSize(width: width, height: .greatestFiniteMagnitude), nil)
            let path = CGPath(rect: CGRect(x: x, y: pageRect.height - yTop - size.height,
                                           width: width, height: size.height), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
            ctx.saveGState()
            ctx.textMatrix = .identity
            CTFrameDraw(frame, ctx)
            ctx.restoreGState()
            return ceil(size.height)
        }

        func fill(_ rect: CGRect, _ color: NSColor) {
            ctx.saveGState()
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: rect.minX, y: pageRect.height - rect.minY - rect.height,
                            width: rect.width, height: rect.height))
            ctx.restoreGState()
        }

        func hairline(atY yTop: CGFloat, from x0: CGFloat = WeekPDFLayout.contentLeft,
                      to x1: CGFloat = WeekPDFLayout.contentRight,
                      color: NSColor = WeekPDFLayout.faint) {
            fill(CGRect(x: x0, y: yTop, width: x1 - x0, height: 0.5), color)
        }
    }

    // MARK: - document

    static func render(client: Client, program: Program, week: Week,
                       library: ExerciseLibrary) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        let r = Renderer(ctx: ctx)
        r.beginPage()

        header(r, client: client, program: program, week: week)
        columnLegend(r)

        for day in week.days {
            dayBlock(r, day: day, client: client, library: library)
        }

        if !week.note.isEmpty {
            notesBlock(r, note: week.note)
        }
        if week.phase == .meet {
            attemptsBlock(r, client: client)
        }
        footer(r)

        r.endPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: sections

    private static func header(_ r: Renderer, client: Client, program: Program, week: Week) {
        // Phase accent bar across the top.
        r.fill(CGRect(x: contentLeft, y: r.y, width: contentWidth, height: 5),
               phaseAccent(week.phase))
        r.y += 14
        r.draw("PEAK WEEK — COACHING PLAN", x: contentLeft, at: r.y,
               font: font(7.5, .bold), color: gray, kern: 1.6)
        // Date range, right-aligned (when the program is anchored).
        if let start = client.startDate {
            let weekStart = DeliverySchedule.weekStart(startDate: start, weekNum: week.num)
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            r.draw("\(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))",
                   x: contentRight, at: r.y, font: font(7.5, .semibold), color: gray,
                   kern: 0.6, align: .right)
        }
        r.y += 14
        r.draw(client.name.uppercased(), x: contentLeft, at: r.y,
               font: font(21, .black), kern: 0.5)
        r.y += 30

        var meta = "WEEK \(week.num) OF \(program.weeks.count)   ·   \(week.phase.label.uppercased())"
        if program.startPhase == .full || program.startPhase == .real {
            let out = program.weeks.count - week.num
            if out > 0 { meta += "   ·   \(out) WK\(out == 1 ? "" : "S") OUT" }
        }
        r.draw(meta, x: contentLeft, at: r.y, font: font(9.5, .bold), kern: 0.8)
        r.y += 18
        r.hairline(atY: r.y, color: NSColor(white: 0.3, alpha: 1))
        r.y += 4
    }

    private static func columnLegend(_ r: Renderer) {
        r.y += 8
        let f = font(6.8, .bold)
        r.draw("EXERCISE", x: Cols.exercise, at: r.y, font: f, color: gray, kern: 1.2)
        r.draw("SETS × REPS", x: Cols.setsRepsCenter, at: r.y, font: f, color: gray, kern: 1.2, align: .center)
        r.draw("%1RM", x: Cols.pctCenter, at: r.y, font: f, color: gray, kern: 1.2, align: .center)
        r.draw("LOAD", x: Cols.loadRight, at: r.y, font: f, color: gray, kern: 1.2, align: .right)
        r.draw("RPE", x: Cols.rpeCenter, at: r.y, font: f, color: gray, kern: 1.2, align: .center)
        r.y += 14
    }

    private static func dayBlock(_ r: Renderer, day: DayPlan, client: Client,
                                 library: ExerciseLibrary) {
        let rowH: CGFloat = 19
        let noteH: CGFloat = 12
        var needed: CGFloat = 24 + 8
        needed += day.slots.isEmpty ? rowH : CGFloat(day.slots.count) * rowH
        needed = min(needed, 120)   // keep header + a few rows together at least
        r.ensure(needed)

        // Day bar
        r.fill(CGRect(x: contentLeft, y: r.y, width: contentWidth, height: 20), barFill)
        r.draw(day.title.uppercased(), x: contentLeft + 10, at: r.y + 4.5,
               font: font(9, .heavy), color: .white, kern: 1.1)
        r.y += 26

        if day.slots.isEmpty {
            r.draw("Rest. Sleep 8+, eat, hydrate.", x: Cols.exercise, at: r.y,
                   font: font(9.5, .regular), color: gray)
            r.y += rowH
            r.y += 6
            return
        }

        for (i, slot) in day.slots.enumerated() {
            r.ensure(rowH + (slot.note != nil ? noteH : 0) + 4)
            let name = Engine.slotName(slot, library: library)
            var displayName = name
            if slot.filmThis == true { displayName += "  ◉ FILM" }
            r.draw(displayName, x: Cols.exercise, at: r.y, font: font(10, .semibold))
            r.draw("\(slot.sets) × \(slot.reps)", x: Cols.setsRepsCenter, at: r.y,
                   font: mono(9.5), align: .center)

            let load = Engine.slotLoad(slot, maxes: client.maxes, unit: client.unit,
                                       library: library, settings: client.settings)
            if let pct = slot.pct {
                let rawOff = load != nil ? (client.settings.lift(slot.pool).intensityOffset ?? 0) : 0
                let eff = pct + min(15, max(-15, rawOff))
                let pctStr = eff == eff.rounded() ? "\(Int(eff))%" : String(format: "%.1f%%", eff)
                r.draw(pctStr, x: Cols.pctCenter, at: r.y, font: mono(9.5), align: .center)
            } else {
                r.draw("—", x: Cols.pctCenter, at: r.y, font: mono(9.5), color: faint, align: .center)
            }

            if let load {
                r.draw(Engine.loadString(load, unit: client.unit), x: Cols.loadRight,
                       at: r.y, font: mono(9.5, .bold), align: .right)
            } else {
                r.draw("—", x: Cols.loadRight, at: r.y, font: mono(9.5), color: faint, align: .right)
            }

            let rpeStr = slot.rpe == slot.rpe.rounded() ? String(Int(slot.rpe)) : String(slot.rpe)
            r.draw(rpeStr, x: Cols.rpeCenter, at: r.y, font: mono(9.5), align: .center)
            r.y += rowH - 5

            if let note = slot.note, !note.isEmpty {
                r.draw(note, x: Cols.exercise + 8, at: r.y, font: font(8, .regular), color: gray)
                r.y += noteH
            }
            if i < day.slots.count - 1 {
                r.hairline(atY: r.y + 1)
            }
            r.y += 5
        }
        r.y += 8
    }

    private static func notesBlock(_ r: Renderer, note: String) {
        r.ensure(50)
        r.y += 4
        r.fill(CGRect(x: contentLeft, y: r.y, width: 3, height: 30), NSColor(white: 0.2, alpha: 1))
        r.draw("COACH NOTES", x: contentLeft + 12, at: r.y, font: font(7.5, .bold),
               color: gray, kern: 1.4)
        r.y += 13
        let used = r.drawWrapped(note, x: contentLeft + 12, width: contentWidth - 12,
                                 at: r.y, font: font(9.5, .regular))
        r.y += used + 10
    }

    private static func attemptsBlock(_ r: Renderer, client: Client) {
        r.ensure(110)
        r.y += 6
        r.fill(CGRect(x: contentLeft, y: r.y, width: contentWidth, height: 20), barFill)
        r.draw("MEET DAY — ATTEMPT SELECTION", x: contentLeft + 10, at: r.y + 4.5,
               font: font(9, .heavy), color: .white, kern: 1.1)
        r.y += 28

        let profile = client.settings.attempts ?? AttemptProfile()
        let eff = profile.effective
        func p(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))%" : String(format: "%.1f%%", v) }
        let lifts: [(String, Double)] = [("SQUAT", client.maxes.squat),
                                         ("BENCH", client.maxes.bench),
                                         ("DEADLIFT", client.maxes.deadlift)]
        // Column header row
        let colX: [CGFloat] = [220, 320, 420, 506]
        let f = font(6.8, .bold)
        for (label, x) in zip(["OPENER ~\(p(eff.opener))", "SECOND ~\(p(eff.second))", "THIRD ~\(p(eff.third))"], colX) {
            r.draw(label, x: x, at: r.y, font: f, color: gray, kern: 1.0, align: .right)
        }
        r.y += 13
        for (i, (name, max)) in lifts.enumerated() {
            let a = Engine.attempts(max: max, unit: client.unit, profile: profile)
            r.draw(name, x: Cols.exercise, at: r.y, font: font(9.5, .heavy), kern: 0.6)
            for (v, x) in zip([a.opener, a.second, a.third], colX) {
                r.draw(Engine.loadString(v, unit: client.unit), x: x, at: r.y,
                       font: mono(9.5, v == a.third ? .bold : .regular), align: .right)
            }
            r.y += 17
            if i < lifts.count - 1 { r.hairline(atY: r.y - 3) }   // below the row, never through it
        }
        r.y += 2
        r.drawWrapped("Opener = a weight you could triple on your worst day. The third gets adjusted on the platform based on how the second moves.",
                      x: contentLeft, width: contentWidth, at: r.y,
                      font: font(8, .regular), color: gray)
        r.y += 24
    }

    private static func footer(_ r: Renderer) {
        r.ensure(34)
        r.y += 6
        r.hairline(atY: r.y)
        r.y += 7
        r.drawWrapped("RPE guide: 7 = 3 reps left · 8 = 2 left · 9 = 1 left. Trust the percentages — if a weight feels a full point harder than listed, drop the load and tell your coach.",
                      x: contentLeft, width: contentWidth, at: r.y,
                      font: font(7.5, .regular), color: gray)
    }
}
