import SwiftUI

@main
struct MiseApp: App {
    @State private var model = Seed.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
