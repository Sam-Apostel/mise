import SwiftUI

@main
struct MiseApp: App {
    @State private var model = Seed.makeModel()

    init() {
        ErrorReporting.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
