import SwiftUI
import AVKit
import AppKit

/// The inbound side of the delivery story: client-app submissions as they
/// arrived. Everything already auto-logged — this is the REVIEW surface.
/// Flagged rows lead; "Looks right" clears them, "Remove entry" pulls the
/// data back out of the log (audit row stays, dismissed).
struct InboxView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRejectID: UUID?
    @State private var playingVideoURL: URL?
    @State private var detailRecord: IngestRecord?

    private var fresh: [IngestRecord] {
        store.data.inboxLog.filter { $0.state == .new }
            .sorted {
                // Flagged first, then newest first.
                if $0.flags.isEmpty != $1.flags.isEmpty { return !$0.flags.isEmpty }
                return $0.date > $1.date
            }
    }
    private var history: [IngestRecord] {
        store.data.inboxLog.filter { $0.state != .new }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Client Inbox").font(.title2).bold()
                Spacer()
                if SyncService.isConfigured {
                    Button {
                        store.syncNow()
                    } label: {
                        Label("Check now", systemImage: "arrow.clockwise").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Poll the pipe right now instead of waiting for the hourly pass")
                }
            }
            if store.data.inboxLog.isEmpty {
                Text("Nothing yet. When a lifter logs a result from the client app, it lands in their Trends & Log automatically and shows up here for your eyes — flagged if anything looks off.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Everything lives in ONE scroll, bounded to a fixed height —
            // with 18 unreviewed rows the old unwrapped "fresh" section grew
            // taller than the screen with nothing to scroll it, so rows past
            // the fold were simply unreachable.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !fresh.isEmpty {
                        Text("NEW — ALREADY LOGGED, AWAITING YOUR EYES")
                            .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            ForEach(fresh) { rec in row(rec, actionable: true) }
                        }
                    }
                    if !history.isEmpty {
                        Text("HISTORY")
                            .font(.caption2).kerning(1.5).foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            ForEach(history.prefix(50)) { rec in row(rec, actionable: false) }
                        }
                    }
                }
            }
            .frame(maxHeight: 480)

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
        .sheet(item: $detailRecord) { rec in
            InboxDetailView(record: rec, onPlayVideo: { playingVideoURL = $0 })
        }
        .sheet(isPresented: Binding(get: { playingVideoURL != nil },
                                    set: { if !$0 { playingVideoURL = nil } })) {
            if let url = playingVideoURL {
                VStack(spacing: 10) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(width: 560, height: 400)
                    HStack {
                        Button("Open in QuickTime") { NSWorkspace.shared.open(url) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Done") { playingVideoURL = nil }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
            }
        }
        .confirmationDialog(
            "Remove this entry from the lifter's log? The submission stays in history as rejected.",
            isPresented: Binding(get: { confirmRejectID != nil },
                                 set: { if !$0 { confirmRejectID = nil } }),
            titleVisibility: .visible) {
            Button("Remove entry", role: .destructive) {
                if let id = confirmRejectID { store.rejectIngest(id) }
                confirmRejectID = nil
            }
            Button("Cancel", role: .cancel) { confirmRejectID = nil }
        }
    }

    /// The log entry this inbox row created, found by submission id.
    private func entry(_ rec: IngestRecord) -> LiftLogEntry? {
        store.data.clients.first { $0.id == rec.clientID }?
            .logs.first { $0.submissionID == rec.submissionID }
    }

    private func loggedNote(_ rec: IngestRecord) -> String? {
        entry(rec)?.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What the program asked for, beside what she actually did. Both values
    /// ride the wire already; they were simply never shown.
    private func prescribedLine(_ rec: IngestRecord) -> String? {
        guard let e = entry(rec) else { return nil }
        var bits: [String] = []
        if let pct = e.prescribedPct { bits.append(String(format: "%.0f%%", pct)) }
        if let rpe = e.prescribedRPE {
            bits.append("RPE \(rpe == rpe.rounded() ? String(Int(rpe)) : String(rpe))")
        }
        guard !bits.isEmpty else { return nil }
        return "prescribed \(bits.joined(separator: " · "))"
    }

    @ViewBuilder
    private func row(_ rec: IngestRecord, actionable: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            stateIcon(rec)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if rec.effectiveKind == .note {
                        Text("\(rec.clientName):").fontWeight(.semibold)
                        Text("“\(rec.summary)”").italic()
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(rec.clientName) — \(rec.summary)").fontWeight(.medium)
                    }
                    if let filename = rec.videoFilename {
                        Button {
                            let url = SyncService.localVideoURL(
                                clientID: rec.clientID,
                                submissionID: rec.submissionID)
                            if FileManager.default.fileExists(atPath: url.path) {
                                playingVideoURL = url
                            }
                        } label: {
                            Label("Play", systemImage: "play.rectangle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Watch \(filename)")
                    }
                }
                // Read the note off the LOG ENTRY rather than the stored
                // summary, so rows that landed before notes were surfaced
                // still show what she actually said.
                if rec.effectiveKind == .set, let said = loggedNote(rec), !said.isEmpty {
                    Text("“\(said)”")
                        .font(.caption).italic()
                        .foregroundStyle(Theme.plateBlue)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let pres = prescribedLine(rec) {
                    Text(pres).font(.caption2).foregroundStyle(.secondary)
                }
                if !rec.flags.isEmpty {
                    Text(rec.flags.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.orange)
                }
                Text("\(rec.performedAt.formatted(date: .abbreviated, time: .omitted)) · arrived \(rec.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                detailRecord = rec
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
            .help("Open — full text, reply, and actions")
            if actionable {
                Button(rec.effectiveKind == .note ? "Read it" : "Looks right") {
                    store.markIngestReviewed(rec.id)
                }
                .buttonStyle(.bordered).font(.caption)
                if rec.effectiveKind == .set {
                    Button("Remove entry") { confirmRejectID = rec.id }
                        .buttonStyle(.borderless).font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text(rec.state == .reviewed ? "reviewed" : "rejected")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Theme.iron2, in: Rectangle())
        .overlay(Rectangle().stroke(
            rec.state == .new && !rec.flags.isEmpty
                ? Color.orange.opacity(0.6) : Theme.line, lineWidth: 1))
    }

    @ViewBuilder
    private func stateIcon(_ rec: IngestRecord) -> some View {
        switch rec.state {
        case .new:
            Image(systemName: rec.effectiveKind == .note ? "bubble.left.fill"
                  : rec.flags.isEmpty ? "tray.and.arrow.down.fill" : "flag.fill")
                .foregroundStyle(rec.effectiveKind == .note ? Theme.plateBlue
                                 : rec.flags.isEmpty ? Theme.plateGreen : .orange)
        case .reviewed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.plateGreen)
        case .dismissed:
            Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }
}

// MARK: - One item, full text, guaranteed unclipped — and the reply hook

/// Opened from a row's expand button. Shows the complete text (selectable,
/// wraps instead of truncating) and, if the client has a phone/iMessage
/// handle on file, a button that jumps straight to that conversation in
/// Messages — not a reply box built into this app. iMessage already IS the
/// channel of record for every client, app or no app; a second, in-app
/// message thread would just be a copy of that conversation the coach has
/// to remember to keep checking, and it would only ever reach clients who
/// have the app paired. This keeps replying one tap away without building
/// a second inbox.
struct InboxDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let record: IngestRecord
    var onPlayVideo: (URL) -> Void

    @State private var confirmReject = false
    @State private var replyContext = ""
    @State private var justCopied = false

    private var client: Client? {
        store.data.clients.first { $0.id == record.clientID }
    }
    private var entry: LiftLogEntry? {
        client?.logs.first { $0.submissionID == record.submissionID }
    }
    private var note: String? {
        guard record.effectiveKind == .set else { return nil }
        let n = entry?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? nil : n
    }
    private var prescribedLine: String? {
        guard let e = entry else { return nil }
        var bits: [String] = []
        if let pct = e.prescribedPct { bits.append(String(format: "%.0f%%", pct)) }
        if let rpe = e.prescribedRPE {
            bits.append("RPE \(rpe == rpe.rounded() ? String(Int(rpe)) : String(rpe))")
        }
        return bits.isEmpty ? nil : "prescribed \(bits.joined(separator: " · "))"
    }
    private var recipient: String? {
        let r = client?.delivery.recipient.trimmingCharacters(in: .whitespaces) ?? ""
        return r.isEmpty ? nil : r
    }

    /// What she'll see quoted back at her — the starting point for the reply
    /// draft, editable before anything touches Messages. Standalone notes
    /// carry their body IN `summary` (Store.ingestNote sets it directly).
    /// Logged sets after the note-surfacing fix already have the note BAKED
    /// into `summary` too (Ingest.summary appends it at ingest time) — only
    /// append it again for older rows where that hadn't happened yet, or
    /// this would quote the same line twice.
    private var defaultReplyContext: String {
        if record.effectiveKind == .note {
            return "Re: “\(record.summary)”"
        }
        var line = "Re: \(record.summary)"
        if let note, !record.summary.contains(note) { line += " — “\(note)”" }
        return line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.clientName).font(.title3).bold()
                Text(record.effectiveKind == .note ? "NOTE" : "LOGGED SET")
                    .font(.caption2).kerning(1).foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(record.summary)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    if let pres = prescribedLine {
                        Text(pres).font(.caption).foregroundStyle(.secondary)
                    }

                    if let note {
                        Divider()
                        Text("NOTE").font(.caption2).kerning(1).foregroundStyle(.secondary)
                        Text(note)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !record.flags.isEmpty {
                        Divider()
                        Text("FLAGGED").font(.caption2).kerning(1).foregroundStyle(.orange)
                        Text(record.flags.joined(separator: " · "))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)

            Text("Logged \(record.performedAt.formatted(date: .abbreviated, time: .shortened)) · arrived \(record.date.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2).foregroundStyle(.secondary)

            Divider()

            if recipient != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPLY WILL QUOTE").font(.caption2).kerning(1).foregroundStyle(.secondary)
                    TextField("", text: $replyContext, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text(justCopied
                         ? "Copied — paste with ⌘V once Messages is open."
                         : "Messages has no way to prefill a draft, so this goes to your clipboard — paste it in, edit it, then send it yourself.")
                        .font(.caption2).foregroundStyle(justCopied ? Theme.plateGreen : .secondary)
                }
                .onAppear { if replyContext.isEmpty { replyContext = defaultReplyContext } }
            }

            HStack(spacing: 10) {
                if let recipient {
                    Button {
                        openInMessages(recipient)
                    } label: {
                        Label("Reply in Messages", systemImage: "message.fill")
                    }
                    .buttonStyle(.bordered)
                }
                if let filename = record.videoFilename {
                    Button {
                        let url = SyncService.localVideoURL(
                            clientID: record.clientID, submissionID: record.submissionID)
                        if FileManager.default.fileExists(atPath: url.path) {
                            onPlayVideo(url)
                        }
                    } label: {
                        Label("Play video", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(.bordered)
                    .help(filename)
                }
                Spacer()
                if record.state == .new {
                    Button(record.effectiveKind == .note ? "Read it" : "Looks right") {
                        store.markIngestReviewed(record.id)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    if record.effectiveKind == .set {
                        Button("Remove entry") { confirmReject = true }
                            .buttonStyle(.borderless).foregroundStyle(.red)
                    }
                }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .confirmationDialog(
            "Remove this entry from the lifter's log? The submission stays in history as rejected.",
            isPresented: $confirmReject, titleVisibility: .visible) {
            Button("Remove entry", role: .destructive) {
                store.rejectIngest(record.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Opens Messages.app straight to this client's conversation and puts the
    /// quoted context on the clipboard. Standard URL handoff — no Automation
    /// permission needed (that's only required for the AppleScript SEND path
    /// used by scheduled delivery); this never sends anything itself.
    ///
    /// There's no supported way to do better than the clipboard here: Messages'
    /// AppleScript dictionary has a `send` verb (fires immediately — wrong for
    /// a draft) but nothing to populate the compose field without sending, and
    /// the `sms:...&body=` URL trick some sites use isn't documented or
    /// consistently honored by macOS Messages, so it isn't something to
    /// silently depend on.
    private func openInMessages(_ recipient: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(replyContext.isEmpty ? defaultReplyContext : replyContext, forType: .string)
        justCopied = true

        guard let encoded = recipient.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Simulate a submission (drives the REAL ingest pipeline)

/// Test harness for the whole inbound path before any client device exists:
/// pick a client, type what "they" logged, submit — it runs through the
/// exact ingest → anomaly → notification path a real phone submission will.
struct SimulateSubmissionSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var clientID: UUID?
    @State private var lift: LiftPool = .squat
    @State private var load = 0.0
    @State private var unit: Unit = .lb
    @State private var reps = 5
    @State private var rpe: Double? = nil
    @State private var note = ""
    @State private var attachVideo = false
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Simulate Client Submission").font(.title3).bold()
            Text("Runs the REAL ingest pipeline — unit conversion, anomaly flags, notification — exactly as a phone submission will.")
                .font(.caption).foregroundStyle(.secondary)

            Picker("Client", selection: $clientID) {
                Text("Pick…").tag(UUID?.none)
                ForEach(store.data.clients) { c in
                    Text(c.name).tag(UUID?.some(c.id))
                }
            }
            HStack(spacing: 8) {
                Picker("", selection: $lift) {
                    Text("SQ").tag(LiftPool.squat)
                    Text("BP").tag(LiftPool.bench)
                    Text("DL").tag(LiftPool.deadlift)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 130)
                TextField("load", value: $load, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                Picker("", selection: $unit) {
                    ForEach(Unit.allCases) { u in Text(u.rawValue).tag(u) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 90)
                Text("×")
                Stepper(value: $reps, in: 1...12) { Text("\(reps)") }.fixedSize()
                Text("@ RPE")
                OptionalNumberField(placeholder: "—", value: $rpe, width: 44)
            }
            TextField("note", text: $note).textFieldStyle(.roundedBorder)
            Toggle("Pretend a video is attached", isOn: $attachVideo)
                .toggleStyle(.checkbox).font(.caption)

            if let result {
                Text(result).font(.caption).fontWeight(.medium)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Button("Submit through pipeline") {
                    guard let clientID else { return }
                    let sub = Submission(
                        clientID: clientID, performedAt: Date(), lift: lift,
                        load: load, unit: unit, reps: reps, rpe: rpe,
                        note: note.isEmpty ? nil : note,
                        videoFilename: attachVideo ? "simulated.mp4" : nil)
                    if let rec = store.ingest(sub) {
                        result = rec.flags.isEmpty
                            ? "Ingested clean: \(rec.summary)"
                            : "Ingested + FLAGGED: \(rec.flags.joined(separator: " · "))"
                    } else {
                        result = "Skipped (duplicate, unknown client, or write freeze)."
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(clientID == nil || load <= 0)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
