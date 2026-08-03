import SwiftUI
import AppKit

struct ClientView: View {
    @EnvironmentObject var store: AppStore
    @Binding var client: Client
    var onDelete: () -> Void

    @State private var confirmRegen = false
    @State private var confirmDelete = false
    @State private var expandedWeeks: Set<UUID> = []
    @State private var showRPE = false
    @State private var copiedWeek: Int?
    @State private var scrollTarget: Int?

    private var clampedWeeks: Int {
        min(client.setupPhase.maxWeeks, max(client.setupPhase.minWeeks, client.setupWeeks))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    setupPanel
                    if let program = client.program {
                        timeline(program)
                        programSections(program)
                        Button(showRPE ? "Hide RPE → % chart" : "Show RPE → % chart") { showRPE.toggle() }
                            .buttonStyle(SquareOutlineButtonStyle())
                    }
                }
                .padding(24)
            }
            .background(Theme.iron)
            .onChange(of: scrollTarget) { target in
                if let t = target {
                    withAnimation { proxy.scrollTo("section-\(t)", anchor: .top) }
                    scrollTarget = nil
                }
            }
        }
        .sheet(isPresented: $showRPE) { RPEChartView() }
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Client", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete \(client.name) and their program? Back up first if unsure.",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
        }
        .confirmationDialog("This replaces the current program and any weekly edits.",
                            isPresented: $confirmRegen, titleVisibility: .visible) {
            Button("Regenerate", role: .destructive) { generate() }
        }
    }

    // MARK: setup

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                TextField("Client name", text: $client.name)
                    .font(.system(size: 26, weight: .black))
                    .textFieldStyle(.plain)
                if let meet = client.meetDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: meet).day ?? 0
                    let wks = Int((Double(days) / 7.0).rounded(.up))
                    Text(days < 0 ? "MEET PASSED — \(meet.formatted(date: .abbreviated, time: .omitted))"
                         : "MEET IN \(wks) WK\(wks == 1 ? "" : "S") — \(meet.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .black)).kerning(1)
                        .foregroundStyle(days < 0 ? Theme.smoke : Theme.plateRed)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    labeled("Units") {
                        Picker("", selection: $client.unit) {
                            ForEach(Unit.allCases) { u in Text(u.rawValue).tag(u) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 110)
                        .onChange(of: client.unit) { newUnit in
                            // True, exact conversion — round-trips are lossless.
                            let old: Unit = newUnit == .kg ? .lb : .kg
                            client.maxes = client.maxes.converted(from: old, to: newUnit)
                        }
                    }
                    labeled("Squat 1RM") { maxField($client.maxes.squat) }
                    labeled("Bench 1RM") { maxField($client.maxes.bench) }
                    labeled("Deadlift 1RM") { maxField($client.maxes.deadlift) }
                    labeled("Meet date") {
                        HStack(spacing: 4) {
                            DatePicker("", selection: Binding(
                                get: { client.meetDate ?? {
                                    // Default: Saturday of the final program week.
                                    let afterEnd = DeliverySchedule.weekStart(
                                        startDate: client.startDate ?? Date(),
                                        weekNum: (client.program?.weeks.count ?? client.setupWeeks) + 1)
                                    return Calendar.current.date(byAdding: .day, value: -2, to: afterEnd) ?? afterEnd
                                }() },
                                set: { client.meetDate = $0 }
                            ), displayedComponents: .date)
                            .labelsHidden().frame(width: 130)
                            if client.meetDate != nil {
                                Button { client.meetDate = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                                .help("Clear meet date")
                            }
                        }
                    }
                }
                GridRow {
                    labeled("Training phase") {
                        Picker("", selection: $client.setupPhase) {
                            ForEach(StartPhase.allCases) { p in Text(p.label).tag(p) }
                        }
                        .labelsHidden()
                        .onChange(of: client.setupPhase) { p in client.setupWeeks = p.defaultWeeks }
                    }
                    .gridCellColumns(2)
                    labeled("Length (\(client.setupPhase.minWeeks)–\(client.setupPhase.maxWeeks) wks)") {
                        Stepper(value: $client.setupWeeks,
                                in: client.setupPhase.minWeeks...client.setupPhase.maxWeeks) {
                            Text("\(clampedWeeks) weeks").monospacedDigit()
                        }
                    }
                    labeled("Days / week") {
                        Picker("", selection: $client.fiveDay) {
                            Text("4-day").tag(false)
                            Text("5-day").tag(true)
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                    }
                }
            }

            HStack(spacing: 14) {
                Button {
                    if client.program != nil { confirmRegen = true } else { generate() }
                } label: {
                    Text(client.program == nil
                         ? "Generate \(clampedWeeks)-week program"
                         : "Regenerate \(clampedWeeks)-week program")
                        .fontWeight(.bold)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                }
                .buttonStyle(SquareButtonStyle())
                .tint(Theme.plateRed)

                Text("5-day adds a second squat day to volume + strength blocks. Peaking and deload stay at 4 days — the taper works by cutting workload.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Maxes update loads everywhere instantly — bump a 1RM after a PR and every remaining week recalculates.")
                .font(.caption).foregroundStyle(.secondary)

            Divider().overlay(Theme.line)
            deliveryPanel
            Divider().overlay(Theme.line)
            coachingOptions
        }
        .padding(20)
        .background(Theme.iron2, in: Rectangle())
    }

    // MARK: coaching options

    @State private var optionsExpanded = false

    private var excludedInProgram: Bool {
        guard let excluded = client.settings.excludedExerciseIDs, !excluded.isEmpty,
              let program = client.program else { return false }
        return program.weeks.contains { w in
            w.days.contains { d in
                d.slots.contains { $0.exerciseID.map(excluded.contains) == true }
            }
        }
    }

    private var coachingOptions: some View {
        DisclosureGroup(isExpanded: $optionsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                attemptsPanel
                perLiftPanel
                exclusionsPanel
                notesPanel
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 10) {
                Text("COACHING OPTIONS")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                if client.settings.isCustomized {
                    Circle().fill(Theme.plateYellow).frame(width: 6, height: 6)
                        .help("This client has customized settings")
                }
                if excludedInProgram {
                    Text("excluded exercises still in program — regenerate to apply")
                        .font(.caption2).foregroundStyle(Theme.plateYellow)
                }
            }
        }
    }

    private var attemptsBinding: Binding<AttemptProfile> {
        Binding(
            get: { client.settings.attempts ?? AttemptProfile() },
            set: { client.settings.attempts = $0 }
        )
    }

    private var attemptsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEET ATTEMPTS").font(.caption2).kerning(1).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Picker("", selection: attemptsBinding.risk) {
                    ForEach(AttemptProfile.Risk.allCases) { r in Text(r.label).tag(r) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 280)
                let eff = (client.settings.attempts ?? AttemptProfile()).effective
                Text("open \(pct(eff.opener)) · second \(pct(eff.second)) · third \(pct(eff.third))")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                overrideField("Opener %", attemptsBinding.opener, placeholder: "91")
                overrideField("Second %", attemptsBinding.second, placeholder: "97")
                overrideField("Third %", attemptsBinding.third, placeholder: "101.5")
                Text("Leave blank to follow the risk preset.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func pct(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))%" : String(format: "%.1f%%", v)
    }

    private func overrideField(_ label: String, _ value: Binding<Double?>, placeholder: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            // Commits on submit/blur; the engine clamps overrides 80–115 at use.
            OptionalNumberField(placeholder: placeholder, value: value, width: 52)
        }
    }

    private func liftBinding(_ pool: LiftPool) -> Binding<LiftSettings> {
        Binding(
            get: { client.settings.lift(pool) },
            set: { new in
                var map = client.settings.perLift ?? [:]
                map[pool.rawValue] = new
                client.settings.perLift = map
            }
        )
    }

    private var perLiftPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PER-LIFT PROGRAMMING").font(.caption2).kerning(1).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("").font(.caption2)
                    Text("TRAINING MAX %").font(.system(size: 9)).kerning(0.5).foregroundStyle(.secondary)
                    Text("INTENSITY OFFSET ±%").font(.system(size: 9)).kerning(0.5).foregroundStyle(.secondary)
                }
                ForEach([LiftPool.squat, .bench, .deadlift]) { pool in
                    GridRow {
                        Text(pool.groupLabel).font(.system(size: 11, weight: .bold))
                        optionalNumField(liftBinding(pool).trainingMaxPct, placeholder: "100", range: 80...105)
                        optionalNumField(liftBinding(pool).intensityOffset, placeholder: "0", range: -10...10)
                    }
                }
            }
            Text("Training max scales every load for that lift. Offset shifts each prescribed % (e.g. −2.5 for a deadlift that runs hot). Loads update instantly.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func optionalNumField(_ value: Binding<Double?>, placeholder: String,
                                  range: ClosedRange<Double>) -> some View {
        // Commits on submit/blur — decimals and minus signs type normally.
        // The engine clamps per-lift values at use.
        OptionalNumberField(placeholder: placeholder, value: value, width: 64)
    }

    private var exclusionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXCLUDED EXERCISES (INJURY / EQUIPMENT)")
                .font(.caption2).kerning(1).foregroundStyle(.secondary)
            let excluded = client.settings.excludedExerciseIDs ?? []
            HStack(spacing: 8) {
                ForEach(Array(excluded), id: \.self) { id in
                    if let ex = store.data.exerciseLibrary.exercise(id: id) {
                        HStack(spacing: 4) {
                            Text(ex.name).font(.caption)
                            Button {
                                client.settings.excludedExerciseIDs?.remove(id)
                            } label: { Image(systemName: "xmark").font(.system(size: 8)) }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.iron3)
                    }
                }
                Menu {
                    ForEach(LiftPool.allCases) { pool in
                        ForEach(store.data.exerciseLibrary[pool].filter {
                            !$0.archived && !excluded.contains($0.id)
                        }) { ex in
                            Button("\(pool.groupLabel) — \(ex.name)") {
                                var set = client.settings.excludedExerciseIDs ?? []
                                set.insert(ex.id)
                                client.settings.excludedExerciseIDs = set
                            }
                        }
                    }
                } label: {
                    Label("Exclude…", systemImage: "plus")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Text("Excluded exercises are swapped out at generation and hidden nowhere else — regenerate after changing.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLIENT NOTES (FEDERATION, EQUIPMENT, CUES)")
                .font(.caption2).kerning(1).foregroundStyle(.secondary)
            TextField("e.g. USAPL raw · low-bar, close grip · cue: spread the floor",
                      text: Binding(
                        get: { client.settings.notes ?? "" },
                        set: { client.settings.notes = $0.isEmpty ? nil : $0 }
                      ), axis: .vertical)
                .lineLimit(2...4)
                .squareFieldStyle()
        }
    }

    // MARK: delivery preferences

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday",
                                       "Thursday", "Friday", "Saturday"]

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { client.startDate ?? Self.nextMonday() },
            set: { client.startDate = DeliverySchedule.mondayOfWeek(containing: $0) }
        )
    }

    /// DST-safe "next Monday" (calendar day arithmetic, not seconds).
    static func nextMonday(from date: Date = Date()) -> Date {
        let inAWeek = Calendar.current.date(byAdding: .day, value: 7, to: date) ?? date
        return DeliverySchedule.mondayOfWeek(containing: inAWeek)
    }

    private var deliveryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("WEEKLY PLAN DELIVERY")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                if client.delivery.autoSend && client.delivery.recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("⚠ add a recipient or nothing will send")
                        .font(.caption2).foregroundStyle(Theme.plateYellow)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    labeled("Auto-send") {
                        Toggle("", isOn: $client.delivery.autoSend)
                            .toggleStyle(.switch).labelsHidden()
                    }
                    labeled("Via") {
                        Picker("", selection: $client.delivery.method) {
                            ForEach(DeliveryMethod.allCases) { m in Text(m.label).tag(m) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                    }
                    labeled(client.delivery.method == .mail ? "Email address" : "iMessage / phone") {
                        TextField(client.delivery.method == .mail ? "client@example.com" : "+1 555 010 0000",
                                  text: $client.delivery.recipient)
                            .squareFieldStyle()
                            .frame(width: 190)
                    }
                    labeled("Format") {
                        Picker("", selection: $client.delivery.format) {
                            ForEach(DeliveryFormat.allCases) { f in Text(f.label).tag(f) }
                        }
                        .labelsHidden().frame(width: 120)
                    }
                }
                GridRow {
                    labeled("Send on") {
                        Picker("", selection: $client.delivery.weekday) {
                            ForEach(1...7, id: \.self) { d in
                                Text(Self.weekdayNames[d - 1]).tag(d)
                            }
                        }
                        .labelsHidden().frame(width: 120)
                    }
                    labeled("At") {
                        Picker("", selection: $client.delivery.hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .labelsHidden().frame(width: 90)
                    }
                    labeled("Review before sending") {
                        Toggle("", isOn: $client.delivery.requireReview)
                            .toggleStyle(.switch).labelsHidden()
                    }
                    labeled("Week 1 starts (Monday)") {
                        DatePicker("", selection: startDateBinding, displayedComponents: .date)
                            .labelsHidden().frame(width: 130)
                    }
                }
            }
            Text(client.delivery.requireReview
                 ? "Due weeks queue up for your approval — check the paper-plane icon in the toolbar."
                 : "Due weeks send without asking. The send log keeps a record of every delivery.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let ampm = h < 12 ? "AM" : "PM"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display) \(ampm)"
    }

    private func maxField(_ value: Binding<Double>) -> some View {
        // Show at most 1 decimal; stored value keeps full precision so unit
        // conversions round-trip exactly.
        TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
            .squareFieldStyle()
            .font(.system(.body, design: .monospaced))
            .frame(width: 90)
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).kerning(1).foregroundStyle(.secondary)
            content()
        }
    }

    private func generate() {
        client.program = Engine.buildProgram(startPhase: client.setupPhase,
                                             totalWeeks: clampedWeeks,
                                             fiveDay: client.fiveDay,
                                             library: store.data.exerciseLibrary,
                                             excluded: client.settings.excludedExerciseIDs ?? [])
        if client.startDate == nil {
            // Default anchor: next Monday.
            client.startDate = Self.nextMonday()
        }
        if let first = client.program?.weeks.first { expandedWeeks = [first.id] }
    }

    // MARK: barbell timeline (signature)

    private func timeline(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(client.name.uppercased())'S \(program.weeks.count) WEEKS, LOADED ON THE BAR")
                .font(.caption2).kerning(2).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(white: 0.72), Color(white: 0.5)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 13)
                ForEach(Array(program.blocks.enumerated()), id: \.offset) { idx, block in
                    Button {
                        scrollTarget = idx
                    } label: {
                        VStack(spacing: 4) {
                            Text(block.phase.label.uppercased())
                                .font(.system(size: 11, weight: .black))
                            Text("\(block.weeks) wk")
                                .font(.system(size: 10, design: .monospaced)).opacity(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(Theme.phaseColor(block.phase), in: Rectangle())
                        .foregroundStyle(block.phase == .meet ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(Double(block.weeks))
                    .frame(minWidth: CGFloat(block.weeks) * 40)
                }
                Rectangle()
                    .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 32)
            }
            Text("Each plate is a block; width = weeks. The collar is the finish line. Click a plate to jump there.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: sections

    private struct Section2: Identifiable {
        let id: Int
        let phase: Phase
        let weekIndices: [Int]
    }

    private func sections(of program: Program) -> [Section2] {
        var out: [Section2] = []
        for (i, wk) in program.weeks.enumerated() {
            if let last = out.last, last.phase == wk.phase {
                out[out.count - 1] = Section2(id: last.id, phase: last.phase,
                                              weekIndices: last.weekIndices + [i])
            } else {
                out.append(Section2(id: out.count, phase: wk.phase, weekIndices: [i]))
            }
        }
        return out
    }

    @ViewBuilder
    private func programSections(_ program: Program) -> some View {
        ForEach(sections(of: program)) { sec in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Circle().fill(Theme.phaseColor(sec.phase)).frame(width: 13, height: 13)
                    Text(sec.phase.label.uppercased())
                        .font(.system(size: 24, weight: .black))
                    Text(sec.phase.sub.uppercased())
                        .font(.caption).kerning(1.5).foregroundStyle(.secondary)
                }
                Text(sec.phase.blurb)
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: 660, alignment: .leading)

                ForEach(sec.weekIndices, id: \.self) { wIdx in
                    WeekView(
                        week: weekBinding(wIdx),
                        client: client,
                        program: program,
                        isExpanded: expandedBinding(program.weeks[wIdx].id),
                        copied: copiedWeek == program.weeks[wIdx].num,
                        onCopy: { copyWeek(program.weeks[wIdx], program: program) },
                        onSendNow: client.delivery.recipient.trimmingCharacters(in: .whitespaces).isEmpty
                            ? nil
                            : { store.sendNow(clientID: client.id, weekNum: program.weeks[wIdx].num) }
                    )
                }
            }
            .id("section-\(sec.id)")
            .padding(.top, 12)
        }
    }

    private func weekBinding(_ index: Int) -> Binding<Week> {
        Binding(
            get: { client.program?.weeks.indices.contains(index) == true
                   ? client.program!.weeks[index]
                   : Week(num: 0, phase: .acc, weekInBlock: 1, blockLen: 1, days: []) },
            set: { newValue in
                if client.program?.weeks.indices.contains(index) == true {
                    client.program!.weeks[index] = newValue
                }
            }
        )
    }

    private func expandedBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedWeeks.contains(id) },
            set: { open in
                if open { expandedWeeks.insert(id) } else { expandedWeeks.remove(id) }
            }
        )
    }

    private func copyWeek(_ week: Week, program: Program) {
        let text = Engine.weekToText(client: client, program: program, week: week,
                                     library: store.data.exerciseLibrary)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copiedWeek = week.num
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedWeek == week.num { copiedWeek = nil }
        }
    }
}
