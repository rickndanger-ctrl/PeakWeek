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
            TextField("Client name", text: $client.name)
                .font(.system(size: 26, weight: .black))
                .textFieldStyle(.plain)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    labeled("Units") {
                        Picker("", selection: $client.unit) {
                            ForEach(Unit.allCases) { u in Text(u.rawValue).tag(u) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 110)
                    }
                    labeled("Squat 1RM") { maxField($client.maxes.squat) }
                    labeled("Bench 1RM") { maxField($client.maxes.bench) }
                    labeled("Deadlift 1RM") { maxField($client.maxes.deadlift) }
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
                .buttonStyle(.borderedProminent)
                .tint(Theme.plateRed)

                Text("5-day adds a second squat day to volume + strength blocks. Peaking and deload stay at 4 days — the taper works by cutting workload.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Maxes update loads everywhere instantly — bump a 1RM after a PR and every remaining week recalculates.")
                .font(.caption).foregroundStyle(.secondary)

            Divider().overlay(Theme.line)
            deliveryPanel
        }
        .padding(20)
        .background(Theme.iron2, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: delivery preferences

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday",
                                       "Thursday", "Friday", "Saturday"]

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { client.startDate ?? DeliverySchedule.mondayOfWeek(containing: Date().addingTimeInterval(7 * 86400)) },
            set: { client.startDate = DeliverySchedule.mondayOfWeek(containing: $0) }
        )
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
        TextField("", value: value, format: .number)
            .textFieldStyle(.roundedBorder)
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
                                             library: store.data.exerciseLibrary)
        if client.startDate == nil {
            // Default anchor: next Monday.
            client.startDate = DeliverySchedule.mondayOfWeek(
                containing: Date().addingTimeInterval(7 * 86400))
        }
        if let first = client.program?.weeks.first { expandedWeeks = [first.id] }
    }

    // MARK: barbell timeline (signature)

    private func timeline(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(client.name.uppercased())'S \(program.weeks.count) WEEKS, LOADED ON THE BAR")
                .font(.caption2).kerning(2).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
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
                        .background(Theme.phaseColor(block.phase), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(block.phase == .meet ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(Double(block.weeks))
                    .frame(minWidth: CGFloat(block.weeks) * 40)
                }
                RoundedRectangle(cornerRadius: 3)
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
