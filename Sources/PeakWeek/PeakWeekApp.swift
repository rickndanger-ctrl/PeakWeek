import SwiftUI
import AppKit

@main
struct PeakWeekApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 680)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

// MARK: - Theme

// Native macOS appearance: every surface uses semantic system colors so the
// app follows the user's light/dark setting and looks like a real Mac app.
// The IPF plate colors survive only as DATA accents (phase timeline, status).
enum Theme {
    static let iron = Color(nsColor: .windowBackgroundColor)          // window
    static let iron2 = Color(nsColor: .controlBackgroundColor)        // panels/cards
    static let iron3 = Color(nsColor: .unemphasizedSelectedContentBackgroundColor) // chips
    static let line = Color(nsColor: .separatorColor)
    static let chalk = Color(nsColor: .labelColor)
    static let smoke = Color(nsColor: .secondaryLabelColor)
    static let plateRed = Color(red: 0.788, green: 0.275, blue: 0.235)
    static let plateBlue = Color(red: 0.239, green: 0.42, blue: 0.71)
    static let plateYellow = Color(red: 0.863, green: 0.663, blue: 0.247)
    static let plateGreen = Color(red: 0.243, green: 0.557, blue: 0.361)
    static let plateWhite = Color(red: 0.949, green: 0.941, blue: 0.918)

    static func phaseColor(_ p: Phase) -> Color {
        switch p {
        case .acc: return plateBlue
        case .trans: return plateYellow
        case .real: return plateRed
        case .deload: return plateGreen
        case .meet: return plateWhite
        case .hyp: return Color(red: 0.42, green: 0.32, blue: 0.64)   // purple: build season
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedID: UUID?
    @State private var showNewClient = false
    @State private var restoreMessage: String?
    @State private var showDeliveries = false

    var body: some View {
        VStack(spacing: 0) {
            if store.loadFailed {
                frozenBanner
            }
            NavigationSplitView {
                sidebar
            } detail: {
                if let id = selectedID, let binding = store.binding(for: id) {
                    ClientView(client: binding, onDelete: {
                        store.deleteClient(id)
                        selectedID = nil
                    })
                    .id(id)
                } else {
                    placeholder
                }
            }
        }
        .background(Theme.iron)
        .sheet(isPresented: $showNewClient) {
            NewClientSheet { client in
                store.addClient(client)
                selectedID = client.id
            }
        }
        .sheet(isPresented: $showDeliveries) {
            DeliveriesView()
        }
        .alert(restoreMessage ?? "", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) { Button("OK", role: .cancel) {} }
        .alert("Peak Week couldn't read its data file",
               isPresented: $store.showLoadFailedAlert) {
            Button("Restore Automatic Backup") {
                restoreMessage = store.restoreAutomaticBackup()
                    ? "Automatic backup restored."
                    : "No readable automatic backup found. Try Restore from a manual backup in the Data menu."
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([AppStore.dataURL])
            }
            Button("Quit", role: .cancel) { NSApplication.shared.terminate(nil) }
        } message: {
            Text("Your clients are safe on disk — nothing will be overwritten. Restore the automatic backup, or quit and inspect the file.")
        }
    }

    private var sidebar: some View {
        List(selection: $selectedID) {
            Section("Roster") {
                ForEach(store.data.clients) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.name).font(.headline)
                        Text("S \(Int(c.maxes.squat)) · B \(Int(c.maxes.bench)) · D \(Int(c.maxes.deadlift)) \(c.unit.rawValue)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(c.program == nil ? "No program yet"
                             : "\(c.program!.startPhase.label.components(separatedBy: " (").first ?? "") · \(c.program!.weeks.count) wks · \(c.program!.fiveDay ? 5 : 4)-day")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(c.id)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        .navigationTitle("Peak Week")
        .toolbar {
            ToolbarItemGroup {
                Button { showNewClient = true } label: { Label("New Client", systemImage: "plus") }
                Button { showDeliveries = true } label: {
                    // .badge() doesn't render on macOS toolbar buttons — draw our own.
                    Label("Deliveries", systemImage: "paperplane")
                        .overlay(alignment: .topTrailing) {
                            if !store.queuedSends.isEmpty {
                                Text("\(store.queuedSends.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(Theme.plateRed)
                                    .offset(x: 8, y: -6)
                            }
                        }
                }
                .help(store.queuedSends.isEmpty
                      ? "Delivery log"
                      : "\(store.queuedSends.count) plan(s) waiting for your approval")
                Menu {
                    Button("Backup all data…") { store.exportBackup() }
                    Button("Restore from backup…") {
                        restoreMessage = store.importBackup()
                            ? "Backup restored." : "Restore cancelled or file not valid."
                        selectedID = nil
                    }
                    Button("Restore automatic backup (.bak)") {
                        restoreMessage = store.restoreAutomaticBackup()
                            ? "Automatic backup restored."
                            : "No readable automatic backup found."
                        selectedID = nil
                    }
                    Divider()
                    Button("Reveal data file in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppStore.dataURL])
                    }
                } label: { Label("Data", systemImage: "externaldrive") }
            }
        }
    }

    /// Shown whenever the write freeze is active — nothing typed while this is
    /// visible will be saved, and the coach must know that.
    private var frozenBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
            Text("SAVING IS DISABLED — the data file couldn't be read. Anything you enter now will NOT be kept.")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Button("Restore Automatic Backup") {
                restoreMessage = store.restoreAutomaticBackup()
                    ? "Automatic backup restored." : "No readable automatic backup found."
            }
            .buttonStyle(.bordered)
            Button("Restore from file…") {
                restoreMessage = store.importBackup()
                    ? "Backup restored." : "Restore cancelled or file not valid."
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(nsColor: .systemRed))
        .foregroundStyle(.white)
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Text("PEAK WEEK")
                .font(.system(size: 46, weight: .black))
                .kerning(1)
            Text("Select a client, or press + to add your first lifter.\nEverything saves automatically on this Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.iron)
    }
}

// MARK: - New client sheet

struct NewClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (Client) -> Void

    @State private var name = ""
    @State private var unit: Unit = .lb
    @State private var squat = 0.0
    @State private var bench = 0.0
    @State private var deadlift = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Client").font(.title2).bold()
            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                Picker("Units", selection: $unit) {
                    ForEach(Unit.allCases) { u in Text(u.rawValue).tag(u) }
                }
                .pickerStyle(.segmented)
                TextField("Squat 1RM", value: $squat, format: .number)
                    .textFieldStyle(.roundedBorder)
                TextField("Bench 1RM", value: $bench, format: .number)
                    .textFieldStyle(.roundedBorder)
                TextField("Deadlift 1RM", value: $deadlift, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add Client") {
                    var c = Client(name: name.trimmingCharacters(in: .whitespaces))
                    c.unit = unit
                    c.maxes = Maxes(squat: squat, bench: bench, deadlift: deadlift)
                    onAdd(c)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
