import SwiftUI
import PhotosUI
import MiseShared

/// The first screen, and home: point at the menu. Recent menus underneath
/// open without a connection.
struct CameraView: View {
    @Environment(AppModel.self) private var model
    @State private var camera = Camera()
    @State private var cameraLive = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPeople = false
    @State private var showingSettings = false
    @State private var shutter = 0

    var body: some View {
        GeometryReader { proxy in
            let full = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            VStack(spacing: 0) {
                viewfinder
                    .overlay(alignment: .bottom) { shutterButton.padding(.bottom, 70) }
                    .frame(height: full * 0.62)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34))
                recent
            }
            .background(Board.ground)
            .ignoresSafeArea()
            .overlay(alignment: .top) { topBar }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-demoViewfinder") { return }
            cameraLive = await camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await model.scan(imageData: data) }
                pickerItem = nil
            }
        }
        .sheet(isPresented: $showingPeople) { WhoIsEatingSheet() }
        .sheet(isPresented: $showingSettings) { SettingsSheet() }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutter)
    }

    // MARK: Viewfinder

    @ViewBuilder
    private var viewfinder: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x161C18)
            if let image = model.capturedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else if cameraLive {
                CameraPreview(session: camera.session)
            } else if ProcessInfo.processInfo.arguments.contains("-demoViewfinder") {
                DemoMenuPaper().padding(.top, 104)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                noCamera
            }
            LinearGradient(colors: [Color(hex: 0x0F1512, alpha: 0), Color(hex: 0x0F1512, alpha: 0.85)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .allowsHitTesting(false)
            status
                .padding(.bottom, 18)
        }
        .clipped()
    }

    private var noCamera: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera").font(.system(size: 28)).foregroundStyle(.white.opacity(0.6))
            Text("No camera here. Choose a photo of a menu.")
                .font(.boardSecondary).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var status: some View {
        VStack(spacing: 4) {
            switch model.phase {
            case .recognizing:
                Text("Hold still, reading the menu").font(.system(size: 17, weight: .semibold))
                Text("Finding the lines").font(.boardMeta).foregroundStyle(.white.opacity(0.7))
            case .parsing:
                Text("Reading the dishes").font(.system(size: 17, weight: .semibold))
                Text("Checking each one for your table").font(.boardMeta).foregroundStyle(.white.opacity(0.7))
            case .failed(let message):
                Text("Couldn't read that menu").font(.system(size: 17, weight: .semibold))
                Text(message).font(.boardMeta).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                Button("Retake") { withAnimation { model.retake() } }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 16).frame(height: 36)
                    .boardGlass(in: Capsule())
                    .padding(.top, 6)
            case .idle:
                if ProcessInfo.processInfo.arguments.contains("-demoViewfinder") {
                    Text("Hold still, reading the menu").font(.system(size: 17, weight: .semibold))
                    Text("7 dishes so far").font(.boardMeta).foregroundStyle(.white.opacity(0.7))
                } else {
                    Text(cameraLive ? "Point at the menu" : "").font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
    }

    private var shutterButton: some View {
        HStack(spacing: 28) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white).frame(width: 44, height: 44)
            }
            .boardGlass(in: Circle())
            .accessibilityLabel("Choose a photo")
            Button {
                shutter += 1
                Task {
                    if let data = await camera.capture() { await model.scan(imageData: data) }
                }
            } label: {
                Circle().fill(.white).frame(width: 64, height: 64)
                    .overlay { Circle().strokeBorder(Color(hex: 0x0F1512), lineWidth: 2).padding(5) }
                    .background { Circle().fill(.white.opacity(0.35)).padding(-4) }
            }
            .buttonStyle(PressStyle())
            .disabled(!cameraLive || model.isWorking)
            .accessibilityLabel("Read this menu")
            Color.clear.frame(width: 44, height: 44)
        }
        .opacity(model.isWorking ? 0.4 : 1)
    }

    private var topBar: some View {
        HStack {
            GlassCircleButton(systemImage: "gearshape", label: "Settings") { showingSettings = true }
            Spacer()
            GlassCapsuleButton(systemImage: "person.2",
                               title: model.profiles.isEmpty ? "Add who's eating" : "Who's eating · \(model.profiles.count)") {
                showingPeople = true
            }
        }
        .padding(.horizontal, 16)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Recent

    private var recent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent · open without a connection")
                .boardLabelStyle().foregroundStyle(Board.ink2)
            if model.recents.isEmpty {
                Text("Menus you read appear here and open offline.")
                    .font(.boardSecondary).foregroundStyle(Board.ink3)
                    .padding(.top, 6)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(model.recents.prefix(6).enumerated()), id: \.element.id) { index, menu in
                        if index > 0 { Rectangle().fill(Board.rule).frame(height: 1) }
                        Button {
                            withAnimation(.smooth) { model.open(menu) }
                        } label: {
                            recentRow(menu)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Board.margin)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Board.ground)
    }

    private func recentRow(_ menu: ParsedMenu) -> some View {
        HStack(spacing: 12) {
            if let first = menu.dishes.first(where: { $0.imageURL != nil }) ?? menu.dishes.first {
                DishPhoto(dish: first, plateScale: 0.9)
                    .frame(width: 64, height: 48)
                    .clipShape(.rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(menu.restaurantName ?? "A menu").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Board.ink)
                Text([menu.cuisine, "\(menu.dishes.count) dishes", menu.scannedAt.map(Self.when)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.boardMeta).foregroundStyle(Board.ink2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Board.ink3)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    /// "tonight", "last night", "Tuesday", "12 Oct".
    static func when(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return calendar.component(.hour, from: date) >= 17 ? "tonight" : "today" }
        if calendar.isDateInYesterday(date) { return "last night" }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// Only for `-demoViewfinder` screenshots in the simulator, which has no camera:
/// the paper menu from the mockup, with the lines Mise has found outlined.
struct DemoMenuPaper: View {
    private let lines = [("ส้มตำไทย", "70"), ("ต้มข่าไก่", "95"), ("ผัดไทยกุ้งสด", "120"), ("แกงเขียวหวานไก่", "110"),
                         ("ข้าวผัดสับปะรด", "130"), ("ผัดผักบุ้งไฟแดง", "60"), ("ไก่ทอดหาดใหญ่", "90")]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ครัวป้านิด").font(.system(size: 20, weight: .heavy)).padding(.bottom, 14)
            ForEach(lines, id: \.0) { line in
                HStack { Text(line.0); Spacer(); Text(line.1) }
                    .font(.system(size: 17))
                    .frame(height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Board.paint.opacity(0.10))
                            .strokeBorder(Board.paint.opacity(0.6), lineWidth: 1.5)
                            .padding(.horizontal, -6).padding(.vertical, 2)
                    }
            }
        }
        .foregroundStyle(Color(hex: 0x2A2A26))
        .padding(24)
        .frame(width: 330)
        .background(Color(hex: 0xF2EFE6), in: .rect(cornerRadius: 3))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
        .rotationEffect(.degrees(-4))
    }
}
