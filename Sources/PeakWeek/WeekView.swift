import SwiftUI
import CoreTransferable

// MARK: - Week delivery transferable

/// Lets the share sheet produce the PDF lazily — only rendered when the coach
/// actually picks a destination (Messages, Mail, AirDrop…).
struct WeekPDFTransfer: Transferable {
    let client: Client
    let program: Program
    let week: Week
    let library: ExerciseLibrary

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            guard let url = WeekExporter.writeTempPDF(client: item.client,
                                                     program: item.program,
                                                     week: item.week,
                                                     library: item.library) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

// MARK: - Week

struct WeekView: View {
    @EnvironmentObject var store: AppStore
    @Binding var week: Week
    let client: Client
    let program: Program
    @Binding var isExpanded: Bool
    let copied: Bool
    let onCopy: () -> Void
    var onSendNow: (() -> Void)? = nil
    @State private var confirmSendNow = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                content
            }
        }
        .background(Theme.iron2, in: Rectangle())
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: 16) {
                    Text("WK \(String(format: "%02d", week.num))")
                        .font(.system(size: 17, weight: .black))
                        .frame(minWidth: 66, alignment: .leading)
                    Text(headerMeta)
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(copied ? "Copied ✓" : "Copy week", action: onCopy)
                .buttonStyle(.borderless)
                .padding(.horizontal, 14)
                .fontWeight(.semibold)

            // NOTE: ShareLink inside Menu is verified working on macOS 14+ (this
            // machine). If a macOS 13 install ever misbehaves, hoist the two
            // ShareLinks out of the Menu into inline header buttons.
            Menu {
                ShareLink(item: weekText) {
                    Label("Send as text…", systemImage: "message")
                }
                ShareLink(item: WeekPDFTransfer(client: client, program: program, week: week,
                                                library: store.data.exerciseLibrary),
                          preview: SharePreview("\(client.name) — Week \(week.num)")) {
                    Label("Send as PDF…", systemImage: "doc.richtext")
                }
                Divider()
                Button("Save PDF…") {
                    WeekExporter.savePDF(client: client, program: program, week: week,
                                         library: store.data.exerciseLibrary)
                }
                if onSendNow != nil {
                    Divider()
                    Button("Send now to \(client.delivery.recipient) (\(client.delivery.method.label))…") {
                        confirmSendNow = true
                    }
                }
            } label: {
                Label("Send", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 14)
            .help("Send this week's plan to \(client.name)")
            .confirmationDialog(
                "Send Week \(week.num) to \(client.delivery.recipient) via \(client.delivery.method.label) right now?",
                isPresented: $confirmSendNow, titleVisibility: .visible) {
                Button("Send") { onSendNow?() }
            }
        }
    }

    private var weekText: String {
        Engine.weekToText(client: client, program: program, week: week,
                          library: store.data.exerciseLibrary)
    }

    private var headerMeta: String {
        var s: String
        switch week.phase {
        case .meet: s = "Meet week — compete"
        case .deload: s = "Recovery week"
        default: s = "Block week \(week.weekInBlock) of \(week.blockLen)"
        }
        if program.startPhase == .full || program.startPhase == .real {
            let out = program.weeks.count - week.num
            if out > 0 { s += " · \(out) wk\(out == 1 ? "" : "s") out" }
        }
        if !week.note.isEmpty { s += " · has coach notes" }
        return s
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            let cols = [GridItem(.adaptive(minimum: 320), spacing: 14, alignment: .top)]
            LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
                ForEach($week.days) { $day in
                    DayCard(day: $day, client: client)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("COACH NOTES FOR THIS WEEK (GOES INTO THE COPIED TEXT)")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                TextField("e.g. Keep the pause squats honest — full 2-count. Video your last set of comp squats.",
                          text: $week.note, axis: .vertical)
                    .lineLimit(2...4)
                    .squareFieldStyle()
            }
            if week.phase == .meet {
                MeetCard(client: client)
            }
        }
        .padding(16)
    }
}

// MARK: - Day

struct DayCard: View {
    @EnvironmentObject var store: AppStore
    @Binding var day: DayPlan
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.title.uppercased())
                .font(.system(size: 11, weight: .bold)).kerning(1)
            if day.slots.isEmpty {
                Text("No barbell work. Sleep 8+, eat, arrive fresh.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($day.slots) { $slot in
                Divider()
                SlotRow(slot: $slot, client: client) {
                    day.slots.removeAll { $0.id == slot.id }
                }
            }
            // Always available — a day emptied by removals must not dead-end.
            Button {
                let lib = store.data.exerciseLibrary
                let first = lib[.back].first { !$0.archived }
                day.slots.append(Slot(pool: .back, exerciseID: first?.id,
                                      custom: first == nil ? "" : nil,
                                      sets: 3, reps: 10, pct: nil, rpe: 8))
            } label: {
                Label("Add exercise", systemImage: "plus")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SquareOutlineButtonStyle())
            .padding(.top, 4)
        }
        .padding(12)
        .background(Theme.iron, in: Rectangle())
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Slot

struct SlotRow: View {
    @EnvironmentObject var store: AppStore
    @Binding var slot: Slot
    let client: Client
    let onRemove: () -> Void
    @State private var showNewExercise = false

    private var pctBinding: Binding<Double?> {
        Binding(
            get: { slot.pct },
            set: { slot.pct = $0.map { min(110, max(0, $0)) } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if slot.custom != nil {
                    TextField("Custom exercise", text: Binding(
                        get: { slot.custom ?? "" },
                        set: { slot.custom = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .fontWeight(.semibold)
                    Button("↩︎ list") { slot.custom = nil }
                        .buttonStyle(.borderless).font(.caption)
                } else {
                    Picker("", selection: exerciseSelection) {
                        ForEach(LiftPool.allCases) { pool in
                            ForEach(store.data.exerciseLibrary[pool].filter {
                                !$0.archived || $0.id == slot.exerciseID
                            }) { ex in
                                Text("\(pool.groupLabel) — \(ex.name)\(ex.archived ? " (archived)" : "")")
                                    .tag(ex.id.uuidString)
                            }
                        }
                        Divider()
                        Text("✎ Custom exercise…").tag("custom")
                        Text("＋ New library exercise…").tag("new")
                    }
                    .labelsHidden()
                    .fontWeight(.semibold)
                    .popover(isPresented: $showNewExercise) {
                        NewExercisePopover(defaultPool: slot.pool) { newEx, pool in
                            store.data.exerciseLibrary.add(newEx, to: pool)
                            slot.pool = pool
                            slot.exerciseID = newEx.id
                            slot.exIdx = nil
                            slot.custom = nil
                        }
                    }
                }
                Button { onRemove() } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove exercise")
            }

            HStack(spacing: 5) {
                numField($slot.sets, width: 38)
                    .onChange(of: slot.sets) { v in slot.sets = min(99, max(1, v)) }
                Text("×").foregroundStyle(.secondary)
                numField($slot.reps, width: 38)
                    .onChange(of: slot.reps) { v in slot.reps = min(99, max(1, v)) }
                Text("@").foregroundStyle(.secondary)
                OptionalNumberField(placeholder: "—", value: pctBinding, width: 44)
                Text("%").foregroundStyle(.secondary)
                if let load = Engine.slotLoad(slot, maxes: client.maxes, unit: client.unit,
                                              library: store.data.exerciseLibrary,
                                              settings: client.settings) {
                    Text("→ \(Engine.loadString(load, unit: client.unit))")
                        .font(.system(.caption, design: .monospaced)).bold()
                        .foregroundStyle(Theme.plateYellow)
                }
                Spacer(minLength: 4)
                Text("RPE").font(.caption2).foregroundStyle(.secondary)
                TextField("", value: $slot.rpe, format: .number)
                    .squareFieldStyle()
                    .font(.system(.caption, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .onChange(of: slot.rpe) { v in
                        // Clamp 5–10, snap to half points.
                        slot.rpe = min(10, max(5, (v * 2).rounded() / 2))
                    }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var exerciseSelection: Binding<String> {
        Binding(
            get: {
                store.data.exerciseLibrary.resolve(slot)?.id.uuidString ?? "custom"
            },
            set: { newValue in
                switch newValue {
                case "custom":
                    // Keep pct so switching to custom and back never loses the
                    // prescription (custom slots simply show no computed load).
                    slot.custom = ""
                case "new":
                    showNewExercise = true
                default:
                    if let id = UUID(uuidString: newValue),
                       let pool = store.data.exerciseLibrary.pool(of: id) {
                        slot.pool = pool
                        slot.exerciseID = id
                        slot.exIdx = nil
                        slot.custom = nil
                    }
                }
            }
        )
    }

    private func numField(_ value: Binding<Int>, width: CGFloat) -> some View {
        TextField("", value: value, format: .number)
            .squareFieldStyle()
            .font(.system(.caption, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: width)
    }
}

// MARK: - New exercise popover (in-context library add)

struct NewExercisePopover: View {
    @Environment(\.dismiss) private var dismiss
    let defaultPool: LiftPool
    var onAdd: (LibraryExercise, LiftPool) -> Void

    @State private var name = ""
    @State private var pool: LiftPool
    @State private var isAccessory = true
    @State private var modPct = 90.0

    init(defaultPool: LiftPool, onAdd: @escaping (LibraryExercise, LiftPool) -> Void) {
        self.defaultPool = defaultPool
        self.onAdd = onAdd
        _pool = State(initialValue: defaultPool)
        _isAccessory = State(initialValue: ![.squat, .bench, .deadlift].contains(defaultPool))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Library Exercise").font(.headline)
            TextField("Exercise name", text: $name)
                .squareFieldStyle()
                .frame(width: 240)
            Picker("Group", selection: $pool) {
                ForEach(LiftPool.allCases) { p in Text(p.groupLabel).tag(p) }
            }
            Toggle("Accessory (RPE only, no computed load)", isOn: $isAccessory)
            if !isAccessory {
                HStack {
                    Text("Load modifier")
                    TextField("", value: $modPct, format: .number)
                        .squareFieldStyle().frame(width: 56)
                        .onChange(of: modPct) { v in modPct = min(120, max(30, v)) }
                    Text("% of comp-lift 1RM").foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let ex = LibraryExercise(name: name.trimmingCharacters(in: .whitespaces),
                                             mod: isAccessory ? nil : modPct / 100)
                    onAdd(ex, pool)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }
}

// MARK: - Meet attempts

struct MeetCard: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEET DAY — ATTEMPT SELECTION (FROM CURRENT MAXES)")
                .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 14) {
                attemptBox("Squat", client.maxes.squat)
                attemptBox("Bench", client.maxes.bench)
                attemptBox("Deadlift", client.maxes.deadlift)
            }
            Text("Opener = a weight they could triple on their worst day. Adjust the third based on how the second moves. Never let a lifter miss an opener.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.iron, in: Rectangle())
        .overlay(
            Rectangle()
                .stroke(Theme.line, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.plateWhite).frame(width: 4)
                .clipShape(Rectangle())
        }
    }

    private func attemptBox(_ label: String, _ max: Double) -> some View {
        let profile = client.settings.attempts ?? AttemptProfile()
        let eff = profile.effective
        let a = Engine.attempts(max: max, unit: client.unit, profile: profile)
        func p(_ v: Double) -> String {
            v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased()).font(.system(size: 13, weight: .black))
                if profile.risk != .standard {
                    Text(profile.risk.label.uppercased())
                        .font(.system(size: 8, weight: .black)).kerning(0.5)
                        .foregroundStyle(Theme.plateYellow)
                }
            }
            row("Opener ~\(p(eff.opener))%", a.opener, color: Theme.chalk)
            row("Second ~\(p(eff.second))%", a.second, color: Theme.chalk)
            row("Third ~\(p(eff.third))%", a.third, color: Theme.plateRed)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.iron2, in: Rectangle())
    }

    private func row(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(Engine.loadString(value, unit: client.unit))
                .font(.system(.caption, design: .monospaced)).bold()
                .foregroundStyle(color)
        }
    }
}

// MARK: - RPE chart

struct RPEChartView: View {
    @Environment(\.dismiss) private var dismiss
    private let rpes: [Double] = [7, 7.5, 8, 8.5, 9, 9.5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RPE → % of 1RM").font(.title3).bold()
            Text("RPE = 10 − reps left in the tank. RPE 8 means 2 reps in reserve. Percentages are the plan; RPE is the truth on the day — if the % feels a full point harder than listed, drop the load.")
                .font(.callout).foregroundStyle(.secondary)

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    cell("Reps", header: true)
                    ForEach(rpes, id: \.self) { r in
                        cell("RPE \(r == r.rounded() ? String(Int(r)) : String(r))", header: true)
                    }
                }
                ForEach(Engine.rpeTable, id: \.reps) { entry in
                    GridRow {
                        cell("\(entry.reps)", header: true)
                        ForEach(entry.row, id: \.rpe) { pair in
                            cell("\(pair.pct)%")
                        }
                    }
                }
            }
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))

            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func cell(_ text: String, header: Bool = false) -> some View {
        Text(text)
            .font(.system(.caption, design: header ? .default : .monospaced))
            .fontWeight(header ? .bold : .regular)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(header ? Theme.iron3 : Theme.iron2)
            .border(Theme.line, width: 0.5)
    }
}
