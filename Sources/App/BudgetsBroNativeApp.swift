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
}
