import SwiftUI
import PeakWeekCore

@main
struct PeakWeekClientApp: App {
    @StateObject private var session = Session()

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
