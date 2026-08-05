import SwiftUI
import PeakWeekCore

@main
struct PeakWeekClientApp: App {
    @StateObject private var session = Session()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WeekWatch.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isPaired {
                    MainTabs()
                } else {
                    PairView()
                }
            }
            .environmentObject(session)
            .tint(ClientTheme.accent)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { WeekWatch.schedule() }
            if phase == .active { Task { await session.refresh() } }
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject var session: Session

    var body: some View {
        TabView {
            WeekScreen()
                .tabItem { Label("This Week", systemImage: "calendar") }
            HistoryScreen()
                .tabItem { Label("My Log", systemImage: "list.bullet.rectangle") }
        }
        .task { await session.refresh() }
    }
}
