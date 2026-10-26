import SwiftUI
import Observation
import MiseShared

/// Everything the app knows: the people at the table, the menu being read,
/// tonight's filters, the picks, and the recent menus kept for offline use.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case recognizing
        case parsing
        case failed(String)
    }

    enum ImagePhase: Equatable {
        case idle, loading, slow, failed, done
    }

    struct PickLine: Identifiable, Hashable, Codable {
        var dishID: Dish.ID
        var quantity: Int
        var id: Dish.ID { dishID }
    }

    // MARK: State

    var phase: Phase = .idle
    /// The photo being read, shown in the viewfinder while the parse runs.
    var capturedImage: UIImage?
    var menu: ParsedMenu?
    var parserUsed: String?
    var imagePhase: ImagePhase = .idle

    var profiles: [Profile] = [] { didSet { store.saveProfiles(profiles) } }
    /// `nil` is "Everyone".
    var selectedProfileID: Profile.ID?

    /// Tonight's mood, on top of each person's profile.
    var filter = DishFilter()
    /// Menu sections switched off in Filters.
    var hiddenSections: Set<String> = []
    var hideCrossed = false
    /// Tapping a summary segment shows only that group.
    var verdictFocus: Verdict.Kind?
    /// Typed or dictated from the microphone button: narrows the grid, crosses nothing.
    var searchText = ""

    var picks: [PickLine] = []
    var recents: [ParsedMenu] = []
    /// The diner's own photos of dishes they had, kept on the device.
    var myPhotos: [MyDishPhoto] = [] { didSet { store.saveMyPhotos(myPhotos) } }
    var homeCurrency: String = Locale.current.currency?.identifier ?? "EUR"

    private let recognizer: VisionTextRecognizer
    private let api: APIClient
    private let store: LocalStore

    init(recognizer: VisionTextRecognizer = VisionTextRecognizer(),
         api: APIClient = APIClient(),
         store: LocalStore = LocalStore()) {
        self.recognizer = recognizer
        self.api = api
        self.store = store
        profiles = store.loadProfiles()
        recents = store.loadRecents()
        myPhotos = store.loadMyPhotos()
    }

    var isWorking: Bool { phase == .recognizing || phase == .parsing }

    var selectedProfile: Profile? {
        selectedProfileID.flatMap { id in profiles.first { $0.id == id } }
    }

    // MARK: Scan

    /// Runs OCR on the photo, then asks the backend to structure it.
    func scan(imageData: Data) async {
        capturedImage = UIImage(data: imageData)
        phase = .recognizing
        do {
            let text = try await recognizer.recognizeText(in: imageData)
            phase = .parsing
            let response = try await api.parseMenu(text: text)
            var parsed = response.menu
            parsed.scannedAt = .now
            parserUsed = response.parser
            open(parsed)
            phase = .idle
            capturedImage = nil
            await enrich()
        } catch {
            ErrorReporting.capture(error)
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows a menu (fresh or from Recent) and resets the per-menu state.
    func open(_ parsed: ParsedMenu) {
        menu = parsed
        picks = []
        filter = DishFilter()
        hiddenSections = []
        verdictFocus = nil
        searchText = ""
        imagePhase = parsed.dishes.contains { $0.imageURL != nil } ? .done : .idle
        remember(parsed)
    }

    /// Back to the camera.
    func closeMenu() {
        menu = nil
        parserUsed = nil
        picks = []
        phase = .idle
        capturedImage = nil
    }

    func retake() {
        phase = .idle
        capturedImage = nil
    }

    private func remember(_ parsed: ParsedMenu) {
        recents.removeAll { $0.id == parsed.id }
        recents.insert(parsed, at: 0)
        recents = Array(recents.prefix(10))
        store.saveRecents(recents)
    }

    // MARK: Enrichment (photos, exchange rate)

    /// Fetches photos for the menu's dishes and the exchange rate, in parallel.
    /// Verdicts never wait for this: tiles show their drawn plates until photos land.
    func enrich() async {
        guard let current = menu else { return }
        async let rate: Void = loadRate(for: current)
        await loadImages(for: current)
        await rate
    }

    /// Dishes per photo request: small, so photos land a batch at a time.
    static let imageBatch = 8

    private func loadImages(for current: ParsedMenu) async {
        let missing = current.dishes.filter { $0.imageURL == nil }
        guard !missing.isEmpty else { imagePhase = .done; return }
        imagePhase = .loading
        // After three seconds without photos, say so: the verdicts are ready anyway.
        let slowTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled, self?.imagePhase == .loading { self?.imagePhase = .slow }
        }
        defer { slowTimer.cancel() }
        var queries = missing.map {
            DishImageQuery(id: $0.id, name: $0.name, originalName: $0.originalName, cuisine: current.cuisine,
                           kind: $0.kind, section: $0.section)
        }
        var answered = false
        // A dish the server could not look up this time (a source was rate-limited
        // or slow) gets one more try once the rest have landed.
        for round in 0..<2 {
            var retry: [DishImageQuery] = []
            for start in stride(from: 0, to: queries.count, by: Self.imageBatch) {
                let batch = Array(queries[start..<min(start + Self.imageBatch, queries.count)])
                guard let results = try? await api.dishImages(batch) else {
                    retry += batch
                    continue
                }
                guard menu?.id == current.id else { return }
                answered = true
                // Photos are arriving, so the weak-signal strip has nothing to say.
                if imagePhase == .slow { imagePhase = .loading }
                for result in results {
                    if result.retry { retry += batch.filter { $0.id == result.id } }
                    guard let image = result.image,
                          let index = menu?.dishes.firstIndex(where: { $0.id == result.id }) else { continue }
                    menu?.dishes[index].imageURL = image.url
                    menu?.dishes[index].imageCredit = image.credit
                }
            }
            if let menu, menu.id == current.id { remember(menu) }
            guard round == 0, !retry.isEmpty else { break }
            queries = retry
            try? await Task.sleep(for: .seconds(20))
            guard menu?.id == current.id else { return }
        }
        imagePhase = answered ? .done : .failed
    }

    private func loadRate(for current: ParsedMenu) async {
        guard current.exchange == nil, let currency = current.currency, currency != homeCurrency,
              let rate = try? await api.exchangeRate(from: homeCurrency, to: currency),
              menu?.id == current.id else { return }
        menu?.exchange = rate
        if let menu { remember(menu) }
    }

    // MARK: Verdicts

    func verdict(for dish: Dish, profile: Profile?) -> Verdict {
        Verdict.for(dish, profile: profile, filter: filter)
    }

    struct Summary: Equatable {
        var fine = 0, ask = 0, no = 0
        var total: Int { fine + ask + no }
    }

    func summary(for profile: Profile?) -> Summary {
        var s = Summary()
        for dish in visibleDishes {
            switch verdict(for: dish, profile: profile).kind {
            case .fine: s.fine += 1
            case .ask: s.ask += 1
            case .no: s.no += 1
            }
        }
        return s
    }

    /// Dishes in sections that are switched on.
    var visibleDishes: [Dish] {
        (menu?.dishes ?? []).filter { !hiddenSections.contains($0.sectionTitle) }
    }

    /// Sections for the grid. With a person (or a filter) selected, crossed
    /// dishes sink to the end of their course; "ask" sits between.
    func sections(sortingFor profile: Profile?, sorted: Bool) -> [(title: String, dishes: [Dish])] {
        guard let menu else { return [] }
        return menu.sections.compactMap { section in
            guard !hiddenSections.contains(section.title) else { return nil }
            var dishes = section.dishes
            if sorted {
                // Stable sort by verdict.
                dishes = dishes.enumerated().sorted { a, b in
                    let ka = verdict(for: a.element, profile: profile).kind
                    let kb = verdict(for: b.element, profile: profile).kind
                    return ka == kb ? a.offset < b.offset : ka < kb
                }.map(\.element)
            }
            if hideCrossed {
                dishes = dishes.filter { verdict(for: $0, profile: profile).kind != .no }
            }
            let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                dishes = dishes.filter { dish in
                    ([dish.name, dish.originalName ?? "", dish.description ?? "", dish.menuNumber ?? ""] + dish.ingredients)
                        .contains { $0.lowercased().contains(query) }
                }
            }
            if let verdictFocus {
                dishes = dishes.filter { verdict(for: $0, profile: profile).kind == verdictFocus }
            }
            if sorted, !filter.preferredIngredients.isEmpty {
                // Within each verdict, dishes with everything wanted come first.
                dishes = dishes.enumerated().sorted { a, b in
                    let ka = verdict(for: a.element, profile: profile).kind
                    let kb = verdict(for: b.element, profile: profile).kind
                    guard ka == kb else { return ka < kb }
                    let ma = filter.missingWanted(in: a.element).count
                    let mb = filter.missingWanted(in: b.element).count
                    return ma == mb ? a.offset < b.offset : ma < mb
                }.map(\.element)
            }
            return dishes.isEmpty ? nil : (section.title, dishes)
        }
    }

    // MARK: Filters from a sentence

    /// The ingredients and families on the sections that are switched on.
    var ingredientIndex: IngredientIndex { IngredientIndex(dishes: visibleDishes) }

    /// Reads "only pizzas with mozzarella, no mushrooms" into tonight's filters.
    /// Returns `false` when the sentence is not a filter, so the caller keeps it as a search.
    @discardableResult
    func interpret(_ text: String) async -> Bool {
        guard let current = menu else { return false }
        let sections = current.sections.map(\.title)
        let ingredients = IngredientIndex(dishes: current.dishes).ingredients.map(\.key.name)
        let request = InterpretFiltersRequest(text: text, sections: sections, ingredients: ingredients)
        let intent: FilterIntent
        if let remote = try? await api.interpretFilters(request) {
            intent = remote
        } else {
            intent = FilterIntentParser.parse(text, sections: sections, ingredients: ingredients)
        }
        guard menu?.id == current.id, !intent.isEmpty else { return false }
        apply(intent)
        return true
    }

    func apply(_ intent: FilterIntent) {
        intent.apply(to: &filter, hiddenSections: &hiddenSections, allSections: menu?.sections.map(\.title) ?? [])
        verdictFocus = nil
    }

    /// Neutral → want → avoid → neutral, for an "On this menu" chip.
    func cycle(_ item: String) {
        if filter.preferredIngredients.contains(item) {
            filter.preferredIngredients.remove(item)
            filter.avoidedIngredients.insert(item)
        } else if filter.avoidedIngredients.contains(item) {
            filter.avoidedIngredients.remove(item)
        } else {
            filter.preferredIngredients.insert(item)
        }
    }

    /// Switches every section off but `title`.
    func showOnly(_ title: String) {
        hiddenSections = Set((menu?.sections.map(\.title) ?? []).filter { $0 != title })
    }

    // MARK: My photos

    /// The menu `dish` belongs to: the open one, else a recent one.
    private func menu(containing dish: Dish) -> ParsedMenu? {
        if let menu, menu.dishes.contains(where: { $0.id == dish.id }) { return menu }
        return recents.first { $0.dishes.contains { $0.id == dish.id } }
    }

    /// The diner's own photo of `dish`, the newest when there are several:
    /// from this menu, or from an earlier visit to the same restaurant.
    func myPhoto(for dish: Dish) -> MyDishPhoto? {
        guard let menu = menu(containing: dish) else { return nil }
        return myPhotos.filter { $0.matches(dish, in: menu) }.max { $0.takenAt < $1.takenAt }
    }

    func url(for photo: MyDishPhoto) -> URL? { store.photoURL(photo.file) }

    /// Saves a photo of `dish` (camera or library), replacing an earlier one for it.
    @discardableResult
    func saveMyPhoto(_ data: Data, for dish: Dish) async -> Bool {
        guard let menu = menu(containing: dish) else { return false }
        let store = self.store
        let file = await Task.detached(priority: .userInitiated) { () -> String? in
            MyDishPhoto.prepare(data).flatMap(store.writePhoto)
        }.value
        guard let file else { return false }
        removeMyPhoto(for: dish)
        myPhotos.append(MyDishPhoto(restaurant: MyDishPhoto.restaurantKey(for: menu), dish: MyDishPhoto.dishKey(for: dish),
                                    menuID: menu.id, file: file, takenAt: .now))
        return true
    }

    func removeMyPhoto(for dish: Dish) {
        guard let menu = menu(containing: dish) else { return }
        for photo in myPhotos where photo.matches(dish, in: menu) { store.deletePhoto(photo.file) }
        myPhotos.removeAll { $0.matches(dish, in: menu) }
    }

    // MARK: Profiles

    func upsert(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    func delete(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id { selectedProfileID = nil }
    }

    // MARK: Picks

    func quantity(of dish: Dish) -> Int {
        picks.first { $0.dishID == dish.id }?.quantity ?? 0
    }

    func add(_ dish: Dish) {
        if let index = picks.firstIndex(where: { $0.dishID == dish.id }) {
            picks[index].quantity += 1
        } else {
            picks.append(PickLine(dishID: dish.id, quantity: 1))
        }
    }

    func decrement(_ dish: Dish) {
        guard let index = picks.firstIndex(where: { $0.dishID == dish.id }) else { return }
        if picks[index].quantity > 1 { picks[index].quantity -= 1 } else { picks.remove(at: index) }
    }

    func remove(_ dishID: Dish.ID) {
        picks.removeAll { $0.dishID == dishID }
    }

    var pickCount: Int { picks.reduce(0) { $0 + $1.quantity } }

    /// Picked dishes with quantities, in the order they were added.
    var pickedDishes: [(dish: Dish, quantity: Int)] {
        guard let menu else { return [] }
        return picks.compactMap { line in
            menu.dishes.first { $0.id == line.dishID }.map { ($0, line.quantity) }
        }
    }

    var picksTotal: Decimal? {
        let lines = pickedDishes
        guard !lines.isEmpty, lines.allSatisfy({ $0.dish.price != nil }) else { return nil }
        return lines.reduce(Decimal(0)) { $0 + ($1.dish.price ?? 0) * Decimal($1.quantity) }
    }

    // MARK: Money

    /// "฿95" in the menu's currency.
    func price(_ amount: Decimal, currency: String? = nil) -> String {
        Money.format(amount, currency: currency ?? menu?.currency ?? homeCurrency)
    }

    /// "€2.55" in the home currency, when the menu is in another one.
    func homePrice(_ amount: Decimal) -> String? {
        guard let exchange = menu?.exchange, exchange.home != menu?.currency else { return nil }
        return Money.format(exchange.convert(amount), currency: exchange.home, fractionDigits: 2)
    }

    // MARK: Phrases

    /// The waiter-card words for `profile` (or the whole table) in the menu's language.
    func phrases(for profile: Profile?) -> PhraseSet {
        let language = menu?.sourceLanguage ?? "en"
        let severe = profile.map { $0.severe ? [$0] : [] } ?? profiles.filter(\.severe)
        let allergens = severe.reduce(into: Set<Allergen>()) { $0.formUnion($1.allergens) }
        let speech = profile?.speech ?? .neutral
        return PhraseBook.phrases(language: language, allergens: allergens, speech: speech)
            ?? PhraseBook.phrases(language: "en", allergens: allergens, speech: speech)!
    }
}

enum Money {
    static func format(_ amount: Decimal, currency: String, fractionDigits: Int? = nil) -> String {
        let symbol: String
        switch currency {
        case "THB": symbol = "฿"
        case "EUR": symbol = "€"
        case "USD": symbol = "$"
        case "GBP": symbol = "£"
        default: symbol = currency + " "
        }
        let whole = amount == amount.rounded(0)
        let digits = fractionDigits ?? (whole ? 0 : 2)
        let number = (amount as NSDecimalNumber).doubleValue
        return symbol + number.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic))
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var value = self, result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
