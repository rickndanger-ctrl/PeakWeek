import SwiftUI
import ServiceManagement

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
            Text("Scheduled weekly sends only go out while Peak Week is running — opening at login means Monday-morning plans never get missed.")
                .font(.caption).foregroundStyle(.secondary)
            if let err = loginItemError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            Divider().padding(.vertical, 8)
            LabeledContent("Data file") {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppStore.dataURL])
                }
            }
            Text("Backups: automatic .bak before every save, plus manual Backup/Restore in the toolbar Data menu.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 480)
    }
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
