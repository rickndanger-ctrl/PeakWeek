import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Settings window (⌘,)

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            LibrarySettingsView()
                .tabItem { Label("Exercise Library", systemImage: "list.bullet.rectangle") }
        }
        .frame(width: 640, height: 460)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var notifyStatus: UNAuthorizationStatus = .notDetermined
    @State private var testResult: String?

    private var notifyIcon: String {
        switch notifyStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "bell.slash.fill"
        default: return "bell"
        }
    }
    private var notifyColor: Color {
        switch notifyStatus {
        case .authorized, .provisional, .ephemeral: return Theme.plateGreen
        case .denied: return Theme.plateRed
        default: return .secondary
        }
    }
    private var notifyLabel: String {
        switch notifyStatus {
        case .authorized, .provisional, .ephemeral: return "On — you'll hear about failed sends and client notes"
        case .denied: return "Off — failed sends will be silent"
        default: return "Not set up yet"
        }
    }

    private func refreshNotifyStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifyStatus = s.authorizationStatus }
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in
                refreshNotifyStatus()
            }
    }

    private func openNotificationSettings() {
        // Once denied, macOS won't re-prompt — the switch lives in System Settings.
        let id = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
        if let url { NSWorkspace.shared.open(url) }
    }

    var body: some View {
        Form {
            Toggle("Open Peak Week at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Text("Scheduled weekly sends only go out while Peak Week is running — opening at login means Monday-morning plans never get missed. (Login items require the copy in /Applications.)")
                .font(.caption).foregroundStyle(.secondary)
                .onAppear {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                    refreshNotifyStatus()
                }
            if let err = loginItemError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            Divider().padding(.vertical, 8)
            LabeledContent("Notifications") {
                HStack(spacing: 8) {
                    Image(systemName: notifyIcon)
                        .foregroundStyle(notifyColor)
                    Text(notifyLabel).font(.caption)
                    Spacer()
                    switch notifyStatus {
                    case .notDetermined:
                        Button("Turn on…") { requestNotifications() }
                    case .denied:
                        Button("Open System Settings") { openNotificationSettings() }
                    default:
                        Button("Send a test") {
                            testResult = "Sending…"
                            Notifier.test { testResult = $0 }
                        }
                    }
                }
            }
            if let testResult {
                Text(testResult).font(.caption).foregroundStyle(Theme.plateBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Peak Week tells you when a client logs something odd, when they send a note, and — most importantly — when a weekly send FAILS. Failed sends don't retry on their own, so this is how you find out.")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            LabeledContent("Data file") {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppStore.dataURL])
                }
            }
            Text("Backups: automatic .bak before every save, plus manual Backup/Restore in the toolbar Data menu.")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            LabeledContent("Client app sync") {
                HStack(spacing: 8) {
                    Image(systemName: SyncService.isConfigured
                          ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(SyncService.isConfigured ? Theme.plateGreen : .secondary)
                    Text(SyncService.isConfigured
                         ? "Connected (coach key in Keychain)"
                         : "Not configured")
                        .font(.caption)
                    Button("Test connection") {
                        syncTestResult = nil
                        Task { syncTestResult = await SyncService.testConnection() }
                    }
                    .font(.caption)
                    if let ok = syncTestResult {
                        Text(ok ? "✓ pipe answering" : "✗ no answer — check network")
                            .font(.caption)
                            .foregroundStyle(ok ? Theme.plateGreen : .red)
                    }
                }
            }
            Text("The pipe carries client-app submissions in and published weeks out. Pair a lifter's phone from their delivery panel; unpair there any time.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 480)
    }

    @State private var syncTestResult: Bool?
}

// MARK: - Exercise library editor

struct LibrarySettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPool: LiftPool = .squat
    @State private var confirmDeleteID: UUID?

    private var exercises: [LibraryExercise] {
        store.data.exerciseLibrary[selectedPool]
    }

    var body: some View {
        HSplitView {
            // Pool list
            List(selection: $selectedPool) {
                ForEach(LiftPool.allCases) { pool in
                    Text(pool.groupLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .tag(pool)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150, maxWidth: 180)

            // Exercise table
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(exercises) { ex in
                            row(ex)
                            Divider()
                        }
                    }
                }
                Divider()
                footer
            }
            .frame(minWidth: 400)
        }
        .confirmationDialog(
            "Delete this exercise from the library?",
            isPresented: Binding(get: { confirmDeleteID != nil },
                                 set: { if !$0 { confirmDeleteID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteID { store.data.exerciseLibrary.remove(id) }
                confirmDeleteID = nil
            }
        } message: {
            Text("Slots already using it in saved programs will show \"Exercise\" until you pick a replacement.")
        }
    }

    private var header: some View {
        HStack {
            Text(selectedPool.groupLabel)
                .font(.system(size: 13, weight: .black)).kerning(1)
            Spacer()
            Text(selectedPool == .squat || selectedPool == .bench || selectedPool == .deadlift
                 ? "Load = 1RM × set % × modifier"
                 : "Accessories are RPE-only")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func row(_ ex: LibraryExercise) -> some View {
        HStack(spacing: 10) {
            TextField("Name", text: Binding(
                get: { ex.name },
                set: { var e = ex; e.name = $0; store.data.exerciseLibrary.update(e) }
            ))
            .textFieldStyle(.plain)
            .fontWeight(.medium)
            .foregroundStyle(ex.archived ? .secondary : .primary)

            if ex.seedKey != nil {
                Text("built-in")
                    .font(.system(size: 9, weight: .semibold)).kerning(0.5)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Theme.iron3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if ex.mod != nil {
                TextField("", value: Binding(
                    get: { (ex.mod ?? 1) * 100 },
                    set: { var e = ex; e.mod = min(120, max(30, $0)) / 100; store.data.exerciseLibrary.update(e) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 48)
                Text("%").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("accessory").font(.caption).foregroundStyle(.secondary)
            }

            Button {
                store.data.exerciseLibrary.setArchived(ex.id, !ex.archived)
            } label: {
                Image(systemName: ex.archived ? "archivebox.fill" : "archivebox")
            }
            .buttonStyle(.borderless)
            .help(ex.archived ? "Unarchive (show in pickers again)" : "Archive (hide from pickers; saved programs unaffected)")

            if ex.seedKey == nil {
                Button { confirmDeleteID = ex.id } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.plateRed)
                .help("Delete permanently")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
    }

    private var footer: some View {
        HStack {
            Button {
                let isMain = [LiftPool.squat, .bench, .deadlift].contains(selectedPool)
                store.data.exerciseLibrary.add(
                    LibraryExercise(name: "New Exercise", mod: isMain ? 0.9 : nil),
                    to: selectedPool)
            } label: { Image(systemName: "plus") }
            .buttonStyle(.borderless)
            .help("Add exercise to \(selectedPool.groupLabel)")
            Spacer()
            Text("Rename or adjust modifiers any time — saved programs follow along instantly.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}
