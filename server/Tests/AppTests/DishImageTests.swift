import Foundation
import VaporTesting
import Testing
import MiseShared
@testable import App

/// A provider that answers from a table and records every search, so the chain
/// can be tested without network.
final class FakeImageProvider: ImageProvider, @unchecked Sendable {
    enum Failure { case none, error, rateLimited(Duration?) }

    let name: String
    let source: DishImage.Source
    let maxConcurrent: Int
    let termsFor: @Sendable (DishImageQuery) -> [String]
    let hits: Set<String>
    let failure: Failure
    let delay: Duration
    private let lock = NSLock()
    private var _calls: [String] = []
    private var running = 0
    private var _peak = 0

    init(_ name: String, source: DishImage.Source, hits: Set<String> = [], fails: Bool = false,
         failure: Failure? = nil, maxConcurrent: Int = 8, delay: Duration = .zero,
         terms: @escaping @Sendable (DishImageQuery) -> [String]) {
        self.name = name
        self.source = source
        self.hits = hits
        self.failure = failure ?? (fails ? .error : .none)
        self.maxConcurrent = maxConcurrent
        self.delay = delay
        self.termsFor = terms
    }

    var calls: [String] { lock.withLock { _calls } }
    /// The most searches that were ever in flight at once.
    var peak: Int { lock.withLock { _peak } }

    func terms(for dish: DishImageQuery) -> [String] { termsFor(dish) }

    func search(term: String, dish: DishImageQuery, client: any Client, logger: Logger) async throws -> DishImage? {
        lock.withLock { _calls.append(term); running += 1; _peak = max(_peak, running) }
        if delay > .zero { try? await Task.sleep(for: delay) }
        lock.withLock { running -= 1 }
        switch failure {
        case .none: break
        case .error: throw Abort(.badGateway)
        case .rateLimited(let wait): throw ImageProviderRateLimited(provider: name, retryAfter: wait)
        }
        guard hits.contains(term) else { return nil }
        let slug = term.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "x"
        return DishImage(url: URL(string: "https://img.test/\(name)/\(slug)")!, credit: "Photo: \(name)", source: source)
    }
}

@Suite("Dish images")
struct DishImageTests {
    let dish = DishImageQuery(id: UUID(), name: "Green curry", originalName: "แกงเขียวหวาน", cuisine: "Thai")

    func chain(commonsHits: Set<String> = [], pexelsHits: Set<String> = [], pixabayHits: Set<String> = [],
               pexelsFails: Bool = false)
        -> (DishImageService, FakeImageProvider, FakeImageProvider, FakeImageProvider) {
        let commons = FakeImageProvider("commons", source: .commons, hits: commonsHits) { d in
            [d.originalName, d.name].compactMap { $0 }
        }
        let pexels = FakeImageProvider("pexels", source: .pexels, hits: pexelsHits, fails: pexelsFails) { d in
            ["\(d.name) \(d.cuisine ?? "") food"]
        }
        let pixabay = FakeImageProvider("pixabay", source: .pixabay, hits: pixabayHits) { d in
            ["\(d.name) \(d.cuisine ?? "")"]
        }
        return (DishImageService(providers: [commons, pexels, pixabay]), commons, pexels, pixabay)
    }

    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("Commons original-name hit wins")
    func originalNameWins() async throws {
        try await withApp { app in
            let (service, commons, pexels, _) = chain(commonsHits: ["แกงเขียวหวาน", "Green curry"],
                                                      pexelsHits: ["Green curry Thai food"])
            let image = await service.image(for: dish, client: app.client, logger: app.logger)
            #expect(image?.source == .commons)
            #expect(image?.url.absoluteString.contains("commons") == true)
            #expect(commons.calls == ["แกงเขียวหวาน"])
            #expect(pexels.calls.isEmpty)
        }
    }

    @Test("Falls through Commons English name, then Pexels, then Pixabay, then nil")
    func fallsThrough() async throws {
        try await withApp { app in
            var (service, commons, pexels, pixabay) = chain(commonsHits: ["Green curry"])
            var image = await service.image(for: dish, client: app.client, logger: app.logger)
            #expect(image?.source == .commons)
            #expect(commons.calls == ["แกงเขียวหวาน", "Green curry"])
            #expect(pexels.calls.isEmpty)

            (service, commons, pexels, pixabay) = chain(pexelsHits: ["Green curry Thai food"])
            image = await service.image(for: dish, client: app.client, logger: app.logger)
            #expect(image?.source == .pexels)
            #expect(image?.credit == "Photo: pexels")
            #expect(pixabay.calls.isEmpty)

            // A provider error is a miss for that tier only.
            (service, commons, pexels, pixabay) = chain(pixabayHits: ["Green curry Thai"], pexelsFails: true)
            image = await service.image(for: dish, client: app.client, logger: app.logger)
            #expect(image?.source == .pixabay)
            #expect(pexels.calls.count == 1)

            (service, commons, pexels, pixabay) = chain()
            image = await service.image(for: dish, client: app.client, logger: app.logger)
            #expect(image == nil)
            #expect(commons.calls.count == 2 && pexels.calls.count == 1 && pixabay.calls.count == 1)
        }
    }

    @Test("Cache: a second lookup (hit or miss) does not hit providers")
    func cache() async throws {
        try await withApp { app in
            let (service, commons, pexels, pixabay) = chain(pexelsHits: ["Green curry Thai food"])
            let other = DishImageQuery(id: UUID(), name: "Mystery dish", cuisine: "Thai")
            let first = await service.images(for: [dish, other], client: app.client, logger: app.logger)
            let before = (commons.calls.count, pexels.calls.count, pixabay.calls.count)
            // Same name and cuisine, different id and case: served from cache.
            let again = DishImageQuery(id: UUID(), name: "GREEN CURRY", originalName: "แกงเขียวหวาน", cuisine: "thai")
            let second = await service.images(for: [again, other], client: app.client, logger: app.logger)
            #expect((commons.calls.count, pexels.calls.count, pixabay.calls.count) == before)
            #expect(first[0].image == second[0].image)
            #expect(second[0].id == again.id)
            #expect(second[1].image == nil)
        }
    }

    @Test("Misses expire after the TTL; hits do not")
    func missTTL() async throws {
        let clock = Clock()
        let cache = DishImageCache(missTTL: 100, now: { clock.now })
        let calls = Counter()
        _ = await cache.value(for: "k") { calls.bump(); return .miss }
        _ = await cache.value(for: "k") { calls.bump(); return .miss }
        #expect(calls.value == 1)
        clock.now = clock.now.addingTimeInterval(101)
        _ = await cache.value(for: "k") { calls.bump(); return .miss }
        #expect(calls.value == 2)
    }

    @Test("A failed or rate-limited lookup is never cached")
    func unavailableNotCached() async {
        let cache = DishImageCache()
        let calls = Counter()
        _ = await cache.value(for: "k") { calls.bump(); return .unavailable }
        _ = await cache.value(for: "k") { calls.bump(); return .unavailable }
        #expect(calls.value == 2)
        #expect(await cache.count == 0)
    }

    @Test("A 429 is not a miss: the dish comes back retry, Commons cools down, Pexels takes over")
    func rateLimited() async throws {
        try await withApp { app in
            let commons = FakeImageProvider("commons", source: .commons, failure: .rateLimited(.seconds(60)),
                                            maxConcurrent: 1) { [$0.name] }
            let pexels = FakeImageProvider("pexels", source: .pexels, hits: ["Calzone food"]) { ["\($0.name) food"] }
            let service = DishImageService(providers: [commons, pexels], concurrency: 1)
            let dishes = [DishImageQuery(id: UUID(), name: "Corvo"), DishImageQuery(id: UUID(), name: "Calzone")]
            let results = await service.images(for: dishes, client: app.client, logger: app.logger)
            #expect(results[0].image == nil && results[0].retry)
            #expect(results[1].image?.source == .pexels && !results[1].retry)
            // The 429 stopped Commons for everyone: the second dish never asked it.
            #expect(commons.calls == ["Corvo"])
            #expect(await service.cache.count == 1)

            // Asked again, Corvo is looked up again rather than served a cached miss.
            _ = await service.images(for: [dishes[0]], client: app.client, logger: app.logger)
            #expect(pexels.calls.filter { $0 == "Corvo food" }.count == 2)
        }
    }

    @Test("Commons runs one search at a time, however many dishes are in flight")
    func commonsSerial() async throws {
        try await withApp { app in
            let commons = FakeImageProvider("commons", source: .commons, maxConcurrent: 1,
                                            delay: .milliseconds(20)) { [$0.name] }
            let service = DishImageService(providers: [commons], concurrency: 4)
            let dishes = (0..<8).map { DishImageQuery(id: UUID(), name: "Dish \($0)") }
            let results = await service.images(for: dishes, client: app.client, logger: app.logger)
            #expect(commons.calls.count == 8)
            #expect(commons.peak == 1)
            #expect(results.allSatisfy { $0.image == nil && !$0.retry })
        }
    }

    @Test("Dishes not reached within the request's budget come back retry")
    func budget() async throws {
        try await withApp { app in
            let commons = FakeImageProvider("commons", source: .commons, maxConcurrent: 1,
                                            delay: .milliseconds(150)) { [$0.name] }
            let service = DishImageService(providers: [commons], concurrency: 4, budget: .milliseconds(250))
            let dishes = (0..<6).map { DishImageQuery(id: UUID(), name: "Dish \($0)") }
            let results = await service.images(for: dishes, client: app.client, logger: app.logger)
            #expect(results.contains { $0.retry })
            #expect(commons.calls.count < 6)
        }
    }

    @Test("Commons searches with the kind of dish, once per spelling")
    func commonsTerms() {
        let allegra = DishImageQuery(id: UUID(), name: "Allegra Pizza", originalName: "ALLEGRA", section: "Pizzas")
        #expect(CommonsImageProvider().terms(for: allegra) == ["ALLEGRA pizza"])
        let calzone = DishImageQuery(id: UUID(), name: "Calzone", originalName: "CALZONE", kind: "Calzone")
        #expect(CommonsImageProvider().terms(for: calzone) == ["CALZONE"])
        #expect(CommonsImageProvider().terms(for: dish) == ["แกงเขียวหวาน", "Green curry"])
        #expect(PexelsImageProvider(apiKey: "k").terms(for: allegra) == ["Allegra Pizza food"])
    }

    @Test("The kind comes from the parser, else a one-word section that is not generic")
    func searchKind() {
        #expect(DishImageQuery(id: UUID(), name: "x", kind: "Pizza", section: "Mains").searchKind == "pizza")
        #expect(DishImageQuery(id: UUID(), name: "x", section: "Pizzas").searchKind == "pizza")
        #expect(DishImageQuery(id: UUID(), name: "x", section: "Curries").searchKind == "curry")
        #expect(DishImageQuery(id: UUID(), name: "x", section: "Mains").searchKind == nil)
        #expect(DishImageQuery(id: UUID(), name: "x", section: "Antipasti").searchKind == nil)
        #expect(DishImageQuery(id: UUID(), name: "x", section: "Salads and soups").searchKind == nil)
    }

    @Test("A Commons file must show the kind of dish: no trains, landscapes or pasta for a pizza")
    func commonsRelevance() throws {
        typealias Page = CommonsImageProvider.CommonsResponse.Page
        func page(_ title: String, _ categories: [String] = []) -> Page {
            Page(index: 1, title: title, imageinfo: nil, categories: categories.map { .init(title: $0) })
        }
        let allegra = DishImageQuery(id: UUID(), name: "Allegra Pizza", originalName: "ALLEGRA", kind: "pizza")
        #expect(!CommonsImageProvider.isRelevant(page("File:RhB ABe 8-12 Allegra Bernina.jpg", ["Category:Allegra (RhB)"]), to: allegra))
        let cacio = DishImageQuery(id: UUID(), name: "Cacio e Pepe Pizza", originalName: "CACIO E PEPE", kind: "pizza")
        #expect(!CommonsImageProvider.isRelevant(page("File:Cacio e pepe at Tutto.jpg", ["Category:Cacio e pepe"]), to: cacio))
        #expect(CommonsImageProvider.isRelevant(page("File:Capricciosa 01.jpg", ["Category:Pizza capricciosa"]), to: allegra))
        let curry = DishImageQuery(id: UUID(), name: "Green curry", originalName: "แกงเขียวหวาน", kind: "curry")
        #expect(CommonsImageProvider.isRelevant(page("File:แกงเขียวหวาน.jpg", ["Category:Green curries"]), to: curry))
        // Without a kind, a shared word with the name is enough.
        let araba = DishImageQuery(id: UUID(), name: "Araba")
        #expect(CommonsImageProvider.isRelevant(page("File:Araba landscape.jpg"), to: araba))
        #expect(!CommonsImageProvider.isRelevant(page("File:Vineyard.jpg"), to: araba))
    }

    @Test("POST /v1/images returns one result per dish and caps the batch at 60")
    func endpoint() async throws {
        try await withApp { app in
            let (service, _, _, _) = chain(commonsHits: ["Green curry"])
            app.dishImages = service
            try await app.testing().test(.POST, "v1/images", beforeRequest: { req async throws in
                try req.content.encode(DishImagesRequest(dishes: [dish]))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(DishImagesResponse.self)
                #expect(body.results.count == 1)
                #expect(body.results.first?.id == dish.id)
                #expect(body.results.first?.image?.source == .commons)
            })

            let tooMany = (0..<61).map { DishImageQuery(id: UUID(), name: "Dish \($0)") }
            try await app.testing().test(.POST, "v1/images", beforeRequest: { req async throws in
                try req.content.encode(DishImagesRequest(dishes: tooMany))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("Commons response parsing builds the credit line from metadata")
    func commonsParsing() throws {
        let json = """
        {"query":{"pages":[
          {"index":2,"title":"File:Green curry b.jpg","imageinfo":[{"url":"https://u/b.jpg","thumburl":"https://u/800px-b.jpg","mime":"image/jpeg",
            "extmetadata":{"Artist":{"value":"<a href=\\"//x\\">Takeaway</a>"},"LicenseShortName":{"value":"CC BY-SA 3.0"}}}]},
          {"index":1,"title":"File:Green curry a.svg","imageinfo":[{"url":"https://u/a.svg","mime":"image/svg+xml"}]},
          {"index":3,"title":"File:Green curry c.png","imageinfo":[{"url":"https://u/c.png","mime":"image/png","extmetadata":{"LicenseShortName":{"value":"CC0"}}}]}
        ]}}
        """
        let response = try JSONDecoder().decode(CommonsImageProvider.CommonsResponse.self, from: Data(json.utf8))
        let image = CommonsImageProvider.parse(response, for: dish)
        #expect(image?.url.absoluteString == "https://u/800px-b.jpg")
        #expect(image?.credit == "Photo: Takeaway, CC BY-SA 3.0")

        let noArtist = try JSONDecoder().decode(CommonsImageProvider.CommonsResponse.self, from: Data("""
        {"query":{"pages":[{"index":1,"title":"File:Green curry.png","imageinfo":[{"url":"https://u/c.png","mime":"image/png","extmetadata":{"LicenseShortName":{"value":"CC0"}}}]}]}}
        """.utf8))
        #expect(CommonsImageProvider.parse(noArtist, for: dish)?.credit == "Photo: Wikimedia Commons, CC0")
    }
}

final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now = Date(timeIntervalSince1970: 1_000_000)
    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    func bump() { lock.withLock { _value += 1 } }
}
