import SwiftUI
import MiseShared

/// The hero screen: the menu as a board of numbered photos, with a verdict
/// chalked on each for the selected person.
struct MenuBoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var path: NavigationPath

    /// The signature runs in three beats; each beat reads its own copy of the selection.
    @State private var strikeID: Profile.ID??
    @State private var reasonID: Profile.ID??
    @State private var sortID: Profile.ID??
    @State private var landed = 0
    @State private var choreography: Task<Void, Never>?

    @State private var sheet: Sheet?
    @State private var showingWaiter = false
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    @Namespace private var zoom

    enum Sheet: Identifiable {
        case picks, filters, people(Profile)
        var id: String {
            switch self {
            case .picks: "picks"
            case .filters: "filters"
            case .people(let p): "people-\(p.id)"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Board.ground.ignoresSafeArea()
            if let menu = model.menu {
                ScrollView {
                    content(menu)
                        .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .top, spacing: 8) { topBar }
            }
            BottomFade().ignoresSafeArea(edges: .bottom)
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Dish.ID.self) { id in
            if let dish = model.menu?.dishes.first(where: { $0.id == id }) {
                DishView(dish: dish, showPicks: { sheet = .picks })
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .picks:
                PicksSheet(showWaiter: { self.sheet = nil; showingWaiter = true })
            case .filters:
                FiltersSheet()
            case .people(let profile):
                PeopleSheet(profile: profile)
            }
        }
        .fullScreenCover(isPresented: $showingWaiter) { WaiterCardView(mode: .order) }
        .sensoryFeedback(.selection, trigger: model.selectedProfileID)
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        .onAppear { settle() }
        .task {
            // `-seedTapPerson els`: plays the chalk strike once, for recording the signature.
            guard let name = UserDefaults.standard.string(forKey: "seedTapPerson") else { return }
            try? await Task.sleep(for: .seconds(2))
            select(model.profiles.first { $0.name.lowercased() == name }?.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .seedScreen)) { note in
            switch note.object as? String {
            case "picks": sheet = .picks
            case "filters": sheet = .filters
            case "people": if let p = model.selectedProfile ?? model.profiles.first { sheet = .people(p) }
            case "waiter": showingWaiter = true
            default: break
            }
        }
        .onChange(of: model.profiles) { _, _ in settle() }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ menu: ParsedMenu) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(menu)
            peopleRow
                .padding(.top, 18)
            summaryBar
                .padding(.top, 14)
                .padding(.horizontal, Board.margin)
            if model.parserUsed == "heuristic" {
                strip(icon: "exclamationmark.triangle",
                      "Basic parse only: allergens and translations may be wrong. Rescan to retry.")
            }
            if model.imagePhase == .slow || model.imagePhase == .failed {
                strip(icon: "cellularbars", "Weak signal. Photos will fill in; the verdicts are ready.")
            }
            grid(menu)
                .padding(.top, 4)
                .padding(.horizontal, Board.margin)
        }
    }

    private func header(_ menu: ParsedMenu) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow(menu))
                .font(.system(size: 13, weight: .medium)).tracking(0.2)
                .foregroundStyle(Board.ink2)
                .lineLimit(1)
            Text(menu.restaurantName ?? "The menu")
                .font(.boardDisplay)
                .boardCaps(tracking: -0.5)
                .foregroundStyle(Board.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Board.margin)
    }

    private func eyebrow(_ menu: ParsedMenu) -> String {
        var parts: [String] = []
        if let original = menu.originalRestaurantName { parts.append(original) } else if let place = menu.place { parts.append(place) }
        if let cuisine = menu.cuisine { parts.append(cuisine) }
        parts.append("\(menu.dishes.count) dishes")
        if menu.isNonLatinScript, menu.dishes.contains(where: { $0.menuNumber != nil }) { parts.append("order by number") }
        return parts.joined(separator: " · ")
    }

    private var peopleRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if model.profiles.count > 1 || model.profiles.isEmpty {
                    PersonChip(title: "Everyone", isOn: model.selectedProfileID == nil) { select(nil) }
                }
                ForEach(model.profiles) { profile in
                    PersonChip(title: profile.name, isOn: model.selectedProfileID == profile.id) { select(profile.id) }
                        .contextMenu {
                            Button("Edit \(profile.name)", systemImage: "pencil") { sheet = .people(profile) }
                        }
                }
                PersonChip(title: model.profiles.isEmpty ? "Add who's eating" : "+", isOn: false, dashed: true) {
                    sheet = .people(Profile(name: ""))
                }
                .accessibilityLabel("Add a person")
                if !model.filter.requiredTags.isEmpty {
                    filterPill
                }
            }
            .padding(.horizontal, Board.margin)
        }
        .scrollIndicators(.hidden)
    }

    /// "Vegetarian tonight ×": a dark pill, so cream fill keeps meaning "selected person".
    private var filterPill: some View {
        let names = model.filter.requiredTags.map(\.displayName).sorted().joined(separator: ", ")
        return Button {
            withAnimation(.smooth) { model.filter.requiredTags = [] }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 13, weight: .semibold))
                Text("\(names) tonight").font(.system(size: 13, weight: .semibold))
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Board.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color(hex: 0x0A3D28), in: Capsule())
            .overlay { Capsule().strokeBorder(Board.ink.opacity(0.45), lineWidth: 1) }
        }
        .buttonStyle(PressStyle())
        .padding(.leading, 4)
        .accessibilityLabel("Remove \(names) filter")
    }

    // MARK: Summary bar

    private var summaryBar: some View {
        let profile = profile(for: sortID)
        let s = model.summary(for: profile)
        let filtered = model.filter.isActive
        let verdicts = profile != nil || filtered
        let who = profile.map { "fine for \($0.name)" } ?? "fine"
        // One structure for both states, so the fine segment stays put and its count rolls
        // while ask and no slide in beside it.
        return HStack(spacing: 4) {
            segment(count: verdicts ? s.fine : s.total,
                    label: verdicts ? (filtered ? "\(who) tonight" : who) : "dishes · add a person to see what they can eat",
                    color: Board.ink, border: Board.rule, kind: verdicts ? .fine : nil)
            if verdicts {
                Group {
                    segment(count: s.ask, label: "ask", color: s.ask == 0 ? Board.ink3 : Board.ask,
                            border: s.ask == 0 ? Board.rule : Board.ask, kind: .ask)
                    segment(count: s.no, label: noLabel(profile: profile), color: Board.no, border: Board.no, kind: .no)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .clipped()
        .frame(height: 38)
    }

    private func noLabel(profile: Profile?) -> String {
        let onlyVegetarian = model.filter.requiredTags == [.vegetarian]
        guard onlyVegetarian else { return "no" }
        let noCauses = model.visibleDishes.map { model.verdict(for: $0, profile: profile) }.filter { $0.kind == .no }
        return noCauses.allSatisfy { $0.cause == .filter } ? "not veg." : "no"
    }

    private func segment(count: Int, label: String, color: Color, border: Color, kind: Verdict.Kind?) -> some View {
        let focused = kind != nil && model.verdictFocus == kind
        return Button {
            guard let kind else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0)) {
                model.verdictFocus = model.verdictFocus == kind ? nil : kind
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(count)")
                    .font(.boardHeavy(20, relativeTo: .title3))
                    .contentTransition(.numericText(value: Double(count)))
                Text(label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    .id(label)
                    .transition(.opacity.animation(.easeOut(duration: 0.12)))
            }
            .foregroundStyle(focused ? Board.ground : color)
            .padding(.horizontal, 12)
            .frame(maxWidth: kind == .fine || kind == nil ? .infinity : nil, maxHeight: .infinity, alignment: .leading)
            .background(focused ? color : .clear, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: 1.5) }
            .contentShape(.rect)
        }
        .buttonStyle(PressStyle())
        // Ask and no keep their size; the long fine label is the one that gives.
        .fixedSize(horizontal: kind == .ask || kind == .no, vertical: false)
        .layoutPriority(kind == .ask || kind == .no ? 1 : 0)
        .accessibilityLabel("\(count) \(label)")
        .accessibilityHint(kind == nil ? "" : "Shows only these dishes")
    }

    private func strip(icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Board.paint)
            Text(text).font(.boardSecondary).tracking(-0.2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Board.onRaised)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Board.raised, in: .rect(cornerRadius: 10))
        .padding(.horizontal, Board.margin)
        .padding(.top, 12)
    }

    // MARK: Grid

    private func grid(_ menu: ParsedMenu) -> some View {
        let strikeProfile = profile(for: strikeID)
        let reasonProfile = profile(for: reasonID)
        let sortProfile = profile(for: sortID)
        let sorted = sortProfile != nil || model.filter.isActive
        let sections = model.sections(sortingFor: sortProfile, sorted: sorted)
        let latin = !menu.isNonLatinScript
        let columns = [GridItem(.flexible(), spacing: Board.gutter, alignment: .top),
                       GridItem(.flexible(), spacing: Board.gutter, alignment: .top)]
        return LazyVStack(alignment: .leading, spacing: 0) {
            if sections.isEmpty {
                emptyState
            }
            ForEach(Array(sections.enumerated()), id: \.element.title) { index, section in
                HStack(spacing: 12) {
                    Text(section.title).boardLabelStyle().foregroundStyle(Board.ink2)
                    Rectangle().fill(Board.rule).frame(height: 1)
                }
                .padding(.top, index == 0 ? 10 : 20)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(section.dishes) { dish in
                        Button {
                            path.append(dish.id)
                        } label: {
                            DishTile(
                                dish: dish,
                                strike: model.verdict(for: dish, profile: strikeProfile),
                                reason: model.verdict(for: dish, profile: reasonProfile),
                                chip: chip(for: dish),
                                titleInOriginal: latin && dish.originalName != nil,
                                showsDescription: !latin)
                        }
                        .buttonStyle(PressStyle())
                        .matchedTransitionSource(id: dish.id, in: zoom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing left on the board").font(.boardName).boardCaps().foregroundStyle(Board.ink)
            Text("Every dish is crossed out or switched off.").font(.boardSecondary).foregroundStyle(Board.ink2)
            HStack {
                if model.hideCrossed {
                    Button("Show crossed-out") { withAnimation { model.hideCrossed = false } }
                }
                Button("Clear filters") {
                    withAnimation {
                        model.filter = DishFilter(); model.hiddenSections = []; model.verdictFocus = nil
                        model.searchText = ""
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(Board.ink)
        }
        .padding(.top, 24)
    }

    func chip(for dish: Dish) -> String {
        let price = dish.price.map { model.price($0, currency: dish.currency) }
        return [dish.menuNumber, price].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            GlassCircleButton(systemImage: "camera", label: "Scan another menu") {
                withAnimation(.smooth) { model.closeMenu() }
            }
            Spacer()
            GlassCapsuleButton(systemImage: "bookmark",
                               title: model.pickCount > 0 ? "Picks · \(model.pickCount)" : "Picks") {
                sheet = .picks
            }
        }
        .padding(.horizontal, 16)
        .background(alignment: .top) {
            LinearGradient(colors: [Board.ground, Board.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private var bottomBar: some View {
        @Bindable var model = model
        return HStack(spacing: 10) {
            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Say or type a dish", text: $model.searchText)
                        .focused($searchFocused)
                        .submitLabel(.search)
                }
                .font(.system(size: 17))
                .foregroundStyle(Board.ground)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Board.ink, in: Capsule())
                GlassCircleButton(systemImage: "xmark", label: "Close search", size: 56) {
                    withAnimation(.snappy) { searching = false; model.searchText = "" }
                }
            } else {
                BoardCTA(title: filtersTitle, systemImage: "line.3.horizontal") { sheet = .filters }
                GlassCircleButton(systemImage: "mic", label: "Find a dish by voice or text", size: 56) {
                    withAnimation(.snappy) { searching = true }
                    searchFocused = true
                }
            }
        }
        .padding(.horizontal, Board.margin)
        .padding(.bottom, 8)
    }

    private var filtersTitle: String {
        let f = model.filter
        let n = f.requiredTags.count + (f.maxSpice == nil ? 0 : 1) + (f.maxPrice == nil ? 0 : 1)
            + f.avoidedIngredients.count + model.hiddenSections.count + (model.hideCrossed ? 1 : 0)
        return n == 0 ? "Filters" : "Filters · \(n)"
    }

    // MARK: The chalk strike

    private func profile(for id: Profile.ID??) -> Profile? {
        guard let id, let id else { return nil }
        return model.profiles.first { $0.id == id }
    }

    /// Brings every beat to the current selection at once (first appearance, profile edits).
    private func settle() {
        strikeID = model.selectedProfileID
        reasonID = model.selectedProfileID
        sortID = model.selectedProfileID
    }

    /// Tap a person: chip fills (0 ms) → lines draw and photos dim (0–260 ms) →
    /// haptic as they land, reasons fade in (260–400 ms) → crossed tiles sink and
    /// the counts roll (300–700 ms). Reduced motion: one 200 ms cross-fade.
    private func select(_ id: Profile.ID?) {
        guard model.selectedProfileID != id || strikeID != id else { return }
        choreography?.cancel()
        withAnimation(.snappy(duration: 0.2)) {
            model.selectedProfileID = id
            model.verdictFocus = nil
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                strikeID = id
                reasonID = id
            }
            sortID = id
            landed += 1
            return
        }
        choreography = Task { @MainActor in
            withAnimation(.smooth(duration: 0.26)) { strikeID = id }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            landed += 1
            withAnimation(.easeOut(duration: 0.14)) { reasonID = id }
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0)) { sortID = id }
        }
    }
}
