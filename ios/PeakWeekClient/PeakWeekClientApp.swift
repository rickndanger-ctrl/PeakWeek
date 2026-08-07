import SwiftUI
import PeakWeekCore

/// iOS relaunches the app in the background when a background upload finishes.
/// Without this hook the system never learns we're done draining events, and
/// it throttles future transfers.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == VideoUploader.sessionID else { return completionHandler() }
        Task { @MainActor in
            VideoUploader.shared.backgroundCompletionHandler = completionHandler
        }
    }
}

@main
struct PeakWeekClientApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
