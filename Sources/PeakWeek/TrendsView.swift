import SwiftUI
import Charts

// MARK: - Trends panel (per-client e1RM history + stall signals)

struct TrendsPanel: View {
    @EnvironmentObject var store: AppStore
    @Binding var client: Client

    @State private var lift: LiftPool = .squat
    @State private var showManualLog = false
    @State private var showAllEntries = false
    @State private var confirmMaxEntry: LiftLogEntry?

    private var trend: Trends.LiftTrend {
        Trends.compute(lift: lift, logs: client.logs,
                       program: client.program, startDate: client.startDate)
    }

    private var liftEntries: [LiftLogEntry] {
        client.logs.filter { $0.lift == lift }.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if trend.points.count >= 2 {
                chart(trend)
            } else if trend.points.count == 1 {
                Text("One point logged — the trend starts with the second.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Log the top set the lifter reports each week (the ✎ button on any main lift, or Log result here). The trend reads block-over-block — that's where the truth lives.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            verdictLines
            if trend.checkIn { checkInBox }
            if !liftEntries.isEmpty { entriesList }
        }
        .padding(14)
        .background(Theme.iron2, in: Rectangle())
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        .confirmationDialog(setMaxTitle,
                            isPresented: Binding(get: { confirmMaxEntry != nil },
                                                 set: { if !$0 { confirmMaxEntry = nil } }),
                            titleVisibility: .visible) {
            Button("Set as reference max") {
                if let e = confirmMaxEntry { promoteToMax(e) }
                confirmMaxEntry = nil
            }
            Button("Cancel", role: .cancel) { confirmMaxEntry = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("TRENDS & LOG").font(.caption2).kerning(1.5).foregroundStyle(.secondary)
            Picker("", selection: $lift) {
                Text("SQ").tag(LiftPool.squat)
                Text("BP").tag(LiftPool.bench)
                Text("DL").tag(LiftPool.deadlift)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 140)
            Spacer()
            Button {
                showManualLog = true
            } label: {
                Label("Log result", systemImage: "square.and.pencil").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Log any top set or a clean single — a gym max, a set from another program, anything the bar said")
            .popover(isPresented: $showManualLog) {
                LogResultPopover(lift: lift, unit: client.unit,
                                 prefill: .manual(date: Date())) { entry in
                    client.logs.append(entry)
                }
            }
        }
    }

    @ViewBuilder
    private func chart(_ t: Trends.LiftTrend) -> some View {
        let maxLine = client.maxes.value(for: lift)
        let ys = t.points.map(\.e1RM) + (maxLine > 0 ? [maxLine] : [])
        let lo = (ys.min() ?? 0) * 0.97, hi = (ys.max() ?? 100) * 1.03
        Chart {
            ForEach(t.points) { p in
                LineMark(x: .value("Date", p.date), y: .value("e1RM", p.e1RM))
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", p.date), y: .value("e1RM", p.e1RM))
                    .symbol(p.cleanSingle ? .diamond : .circle)
                    .foregroundStyle(p.cleanSingle ? Theme.plateGreen : Color.accentColor)
                    .opacity(p.isVariation ? 0.45 : 1)
            }
            if maxLine > 0 {
                RuleMark(y: .value("Max", maxLine))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("max \(Engine.loadString(maxLine, unit: client.unit))")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: lo...hi)
        .frame(height: 150)
        Text("◆ clean single · ● estimated from a top set · faded = through a variation's modifier (charted only — verdicts trust comp-lift sets)")
            .font(.system(size: 9)).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var verdictLines: some View {
        let t = trend
        switch t.verdict {
        case .insufficient:
            if t.points.count >= 2 {
                Text("Trend reads block-over-block — need \(Trends.minPointsPerBlock)+ logged sets in back-to-back blocks before it's judged.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .up(let pct):
            signalLine(icon: "arrow.up.right", color: Theme.plateGreen,
                       text: "e1RM up \(pctString(pct)) block-over-block\(bestsString(t)). Building.")
        case .flat(let pct):
            signalLine(icon: "arrow.right", color: .secondary,
                       text: "e1RM \(pctString(pct)) block-over-block\(bestsString(t)) — holding. Normal mid-prep; the taper is where it shows.")
        case .down(let pct):
            signalLine(icon: "arrow.down.right", color: .orange,
                       text: "e1RM \(pctString(pct)) block-over-block\(bestsString(t)).")
        }
        if let d = t.rpeDrift, d >= Trends.driftThreshold {
            signalLine(icon: "flame", color: .orange,
                       text: String(format: "Reported RPE arriving +%.1f hotter than written over the last sets — cross-check sleep, stress and bodyweight before touching the program.", d))
        }
    }

    private func signalLine(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(text).font(.caption)
        }
    }

    private var checkInBox: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(.orange)
            Text("Check-in time — the bar says something's off. It may not be the programming: could be fatigue, sleep, life stress, motivation, or an injury they haven't mentioned. Talk first; adjust together after.")
                .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: Rectangle())
        .overlay(Rectangle().stroke(Color.orange.opacity(0.5), lineWidth: 1))
    }

    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            let shown = showAllEntries ? liftEntries : Array(liftEntries.prefix(5))
            ForEach(shown) { e in entryRow(e) }
            if liftEntries.count > 5 {
                Button(showAllEntries ? "Show fewer" : "Show all \(liftEntries.count)") {
                    showAllEntries.toggle()
                }
                .buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private func entryRow(_ e: LiftLogEntry) -> some View {
        HStack(spacing: 8) {
            Text(e.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(.caption, design: .monospaced))
                .frame(width: 46, alignment: .leading)
                .foregroundStyle(.secondary)
            if e.cleanSingle {
                Image(systemName: "diamond.fill").font(.system(size: 8))
                    .foregroundStyle(Theme.plateGreen)
                    .help("Clean single — reference-max standard")
            }
            if e.source == .client {
                Image(systemName: "iphone").font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("Logged by the lifter from the client app")
            }
            if let flags = e.flags, !flags.isEmpty {
                Image(systemName: "flag.fill").font(.system(size: 8))
                    .foregroundStyle(.orange)
                    .help(flags.joined(separator: " · "))
            }
            Text(entryLabel(e)).font(.caption)
            if let v = e.compE1RM {
                Text("e1RM \(Engine.loadString(Engine.roundLoad(v, unit: client.unit), unit: client.unit))\(e.isVariation ? " est." : "")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if !e.note.isEmpty {
                Text(e.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if e.cleanSingle && !e.isVariation {
                Button("Set as max") { confirmMaxEntry = e }
                    .buttonStyle(.borderless).font(.caption)
                    .help("Make this single the reference max — loads and attempts recalc everywhere")
            }
            Button {
                client.logs.removeAll { $0.id == e.id }
            } label: {
                Image(systemName: "xmark").font(.caption2)
            }
            .buttonStyle(.borderless).foregroundStyle(.secondary)
            .help("Delete this entry")
        }
    }

    private func entryLabel(_ e: LiftLogEntry) -> String {
        let name = e.exerciseName ?? e.lift.groupLabel.capitalized
        let loadStr = Engine.loadString(e.load, unit: client.unit)
        var s = "\(name) \(loadStr)×\(e.reps)"
        if let r = e.rpe {
            s += r == r.rounded() ? " @\(Int(r))" : String(format: " @%.1f", r)
        }
        return s
    }

    private var setMaxTitle: String {
        guard let e = confirmMaxEntry else { return "" }
        return "Set \(e.lift.groupLabel.capitalized) max to \(Engine.loadString(e.load, unit: client.unit)) \(client.unit.rawValue)? Loads and attempts recalc everywhere."
    }

    private func promoteToMax(_ e: LiftLogEntry) {
        let v = (e.load * 10).rounded() / 10
        switch e.lift {
        case .squat: client.maxes.squat = v
        case .bench: client.maxes.bench = v
        case .deadlift: client.maxes.deadlift = v
        default: break
        }
    }

    private func pctString(_ p: Double) -> String {
        String(format: "%@%.1f%%", p >= 0 ? "+" : "", p)
    }

    private func bestsString(_ t: Trends.LiftTrend) -> String {
        guard t.blockBests.count >= 2 else { return "" }
        let prev = t.blockBests[t.blockBests.count - 2]
        let cur = t.blockBests[t.blockBests.count - 1]
        let u = client.unit
        return " (best \(Engine.loadString(Engine.roundLoad(prev.best, unit: u), unit: u)) → \(Engine.loadString(Engine.roundLoad(cur.best, unit: u), unit: u)))"
    }
}

// MARK: - Log-result popover (slot-prefilled or manual)

struct LogResultPopover: View {
    @Environment(\.dismiss) private var dismiss

    /// Where the numbers start from — a program slot (prefilled with what was
    /// prescribed) or a blank manual entry.
    struct Prefill {
        var load: Double? = nil
        var reps: Int = 1
        var rpe: Double? = nil
        var date: Date
        var exerciseName: String? = nil
        var loadMod: Double? = nil
        var prescribedPct: Double? = nil
        var prescribedRPE: Double? = nil
        var weekNum: Int? = nil
        var programStamp: Date? = nil

        static func manual(date: Date) -> Prefill { Prefill(date: date) }
    }

    let lift: LiftPool
    let unit: Unit
    let prefill: Prefill
    var onSave: (LiftLogEntry) -> Void

    @State private var load: Double = 0
    @State private var reps: Int = 1
    @State private var rpe: Double? = nil
    @State private var date: Date = Date()
    @State private var cleanSingle = false
    @State private var note = ""
    @State private var loaded = false
    @State private var manualVariation = false
    @State private var variationName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log — \(prefill.exerciseName ?? lift.groupLabel.capitalized)")
                .font(.headline)
            Text("What the bar actually said:")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("load", value: $load, format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                    .font(.system(.body, design: .monospaced))
                Text(unit.rawValue).foregroundStyle(.secondary)
                Text("×").foregroundStyle(.secondary)
                Stepper(value: $reps, in: 1...12) { Text("\(reps)").monospacedDigit() }
                    .fixedSize()
                Text("@ RPE").foregroundStyle(.secondary)
                OptionalNumberField(placeholder: "—", value: $rpe, width: 44)
            }
            HStack(spacing: 12) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact)
                Toggle("Clean single", isOn: $cleanSingle)
                    .toggleStyle(.checkbox).font(.caption)
                    .disabled(reps != 1)
                    .help("A crisp, well-executed 1RM single — the reference-max standard")
                if prefill.exerciseName == nil {
                    Toggle("Variation", isOn: $manualVariation)
                        .toggleStyle(.checkbox).font(.caption)
                        .help("Not the comp lift (e.g. pause squat, Spoto). Logged for the record, but without a known load modifier it can't honestly feed the comp-lift trend.")
                }
            }
            if manualVariation && prefill.exerciseName == nil {
                TextField("variation name (e.g. Pause Squat)", text: $variationName)
                    .textFieldStyle(.roundedBorder).font(.caption)
            }
            TextField("note (optional — \"moved fast\", \"grinder\", …)", text: $note)
                .textFieldStyle(.roundedBorder).font(.caption)
            if let e = estimate {
                Text("→ comp e1RM ≈ \(Engine.loadString(Engine.roundLoad(e, unit: unit), unit: unit))\(isVariation ? " (est. via variation)" : "")")
                    .font(.system(.caption, design: .monospaced)).bold()
            } else if load > 0 && manualVariation {
                Text("Logged for the record — variations without a known modifier don't feed the comp-lift trend.")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            } else if load > 0 && reps > 1 {
                Text("Logged either way — multi-rep sets need an RPE of 6.5+ (the table floor) to feed the trend.")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Log it") {
                    onSave(buildEntry())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(load <= 0)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            load = prefill.load ?? 0
            reps = prefill.reps
            rpe = prefill.rpe
            date = prefill.date
        }
    }

    private var isVariation: Bool {
        guard let m = prefill.loadMod else { return false }
        return abs(m - 1) > 0.0001
    }

    private var estimate: Double? { buildEntry().compE1RM }

    private func buildEntry() -> LiftLogEntry {
        let isManualVariation = manualVariation && prefill.exerciseName == nil
        let name = isManualVariation
            ? (variationName.trimmingCharacters(in: .whitespaces).isEmpty
               ? "Variation" : variationName.trimmingCharacters(in: .whitespaces))
            : prefill.exerciseName
        // Store the RPE as reported (sane range only) — compE1RM handles
        // values below the table floor honestly. loadMod 0 marks a variation
        // whose modifier is unknown: logged, never normalized.
        return LiftLogEntry(date: date, lift: lift,
                     exerciseName: name,
                     loadMod: isManualVariation ? 0 : prefill.loadMod,
                     load: load, reps: reps,
                     rpe: rpe.map { min(10, max(1, $0)) },
                     cleanSingle: cleanSingle && reps == 1,
                     prescribedPct: prefill.prescribedPct,
                     prescribedRPE: prefill.prescribedRPE,
                     weekNum: prefill.weekNum,
                     programStamp: prefill.programStamp,
                     note: note.trimmingCharacters(in: .whitespaces))
    }
}
