import SwiftUI
import PhotosUI
import PeakWeekCore

/// Log what the bar actually said. Prefilled from the prescribed slot when
/// opened from the week view; blank for anything else. Attach a video from
/// the library — it compresses on-device and uploads in the background.
struct LogFormView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    let prefill: PublishedWeek.Loggable?
    let dayTitle: String?

    @State private var lift: String = "squat"
    @State private var load: Double = 0
    @State private var unit: String = "lb"
    @State private var reps: Int = 5
    @State private var rpeIndex: Int = 0        // 0 = none, else 6.5 + 0.5*(i-1)
    @State private var note = ""
    @State private var videoItem: PhotosPickerItem?
    @State private var videoLocalPath: String?
    @State private var showCamera = false
    @State private var processingVideo = false
    @State private var loaded = false

    private let rpeChoices: [Double?] = [nil] + stride(from: 6.5, through: 10, by: 0.5).map { $0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Lift", selection: $lift) {
                        Text("Squat").tag("squat")
                        Text("Bench").tag("bench")
                        Text("Deadlift").tag("deadlift")
                    }
                    .disabled(prefill != nil)
                    HStack {
                        Text("Load")
                        Spacer()
                        TextField("0", value: $load, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .font(.system(.body, design: .monospaced))
                        Picker("", selection: $unit) {
                            Text("lb").tag("lb")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.segmented).frame(width: 100)
                    }
                    Stepper("Reps: \(reps)", value: $reps, in: 1...12)
                    Picker("RPE", selection: $rpeIndex) {
                        ForEach(rpeChoices.indices, id: \.self) { i in
                            if let v = rpeChoices[i] {
                                Text(v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)).tag(i)
                            } else {
                                Text("not sure").tag(i)
                            }
                        }
                    }
                } header: {
                    if let prefill, let dayTitle {
                        Text("\(dayTitle) — prescribed: \(prefill.sets)×\(prefill.reps)\(prefill.pct.map { String(format: " @ %.0f%%", $0) } ?? "")\(prefill.rpe.map { " RPE \($0 == $0.rounded() ? String(Int($0)) : String($0))" } ?? "")")
                    } else {
                        Text("Top set")
                    }
                }

                Section("Video (optional)") {
                    if CameraPicker.isAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Record this set", systemImage: "video.badge.plus")
                        }
                    }
                    PhotosPicker(selection: $videoItem, matching: .videos) {
                        Label(videoLocalPath == nil ? "Attach from library" : "Video attached ✓",
                              systemImage: videoLocalPath == nil ? "photo.on.rectangle" : "checkmark.circle.fill")
                    }
                    if processingVideo { ProgressView("Compressing…") }
                    if videoLocalPath != nil {
                        Button("Remove video", role: .destructive) {
                            if let p = videoLocalPath { try? FileManager.default.removeItem(atPath: p) }
                            videoLocalPath = nil
                            videoItem = nil
                        }
                    }
                }

                Section("Note to coach") {
                    TextField("moved fast / grinder / hips shot up…", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Log result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .bold()
                        .disabled(load <= 0 || processingVideo)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let prefill {
                    lift = prefill.lift.rawValue
                    load = prefill.load ?? 0
                    reps = prefill.reps
                    unit = session.week?.unit.rawValue ?? session.client?.unit ?? "lb"
                    if let r = prefill.rpe,
                       let idx = rpeChoices.firstIndex(where: { $0 == r }) {
                        rpeIndex = idx
                    }
                } else {
                    unit = session.client?.unit ?? "lb"
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { url in
                    processingVideo = true
                    Task {
                        defer { processingVideo = false }
                        if let compressed = try? await VideoCompressor.compress(url) {
                            let dest = FileManager.default
                                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("pending-\(UUID().uuidString).mp4")
                            try? FileManager.default.createDirectory(
                                at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try? FileManager.default.moveItem(at: compressed, to: dest)
                            videoLocalPath = dest.path
                        }
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: videoItem) { item in
                guard let item else { return }
                processingVideo = true
                Task {
                    defer { processingVideo = false }
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    let raw = FileManager.default.temporaryDirectory
                        .appendingPathComponent("raw-\(UUID().uuidString).mov")
                    try? data.write(to: raw)
                    if let compressed = try? await VideoCompressor.compress(raw) {
                        // Move into the app container so it survives restarts.
                        let dest = FileManager.default
                            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("pending-\(UUID().uuidString).mp4")
                        try? FileManager.default.createDirectory(
                            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? FileManager.default.moveItem(at: compressed, to: dest)
                        videoLocalPath = dest.path
                    }
                    try? FileManager.default.removeItem(at: raw)
                }
            }
        }
    }

    private func send() {
        let pending = PendingSubmission(
            performedAt: Date(),
            lift: lift,
            exerciseName: prefill?.exerciseName,
            load: load,
            unit: unit,
            reps: reps,
            rpe: rpeChoices[rpeIndex],
            prescribedPct: prefill?.pct,
            prescribedRPE: prefill?.rpe,
            weekNum: session.week?.weekNum,
            programStamp: session.week?.programStamp,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note,
            videoLocalPath: videoLocalPath)
        session.submit(pending)
        dismiss()
    }
}
