import Foundation
import VaporTesting
import Testing
import MiseShared
@testable import App

/// A provider that answers from a table and records every search, so the chain
/// can be tested without network.
final class FakeImageProvider: ImageProvider, @unchecked Sendable {
    let name: String
    let source: DishImage.Source
    let termsFor: @Sendable (DishImageQuery) -> [String]
    let hits: Set<String>
    let fails: Bool
    private let lock = NSLock()
    private var _calls: [String] = []

    init(_ name: String, source: DishImage.Source, hits: Set<String> = [], fails: Bool = false,
         terms: @escaping @Sendable (DishImageQuery) -> [String]) {
        self.name = name
        self.source = source
        self.hits = hits
        self.fails = fails
        self.termsFor = terms
    }

    var calls: [String] { lock.withLock { _calls } }

    func terms(for dish: DishImageQuery) -> [String] { termsFor(dish) }

    func search(term: String, client: any Client, logger: Logger) async throws -> DishImage? {
        lock.withLock { _calls.append(term) }
        if fails { throw Abort(.badGateway) }
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
        _ = await cache.value(for: "k") { calls.bump(); return nil }
        _ = await cache.value(for: "k") { calls.bump(); return nil }
        #expect(calls.value == 1)
        clock.now = clock.now.addingTimeInterval(101)
        _ = await cache.value(for: "k") { calls.bump(); return nil }
        #expect(calls.value == 2)
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
          {"index":2,"title":"File:b.jpg","imageinfo":[{"url":"https://u/b.jpg","thumburl":"https://u/800px-b.jpg","mime":"image/jpeg",
            "extmetadata":{"Artist":{"value":"<a href=\\"//x\\">Takeaway</a>"},"LicenseShortName":{"value":"CC BY-SA 3.0"}}}]},
          {"index":1,"title":"File:a.svg","imageinfo":[{"url":"https://u/a.svg","mime":"image/svg+xml"}]},
          {"index":3,"title":"File:c.png","imageinfo":[{"url":"https://u/c.png","mime":"image/png","extmetadata":{"LicenseShortName":{"value":"CC0"}}}]}
        ]}}
        """
        let response = try JSONDecoder().decode(CommonsImageProvider.CommonsResponse.self, from: Data(json.utf8))
        let image = CommonsImageProvider.parse(response)
        #expect(image?.url.absoluteString == "https://u/800px-b.jpg")
        #expect(image?.credit == "Photo: Takeaway, CC BY-SA 3.0")

        let noArtist = try JSONDecoder().decode(CommonsImageProvider.CommonsResponse.self, from: Data("""
        {"query":{"pages":[{"index":1,"imageinfo":[{"url":"https://u/c.png","mime":"image/png","extmetadata":{"LicenseShortName":{"value":"CC0"}}}]}]}}
        """.utf8))
        #expect(CommonsImageProvider.parse(noArtist)?.credit == "Photo: Wikimedia Commons, CC0")
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
