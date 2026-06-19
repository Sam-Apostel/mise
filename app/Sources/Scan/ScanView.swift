import SwiftUI
import PhotosUI

/// Frames 01–02 — Capture & Reading. Pick (or shoot) a menu photo, then OCR + parse.
struct ScanView: View {
    @Environment(ScanSession.self) private var session
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            captureFrame

            VStack(spacing: 8) {
                Text("Point at any menu")
                    .font(.serifTitle(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Snap or choose a photo of a menu and Menu Copilot turns it into a filterable list of dishes — with rich filters and images.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            statusView

            Spacer()

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label("Snap a menu", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent, in: .rect(cornerRadius: Theme.Metrics.corner))
            }
            .disabled(session.isWorking)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Theme.page)
        .navigationTitle("Menu Copilot")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await session.scan(imageData: data)
                }
                pickerItem = nil
            }
        }
    }

    /// The dashed capture viewfinder with corner brackets (frame 01).
    private var captureFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.topBar)
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .padding(20)
            Image(systemName: "text.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: 220, height: 280)
    }

    @ViewBuilder
    private var statusView: some View {
        switch session.phase {
        case .recognizing:
            ProgressView("Reading the menu…").tint(Theme.accent)
        case .parsing:
            ProgressView("Finding the dishes…").tint(Theme.accent)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Theme.alert)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        case .idle:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack { ScanView() }
        .environment(ScanSession())
}
