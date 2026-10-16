import SwiftUI
import MiseShared

/// One flow, no tab bar: camera (home) → menu → dish; people, filters and picks are sheets.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if model.menu == nil {
                CameraView()
                    .transition(.opacity)
            } else {
                NavigationStack(path: $path) {
                    MenuBoardView(path: $path)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.smooth, value: model.menu?.id)
        .tint(Board.ink)
        .onChange(of: model.menu?.id) { _, _ in path = NavigationPath() }
        .task { Seed.openRequestedScreen(model: model, path: $path) }
    }
}

#Preview {
    RootView().environment(Seed.preview(1))
}
