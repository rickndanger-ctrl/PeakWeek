import SwiftUI

// MARK: - Delivery log & review queue

struct DeliveriesView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var previewID: UUID?

    private var queued: [SendRecord] { store.queuedSends }

    /// The exact copy a queued record will send, or nil when it can't (client
    /// gone / program changed since queuing).
    private func previewText(_ rec: SendRecord) -> String? {
        guard let client = store.data.clients.first(where: { $0.id == rec.clientID }),
              let program = client.program,
              rec.programStamp == nil || rec.programStamp == program.createdAt,
              let week = program.weeks.first(where: { $0.num == rec.weekNum })
        else { return nil }
        return Engine.weekToText(client: client, program: program, week: week,
                                 library: store.data.exerciseLibrary)
    }
    private var history: [SendRecord] {
        store.data.sendLog
            .filter { if case .queued = $0.status { return false }; return true }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deliveries").font(.title2).bold()

            if queued.isEmpty && history.isEmpty {
                Text("Nothing here yet. Turn on Auto-send for a client (with a recipient and a start date) and due weeks will show up — queued for review, or sent and logged.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }

            if !queued.isEmpty {
                Text("WAITING FOR YOUR APPROVAL")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                ForEach(queued) { rec in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(rec.clientName) — Week \(rec.weekNum)").fontWeight(.semibold)
                                Text("via \(rec.method.label) · due \(rec.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(previewID == rec.id ? "Hide" : "Preview") {
                                previewID = previewID == rec.id ? nil : rec.id
                            }
                            .buttonStyle(.bordered)
                            .help("Read the exact message before approving")
                            Button("Dismiss") { store.dismissQueued(rec.id) }
                            Button("Send") { store.approveQueued(rec.id) }
                                .buttonStyle(.borderedProminent).tint(Theme.plateGreen)
                        }
                        .padding(10)

                        if previewID == rec.id {
                            Divider()
                            if let text = previewText(rec) {
                                ScrollView {
                                    Text(text)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 220)
                                .padding(10)
                                if let client = store.data.clients.first(where: { $0.id == rec.clientID }),
                                   client.delivery.format != .text {
                                    Text("A PDF of this week is attached as well (format: \(client.delivery.format.label)).")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .padding(.horizontal, 10).padding(.bottom, 8)
                                }
                            } else {
                                Text("This exact copy no longer exists (the program changed since it was queued) — dismiss it; the current week will queue on the next pass.")
                                    .font(.caption).foregroundStyle(.orange)
                                    .padding(10)
                            }
                        }
                    }
                    .background(Theme.iron2, in: Rectangle())
                }
            }

            if !history.isEmpty {
                Text("HISTORY")
                    .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(history.prefix(50)) { rec in
                            HStack(spacing: 10) {
                                statusIcon(rec.status)
                                Text("\(rec.clientName) — Week \(rec.weekNum)")
                                    .fontWeight(.medium)
                                Text(rec.status.label)
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if case .failed = rec.status,
                                   store.data.clients.contains(where: { $0.id == rec.clientID }) {
                                    Button("Retry") { store.retryFailed(rec.id) }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                }
                                Text(rec.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4).padding(.horizontal, 8)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder
    private func statusIcon(_ status: SendStatus) -> some View {
        switch status {
        case .sent: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.plateGreen)
        case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(Theme.plateRed)
        case .skipped: Image(systemName: "arrow.uturn.forward.circle").foregroundStyle(.secondary)
        case .queued: Image(systemName: "clock").foregroundStyle(Theme.plateYellow)
        }
    }
}
