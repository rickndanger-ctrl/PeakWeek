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
                        peakProjectionPanel(program)
                        programSections(program)
                        Button(showRPE ? "Hide RPE → % chart" : "Show RPE → % chart") { showRPE.toggle() }
                            .buttonStyle(.bordered)
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
                    labeled("Squat max (1RM)") { maxField($client.maxes.squat, lift: .squat) }
                    labeled("Bench max (1RM)") { maxField($client.maxes.bench, lift: .bench) }
                    labeled("Deadlift max (1RM)") { maxField($client.maxes.deadlift, lift: .deadlift) }
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
                        .disabled(client.setupPhase == .full && client.blockPlan != nil)
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

            if client.setupPhase == .full {
                phaseLengthsPanel
            }

            if client.meetDate != nil {
                meetPlanRow
            }

            HStack(spacing: 14) {
                Button {
                    if client.program != nil { confirmRegen = true } else { generate() }
                } label: {
                    let n = (client.setupPhase == .full ? client.blockPlan?.total : nil) ?? clampedWeeks
                    Text(client.program == nil
                         ? "Generate \(n)-week program"
                         : "Regenerate \(n)-week program")
                        .fontWeight(.bold)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
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
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                        .help("This client has customized settings")
                }
                if excludedInProgram {
                    Text("excluded exercises still in program — regenerate to apply")
                        .font(.caption2).foregroundStyle(.orange)
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
                        // Engine clamps at use: TM 50–110, offset ±15.
                        optionalNumField(liftBinding(pool).trainingMaxPct, placeholder: "100")
                        optionalNumField(liftBinding(pool).intensityOffset, placeholder: "0")
                    }
                }
            }
            Text("Training max scales every load for that lift. Offset shifts each prescribed % (e.g. −2.5 for a deadlift that runs hot). Loads update instantly.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func optionalNumField(_ value: Binding<Double?>, placeholder: String) -> some View {
        // Decimals and minus signs type normally; the engine clamps at use.
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
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: delivery preferences

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday",
                                       "Thursday", "Friday", "Saturday"]

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { client.startDate ?? Calendar.current.startOfDay(for: Date()) },
            set: { client.startDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var deliveryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("WEEKLY PLAN DELIVERY")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                if client.delivery.autoSend && client.delivery.recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("⚠ add a recipient or nothing will send")
                        .font(.caption2).foregroundStyle(.orange)
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
                            .textFieldStyle(.roundedBorder)
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
                    labeled("Day one (week anchor)") {
                        DatePicker("", selection: startDateBinding, displayedComponents: .date)
                            .labelsHidden().frame(width: 130)
                            .help("The first training day of week 1 — any date, today included. The lifter's weeks run 7 days from this weekday.")
                    }
                }
                if let program = client.program {
                    GridRow {
                        labeled("Start auto-sends at") {
                            Picker("", selection: Binding(
                                get: { client.delivery.firstSendWeek ?? 1 },
                                set: { client.delivery.firstSendWeek = $0 <= 1 ? nil : $0 }
                            )) {
                                ForEach(program.weeks, id: \.num) { wk in
                                    Text(firstSendLabel(wk, program: program)).tag(wk.num)
                                }
                            }
                            .labelsHidden().frame(width: 200)
                        }
                        .gridCellColumns(2)
                        labeled("Mid-prep clients") {
                            Text("Set day one to when their prep actually began (past dates fine), then pick the week sends should begin — earlier weeks are never sent.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .gridCellColumns(2)
                    }
                }
            }
            deliveryStatusLine
            Text(client.delivery.requireReview
                 ? "Due weeks queue up for your approval — check the paper-plane icon in the toolbar."
                 : "Due weeks send without asking. The send log keeps a record of every delivery.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: meet-date planning

    @State private var meetPlanSummary: String?
    /// STAGED preview — nothing touches the live client (its delivery anchor,
    /// phase, or plan) until the coach presses Generate. Dismissing the
    /// regenerate confirmation abandons the staged plan harmlessly.
    @State private var pendingMeetPlan: Engine.MeetPlan?
    @State private var pendingDayOne: Date?

    /// One click: count the runway to the meet and PREVIEW the right prep
    /// slice — peaking-only at 3-4 wks, strength+peak at 5-9, full at 10-16,
    /// extended volume beyond. Nothing applies until Generate.
    private var meetPlanRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    planFromMeetDate()
                } label: {
                    Label("Plan from meet date", systemImage: "wand.and.stars")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Counts the training weeks to the meet and previews the right prep slice — day one is aligned so the meet lands at the end of the final week when possible (today at the earliest). Nothing changes until you press Generate.")
                if let summary = meetPlanSummary {
                    Text(summary).font(.caption).fontWeight(.medium)
                }
                if pendingMeetPlan != nil {
                    Button("Discard") {
                        pendingMeetPlan = nil; pendingDayOne = nil; meetPlanSummary = nil
                    }
                    .buttonStyle(.borderless).font(.caption)
                }
            }
        }
    }

    private func planFromMeetDate() {
        guard let meet = Calendar.current.startOfDay(for: client.meetDate ?? Date()) as Date?,
              client.meetDate != nil else { return }
        let today = Calendar.current.startOfDay(for: Date())
        // First pass: how many weeks fit starting today?
        let available = Engine.weeksAvailable(startMonday: today, meetDate: meet)
        guard let plan = Engine.meetPlan(availableWeeks: available) else {
            pendingMeetPlan = nil; pendingDayOne = nil
            meetPlanSummary = "Only \(available) wk\(available == 1 ? "" : "s") to the meet — too close to program. Coach meet week by hand (Peaking block needs 3+)."
            return
        }
        // Meet alignment (Strategy A): pick day one so the meet lands on the
        // LAST day of the final week — never earlier than today.
        let aligned = Calendar.current.date(byAdding: .day, value: -(plan.weeks * 7 - 1), to: meet) ?? today
        let dayOne = max(aligned, today)
        pendingMeetPlan = plan
        pendingDayOne = dayOne
        let isToday = dayOne == today
        let alignedNote = dayOne == aligned ? " (meet = final day of week \(plan.weeks))" : ""
        meetPlanSummary = plan.summary + " · day one \(isToday ? "TODAY, " : "")\(dayOne.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))\(alignedNote) — press Generate to apply."
    }

    private func firstSendLabel(_ wk: Week, program: Program) -> String {
        var label = "Week \(wk.num) — \(wk.phase.label)"
        if let start = client.startDate {
            let d = DeliverySchedule.weekStart(startDate: start, weekNum: wk.num)
            label += " (\(d.formatted(.dateTime.month(.abbreviated).day())))"
        }
        return label
    }

    /// Live confidence line: which program week today falls in, and exactly
    /// what the next automatic send will be.
    @ViewBuilder
    private var deliveryStatusLine: some View {
        if let program = client.program, let start = client.startDate, client.delivery.autoSend {
            let records = store.data.sendLog.filter { $0.clientID == client.id }
            let current = DeliverySchedule.currentWeek(now: Date(), startDate: start, program: program)
            let next = DeliverySchedule.nextPlannedSend(now: Date(), startDate: start,
                                                       program: program, prefs: client.delivery,
                                                       records: records)
            let dueNow = DeliverySchedule.dueSend(now: Date(), startDate: start, program: program,
                                                  prefs: client.delivery, records: records)
            let queuedCount = records.filter {
                if case .queued = $0.status { return $0.programStamp == program.createdAt }
                return false
            }.count
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock").foregroundStyle(.secondary)
                Text({
                    var s = current.map { "Today is Week \($0) of \(program.weeks.count)." }
                        ?? "Today is outside this program's calendar."
                    if queuedCount > 0 {
                        s += "  \(queuedCount) send\(queuedCount == 1 ? "" : "s") waiting for your review (paper-plane icon)."
                    }
                    if let dueNow, dueNow.alreadyQueued == false {
                        s += "  Week \(dueNow.weekNum) is due — it goes out on the next check (within the hour)."
                    } else if let next {
                        s += "  Next auto-send: Week \(next.week) · \(next.moment.formatted(date: .abbreviated, time: .shortened))"
                        s += client.delivery.requireReview ? " (queues for your review)." : " (sends automatically)."
                    } else if queuedCount == 0 {
                        s += "  No further auto-sends scheduled."
                    }
                    return s
                }())
                .font(.caption).fontWeight(.medium)
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let ampm = h < 12 ? "AM" : "PM"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display) \(ampm)"
    }

    // MARK: custom phase lengths

    private var planBinding: Binding<BlockPlan> {
        Binding(
            get: { client.blockPlan ?? BlockPlan() },
            set: { client.blockPlan = $0 }
        )
    }

    private var phaseLengthsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { client.blockPlan != nil },
                set: { on in
                    if on {
                        // Start from what the automatic split would produce.
                        let auto = Engine.allocateBlocks(clampedWeeks)
                        var plan = BlockPlan()
                        plan.acc = auto.first { $0.phase == .acc }?.weeks ?? 4
                        plan.deloadAfterAcc = auto.contains { $0.phase == .deload }
                        plan.trans = auto.first { $0.phase == .trans }?.weeks ?? 4
                        plan.real = auto.first { $0.phase == .real }?.weeks ?? 3
                        client.blockPlan = plan
                    } else {
                        client.blockPlan = nil
                    }
                }
            )) {
                Text("CUSTOM PHASE LENGTHS")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)

            if client.blockPlan != nil {
                HStack(spacing: 18) {
                    Stepper(value: planBinding.acc, in: 0...10) {
                        Text(planBinding.acc.wrappedValue == 0
                             ? "Volume — skipped"
                             : "Volume \(planBinding.acc.wrappedValue) wk").monospacedDigit()
                    }
                    Toggle("Deload after volume", isOn: planBinding.deloadAfterAcc)
                    Stepper(value: planBinding.trans, in: 1...10) {
                        Text("Strength \(planBinding.trans.wrappedValue) wk").monospacedDigit()
                    }
                    Stepper(value: planBinding.real, in: 2...5) {
                        Text("Peaking \(planBinding.real.wrappedValue) wk").monospacedDigit()
                    }
                    Text("= \(planBinding.wrappedValue.total) weeks total")
                        .font(.caption).fontWeight(.bold).monospacedDigit()
                }
                .font(.caption)
                // Manual scheme selection — never applied automatically.
                HStack(spacing: 18) {
                    if planBinding.acc.wrappedValue > 0 {
                        Picker("Volume scheme", selection: planBinding.accScheme) {
                            Text("Linear (classic)").tag(PhaseScheme.linear)
                            Text("Linear — RPE-anchored").tag(PhaseScheme.rpeAnchored)
                            Text("Undulating (DUP)").tag(PhaseScheme.dup)
                        }
                        .fixedSize()
                        .help("RPE-anchored: comp-lift volume work starts where a trained lifter actually works — 6s at 72→80% (8s at 69→75%), RPE ~6.5 entering, ~8.5 leaving — instead of the classic soft ramp-in (6 @ 67% ≈ RPE 4). Adjust the band to match the program the lifter is coming from. Variations stay factory.\n\nUndulating: each lift sees a volume day, a speed day, and a strength day across the week — evidence on par with linear, with a freshness edge for trained lifters.")
                        if planBinding.accScheme.wrappedValue == .rpeAnchored {
                            HStack(spacing: 4) {
                                Text("Band").font(.caption2).foregroundStyle(.secondary)
                                OptionalNumberField(placeholder: "72", value: planBinding.accBandLo, width: 44)
                                Text("→").foregroundStyle(.secondary)
                                OptionalNumberField(placeholder: "80", value: planBinding.accBandHi, width: 44)
                                Text("%").font(.caption2).foregroundStyle(.secondary)
                            }
                            .help("Entry → top %% for the sixes (bench eights derive automatically). Match the entry to where the lifter is coming from: fresh off hypertrophy ≈ 68, hardened meet-prep lifter ≈ 74. Blank = 72→80.")
                        }
                    }
                    Picker("Strength scheme", selection: planBinding.transScheme) {
                        Text("Linear (classic)").tag(PhaseScheme.linear)
                        Text("Wave (3-week)").tag(PhaseScheme.wave)
                    }
                    .fixedSize()
                    .help("Wave: reps fall and weight rises for three weeks, then the bar drops back and the next wave starts heavier. Same final-week weights as linear (86/85/87), different route — the drop-backs shed fatigue. Best for lifters whose week 5–6 always collapses.")
                    Text("Regenerate to apply scheme changes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .font(.caption)
                Text("Peaking includes meet week. After generating you can add one recovery week between strength and peaking — the button under the timeline (deload rows carry a − control to undo).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @State private var e1rmPool: LiftPool?

    private func maxField(_ value: Binding<Double>, lift: LiftPool) -> some View {
        // Show at most 1 decimal; stored value keeps full precision so unit
        // conversions round-trip exactly.
        HStack(spacing: 2) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 90)
                .help("Programming max — the coach's standard: the most recent CLEAN single, competition or gym. Between tests, the ƒx button estimates e1RM from a top set to keep loads honest.")
            Button {
                e1rmPool = lift
            } label: {
                Image(systemName: "function")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .help("Compute e1RM from a top set (load × reps @ RPE) and apply it")
            .popover(isPresented: Binding(
                get: { e1rmPool == lift },
                set: { if !$0 { e1rmPool = nil } }
            )) {
                E1RMPopover(lift: lift, unit: client.unit) { e1rm in
                    value.wrappedValue = e1rm
                }
            }
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).kerning(1).foregroundStyle(.secondary)
            content()
        }
    }

    private func generate() {
        // A staged meet plan applies HERE — inside the confirmed Generate path.
        if let staged = pendingMeetPlan {
            client.setupPhase = staged.phase
            client.setupWeeks = min(staged.phase.maxWeeks, max(staged.phase.minWeeks, staged.weeks))
            client.blockPlan = staged.blockPlan
            if let dayOne = pendingDayOne { client.startDate = dayOne }
            pendingMeetPlan = nil
            pendingDayOne = nil
        }
        meetPlanSummary = nil
        let plan = client.setupPhase == .full ? client.blockPlan : nil
        client.program = Engine.buildProgram(startPhase: client.setupPhase,
                                             totalWeeks: plan?.total ?? clampedWeeks,
                                             fiveDay: client.fiveDay,
                                             library: store.data.exerciseLibrary,
                                             excluded: client.settings.excludedExerciseIDs ?? [],
                                             blockPlan: plan)
        // Old-program queue entries must not survive into the new program.
        store.retireStaleQueued(clientID: client.id, currentStamp: client.program?.createdAt)
        // A new program is a fresh delivery contract: a first-send week from
        // the OLD program would silently misapply (or kill sends entirely).
        client.delivery.firstSendWeek = nil
        // Never let a rebuild fire an unconfirmed automatic send: the next due
        // send queues for one-time review even when review is off.
        if client.delivery.autoSend && !client.delivery.requireReview {
            client.delivery.forceReviewOnce = true
        }
        if client.startDate == nil {
            // Default anchor: TODAY — day one is now, the lifter's week runs
            // from whatever weekday this is. Coach can re-date it any time.
            client.startDate = Calendar.current.startOfDay(for: Date())
        }
        if let first = client.program?.weeks.first { expandedWeeks = [first.id] }
    }

    // MARK: peak projection

    @ViewBuilder
    private func peakProjectionPanel(_ program: Program) -> some View {
        if let meet = client.meetDate, let start = client.startDate,
           let projection = PeakProjection.compute(program: program, startDate: start,
                                                   meetDate: meet) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: projection.allInWindow ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(projection.allInWindow ? Theme.plateGreen : .orange)
                    Text("PEAK PROJECTION")
                        .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                    Text(projection.allInWindow
                         ? "every milestone sits inside its evidence window"
                         : "check the flagged spacing below")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    ForEach(projection.events) { e in
                        GridRow {
                            Image(systemName: e.ok ? "checkmark.circle" : "exclamationmark.circle")
                                .foregroundStyle(e.ok ? Theme.plateGreen : .orange)
                                .font(.caption)
                            Text(e.kind.rawValue).font(.caption).fontWeight(.semibold)
                            Text(e.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.system(.caption, design: .monospaced))
                            Text(e.detail).font(.caption).foregroundStyle(e.ok ? .secondary : .primary)
                        }
                    }
                }
                if let note = projection.meetPlacementNote {
                    Label(note, systemImage: "calendar.badge.exclamationmark")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text("Windows assume typical fatigue clearance (~12-day decay). Deadlift needs the longest runway, bench the shortest — the model derives the calendar, the bar decides the day.")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Theme.iron2, in: Rectangle())
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        }
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
                        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))  // near-white meet plate stays visible in light mode
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
            HStack(spacing: 12) {
                Text("Each plate is a block; width = weeks. The collar is the finish line. Click a plate to jump there.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let boundary = program.realizationBoundary,
                   program.canInsertDeload(at: boundary) {
                    Button {
                        insertDeloadBeforeRealization()
                    } label: {
                        Label("Insert deload before realization", systemImage: "plus.rectangle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Adds a recovery week between transmutation and realization. Later weeks renumber and the delivery schedule shifts a week — automatically. Never stacks two deloads in a row.")
                }
            }
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
                            : { store.sendNow(clientID: client.id, weekNum: program.weeks[wIdx].num) },
                        onRemoveDeload: program.weeks[wIdx].phase == .deload
                            ? { removeDeload(at: wIdx) } : nil
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

    // MARK: structural edits — the schedule, numbering, and delivery
    // bookkeeping all follow automatically.

    /// Coach workflow: an extra deload goes between transmutation and
    /// realization when the lifter needs one. Never two deloads in a row —
    /// the model refuses adjacent insertions.
    private func insertDeloadBeforeRealization() {
        guard var program = client.program,
              let boundary = program.realizationBoundary else { return }
        let week = Engine.makeDeloadWeek(fiveDay: program.fiveDay,
                                         library: store.data.exerciseLibrary,
                                         excluded: client.settings.excludedExerciseIDs ?? [])
        guard program.insertDeload(week: week, at: boundary) else { return }
        // Send records for weeks at/after the insertion point shift up by one —
        // and so does a configured first-send week.
        store.adjustSendRecords(clientID: client.id, programStamp: program.createdAt,
                                fromWeek: boundary + 1, by: 1)
        if let first = client.delivery.firstSendWeek, first >= boundary + 1 {
            client.delivery.firstSendWeek = first + 1
        }
        client.program = program
    }

    private func removeDeload(at index: Int) {
        guard var program = client.program,
              program.weeks.indices.contains(index),
              program.weeks[index].phase == .deload else { return }
        let removedNum = program.weeks[index].num
        program.removeWeek(at: index)
        store.adjustSendRecords(clientID: client.id, programStamp: program.createdAt,
                                fromWeek: removedNum + 1, by: -1, removedWeek: removedNum)
        if let first = client.delivery.firstSendWeek, first > removedNum {
            client.delivery.firstSendWeek = first - 1
        }
        client.program = program
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

// MARK: - e1RM calculator

/// Coach's reference-max convention: program off the LAST BLOCK'S e1RM.
/// Type the lifter's top set → the RTS table produces the estimate → Apply
/// writes it straight into the programming max (loads recalc everywhere).
struct E1RMPopover: View {
    @Environment(\.dismiss) private var dismiss
    let lift: LiftPool
    let unit: Unit
    var onApply: (Double) -> Void

    @State private var load = 0.0
    @State private var reps = 4
    @State private var rpe = 8.0

    private var estimate: Double? {
        Engine.e1RM(load: load, reps: reps, rpe: rpe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("e1RM — \(lift.groupLabel)").font(.headline)
            Text("Last block's best top set:")
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
                Stepper(value: $rpe, in: 6.5...10, step: 0.5) {
                    Text(rpe == rpe.rounded() ? String(Int(rpe)) : String(rpe)).monospacedDigit()
                }
                .fixedSize()
            }
            HStack {
                if let e = estimate {
                    Text("e1RM ≈ \(Engine.loadString(Engine.roundLoad(e, unit: unit), unit: unit))")
                        .font(.system(.body, design: .monospaced)).bold()
                } else {
                    Text("enter the set…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Apply") {
                    if let e = estimate {
                        onApply((e * 10).rounded() / 10)   // store to 0.1; loads round at prescription
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(estimate == nil)
            }
            Text("Loads and attempts recalc everywhere the moment you apply.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 380)
    }
}
