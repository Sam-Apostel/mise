import SwiftUI

@main
struct MiseApp: App {
    // Launch with `-seedMenu 1` to open straight into a sample menu (used for UI screenshots).
    @State private var session: ScanSession = UserDefaults.standard.bool(forKey: "seedMenu")
        ? .previewLoaded
        : ScanSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
