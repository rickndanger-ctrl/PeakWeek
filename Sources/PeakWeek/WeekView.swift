import SwiftUI
import CoreTransferable

// MARK: - Week delivery transferable

/// Lets the share sheet produce the PDF lazily — only rendered when the coach
/// actually picks a destination (Messages, Mail, AirDrop…).
struct WeekPDFTransfer: Transferable {
    let client: Client
    let program: Program
    let week: Week

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            guard let url = WeekExporter.writeTempPDF(client: item.client,
                                                     program: item.program,
                                                     week: item.week) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

// MARK: - Week

struct WeekView: View {
    @Binding var week: Week
    let client: Client
    let program: Program
    @Binding var isExpanded: Bool
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                content
            }
        }
        .background(Theme.iron2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
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

            Menu {
                ShareLink(item: weekText) {
                    Label("Send as text…", systemImage: "message")
                }
                ShareLink(item: WeekPDFTransfer(client: client, program: program, week: week),
                          preview: SharePreview("\(client.name) — Week \(week.num)")) {
                    Label("Send as PDF…", systemImage: "doc.richtext")
                }
                Divider()
                Button("Save PDF…") {
                    WeekExporter.savePDF(client: client, program: program, week: week)
                }
            } label: {
                Label("Send", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 14)
            .help("Send this week's plan to \(client.name)")
        }
    }

    private var weekText: String {
        Engine.weekToText(client: client, program: program, week: week)
    }

    private var headerMeta: String {
        var s: String
        switch week.phase {
        case .meet: s = "Meet week — compete"
        case .deload: s = "Recovery week"
        default: s = "Block week \(week.weekInBlock) of \(week.blockLen)"
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
                    .textFieldStyle(.roundedBorder)
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
            if !day.slots.isEmpty {
                Button {
                    day.slots.append(Slot(pool: .back, exIdx: 0, sets: 3, reps: 10, pct: nil, rpe: 8))
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Theme.iron, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Slot

struct SlotRow: View {
    @Binding var slot: Slot
    let client: Client
    let onRemove: () -> Void

    private var pctText: Binding<String> {
        Binding(
            get: { slot.pct.map { String(Int($0)) } ?? "" },
            set: { slot.pct = Double($0) }
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
                            ForEach(Array((Engine.pools[pool] ?? []).enumerated()), id: \.offset) { i, ex in
                                Text("\(pool.groupLabel) — \(ex.name)").tag("\(pool.rawValue):\(i)")
                            }
                        }
                        Text("✎ Custom exercise…").tag("custom")
                    }
                    .labelsHidden()
                    .fontWeight(.semibold)
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
                Text("×").foregroundStyle(.secondary)
                numField($slot.reps, width: 38)
                Text("@").foregroundStyle(.secondary)
                TextField("—", text: pctText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                Text("%").foregroundStyle(.secondary)
                if let load = Engine.slotLoad(slot, maxes: client.maxes, unit: client.unit) {
                    Text("→ \(Engine.loadString(load, unit: client.unit))")
                        .font(.system(.caption, design: .monospaced)).bold()
                        .foregroundStyle(Theme.plateYellow)
                }
                Spacer(minLength: 4)
                Text("RPE").font(.caption2).foregroundStyle(.secondary)
                TextField("", value: $slot.rpe, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var exerciseSelection: Binding<String> {
        Binding(
            get: { "\(slot.pool.rawValue):\(slot.exIdx)" },
            set: { newValue in
                if newValue == "custom" {
                    slot.custom = ""
                    slot.pct = nil
                } else {
                    let parts = newValue.split(separator: ":")
                    if parts.count == 2, let pool = LiftPool(rawValue: String(parts[0])),
                       let idx = Int(parts[1]) {
                        slot.pool = pool
                        slot.exIdx = idx
                        slot.custom = nil
                    }
                }
            }
        )
    }

    private func numField(_ value: Binding<Int>, width: CGFloat) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .font(.system(.caption, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: width)
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
        .background(Theme.iron, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.line, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.plateWhite).frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private func attemptBox(_ label: String, _ max: Double) -> some View {
        let a = Engine.attempts(max: max, unit: client.unit)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 13, weight: .black))
            row("Opener ~91%", a.opener, color: Theme.chalk)
            row("Second ~97%", a.second, color: Theme.chalk)
            row("Third ~101.5%", a.third, color: Theme.plateRed)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.iron2, in: RoundedRectangle(cornerRadius: 8))
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
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))

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
