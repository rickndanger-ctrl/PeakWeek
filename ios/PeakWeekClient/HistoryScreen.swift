import SwiftUI
import PeakWeekCore

/// Everything you've logged: what's still queued on this phone, and what
/// your coach's system has received.
struct HistoryScreen: View {
    @EnvironmentObject var session: Session
    @State private var serverRows: [API.MineRow] = []

    var body: some View {
        NavigationStack {
            List {
                let queued = session.outbox.undelivered
                if !queued.isEmpty {
                    Section("On its way") {
                        ForEach(queued) { p in
                            row(lift: p.lift, load: p.load, unit: p.unit, reps: p.reps,
                                rpe: p.rpe, date: p.performedAt,
                                status: p.state == .uploadingVideo
                                    ? "uploading video…" : "queued — sends when you're online",
                                icon: "clock", color: .orange)
                        }
                    }
                }
                Section("Delivered") {
                    if serverRows.isEmpty {
                        Text("Nothing yet — log your first top set from This Week.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(serverRows) { r in
                        row(lift: r.lift, load: r.load, unit: r.unit, reps: r.reps,
                            rpe: r.rpe, date: r.performedAt,
                            status: r.status == "ingested"
                                ? "in your coach's log ✓" : "delivered",
                            icon: "checkmark.circle.fill", color: ClientTheme.plateGreen)
                    }
                }
            }
            .navigationTitle("My Log")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        await session.refresh()
        if let token = Keychain.token(),
           let rows = try? await API.mine(token: token) {
            serverRows = rows
        }
    }

    private func row(lift: String, load: Double, unit: String, reps: Int,
                     rpe: Double?, date: Date, status: String,
                     icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(lift.capitalized).bold()
                    Text("\(load.formatted(.number.precision(.fractionLength(0...1)))) \(unit) × \(reps)")
                        .font(.system(.subheadline, design: .monospaced))
                    if let rpe {
                        Text("@\(rpe == rpe.rounded() ? String(Int(rpe)) : String(rpe))")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(date.formatted(date: .abbreviated, time: .omitted)) · \(status)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
