import SwiftUI

/// Top-level navigation. The flow is: scan a menu → browse the dishes with filters.
///
/// Wireframes and visual design land later — this is a functional skeleton that
/// exercises the whole pipeline (Vision OCR → backend parse → filterable list).
struct RootView: View {
    @Environment(ScanSession.self) private var session

    var body: some View {
        NavigationStack {
            if session.menu == nil {
                ScanView()
            } else {
                BrowseView()
            }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(ScanSession.previewLoaded)
}
