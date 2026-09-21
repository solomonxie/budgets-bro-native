import SwiftUI

@main
struct BudgetsBroNativeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let appLock = AppLockController.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                if appLock.isLocked {
                    LockScreenView(controller: appLock)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                Self.ensureDemoBoardSeededOnce()
                appLock.appDidLaunch()
                AutoPostRunner.run()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appLock.appWillEnterForeground()
                AutoPostRunner.run()
            case .background:
                appLock.appDidEnterBackground()
            default:
                break
            }
        }
    }

    /// Every install gets a "Demo" board to switch to before showing
    /// someone the app — once only, ever, tracked by a settings flag so
    /// deleting it doesn't bring it back uninvited. See budgets-bro's
    /// `useEnsureDemoBoard`. Settings' "Create Demo Board" reuses the same
    /// seeder directly for a deliberate, on-demand re-creation.
    private static func ensureDemoBoardSeededOnce() {
        let settings = AppSettingsRepository()
        guard settings.get("demo_board_seeded") == nil else { return }
        let originalBoardId = BoardContext.shared.currentBoardId
        // Checked before seeding switches the active board out from under
        // this query — a fresh install's default board is empty, so land on
        // the demo automatically; real data already there keeps showing it.
        let originalBoardHadData = !AccountsRepository().all(includeArchived: true).isEmpty
        DemoBoardSeeder.seed()
        if originalBoardHadData {
            BoardContext.shared.currentBoardId = originalBoardId
        }
        settings.set("demo_board_seeded", "1")
    }
}
