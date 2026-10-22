import Vapor
import NIOCore
import MiseShared

/// Wikimedia asks API clients to identify themselves with a way to reach the
/// operator; a vague agent is throttled harder.
private let userAgent = "Mise/0.2 (https://github.com/sam-apostel/mise; menu-reading app) Vapor"

/// The HTTP deadline for one provider call. The chain also races each call against
/// its own timer, but an in-flight NIO request is not cancelled by task cancellation.
private let providerTimeout: TimeAmount = .seconds(8)

// MARK: - Wikimedia Commons

/// Searches Wikimedia Commons files (namespace 6) by the dish's original name,
/// then its English name, each with the kind of dish ("Allegra pizza"). Free,
/// no key; credit comes from the file's metadata.
///
/// Commons is a general media library: a bare "Allegra" finds a train. A file
/// is only used when its title or categories name the kind of dish.
/// Wikimedia asks for one request at a time, so the chain runs this tier serially.
struct CommonsImageProvider: ImageProvider {
    let name = "commons"
    let maxConcurrent = 1
    private static let endpoint = "https://commons.wikimedia.org/w/api.php"

    func terms(for dish: DishImageQuery) -> [String] {
        let kind = dish.searchKind
        var terms: [String] = []
        for name in [dish.originalName.nonEmpty, Optional(dish.name).nonEmpty].compactMap({ $0 }) {
            let term = kind.map { name.lowercased().contains($0) ? name : "\(name) \($0)" } ?? name
            if !terms.contains(where: { $0.lowercased() == term.lowercased() }) { terms.append(term) }
        }
        return terms
    }

    func search(term: String, dish: DishImageQuery, client: any Client, logger: Logger) async throws -> DishImage? {
        struct Query: Content {
            var action = "query"
            var format = "json"
            var formatversion = "2"
            var generator = "search"
            let gsrsearch: String
            var gsrnamespace = "6"
            var gsrlimit = "8"
            var prop = "imageinfo|categories"
            var clshow = "!hidden"
            var cllimit = "max"
            var iiprop = "url|extmetadata|mime"
            var iiextmetadatafilter = "Artist|LicenseShortName"
            var iiurlwidth = "800"
        }
        let response = try await client.get(URI(string: Self.endpoint)) { req in
            req.headers.replaceOrAdd(name: .userAgent, value: userAgent)
            req.timeout = providerTimeout
            try req.query.encode(Query(gsrsearch: term))
        }
        try checkStatus(response, provider: "Commons")
        return try Self.parse(response.content.decode(CommonsResponse.self), for: dish)
    }

    /// Picks the best-ranked JPEG/PNG that shows the dish and builds its credit line.
    static func parse(_ response: CommonsResponse, for dish: DishImageQuery) -> DishImage? {
        let pages = (response.query?.pages ?? []).sorted { ($0.index ?? .max) < ($1.index ?? .max) }
        for page in pages {
            guard isRelevant(page, to: dish),
                  let info = page.imageinfo?.first,
                  let mime = info.mime, mime == "image/jpeg" || mime == "image/png",
                  let urlString = info.thumburl ?? info.url,
                  let url = URL(string: urlString) else { continue }
            let artist = info.extmetadata?.Artist?.value.map(stripHTML).flatMap { Optional($0).nonEmpty }
            let licence = info.extmetadata?.LicenseShortName?.value.map(stripHTML).flatMap { Optional($0).nonEmpty }
            let credit = "Photo: " + [artist ?? "Wikimedia Commons", licence].compactMap { $0 }.joined(separator: ", ")
            return DishImage(url: url, credit: credit, source: .commons)
        }
        return nil
    }

    /// With a kind of dish, the file's title or categories must name it ("pizza",
    /// "curries" for curry). Without one, they must share a word with the dish's name.
    static func isRelevant(_ page: CommonsResponse.Page, to dish: DishImageQuery) -> Bool {
        let text = ([page.title ?? ""] + (page.categories ?? []).compactMap(\.title)).joined(separator: " ").lowercased()
        if let kind = dish.searchKind {
            return kind.split(separator: " ").allSatisfy { text.contains(stem(String($0))) }
        }
        if let original = dish.originalName.nonEmpty?.lowercased(),
           original.unicodeScalars.contains(where: { $0.value > 0x024F }), text.contains(original) {
            return true
        }
        let words = (dish.name + " " + (dish.originalName ?? "")).lowercased()
            .split { !$0.isLetter }.filter { $0.count >= 4 }
        return words.contains { text.contains(stem(String($0))) }
    }

    /// "curry" → "curr" so "Green curries" matches; "pizzas" → "pizza".
    static func stem(_ word: String) -> String {
        var w = word
        if w.count > 4, w.hasSuffix("s") { w.removeLast() }
        if w.count > 4, w.hasSuffix("y") { w.removeLast() }
        return w
    }

    struct CommonsResponse: Codable {
        struct Query: Codable { var pages: [Page]? }
        struct Page: Codable {
            var index: Int?
            var title: String?
            var imageinfo: [Info]?
            var categories: [Category]?
        }
        struct Category: Codable { var title: String? }
        struct Info: Codable {
            var url: String?
            var thumburl: String?
            var mime: String?
            var extmetadata: Metadata?
        }
        struct Metadata: Codable {
            var Artist: Field?
            var LicenseShortName: Field?
        }
        struct Field: Codable { var value: String? }

        var query: Query?
    }
}

/// Removes HTML tags and the common entities, collapsing whitespace.
func stripHTML(_ html: String) -> String {
    var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"),
                           ("&gt;", ">"), ("&nbsp;", " ")] {
        text = text.replacingOccurrences(of: entity, with: char)
    }
    return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Pexels

/// Pexels stock photos (free key, `PEXELS_API_KEY`). Searches "<name> <kind> <cuisine> food".
struct PexelsImageProvider: ImageProvider {
    let name = "pexels"
    let maxConcurrent = 4
    let apiKey: String

    func terms(for dish: DishImageQuery) -> [String] {
        [[dish.nameWithKind, dish.cuisine, "food"].compactMap { $0 }.joined(separator: " ")]
    }

    func search(term: String, dish: DishImageQuery, client: any Client, logger: Logger) async throws -> DishImage? {
        struct Query: Content {
            let query: String
            var per_page = "1"
        }
        struct Response: Codable {
            struct Photo: Codable {
                struct Src: Codable { var large: String? }
                var photographer: String?
                var src: Src?
            }
            var photos: [Photo]?
        }
        let response = try await client.get("https://api.pexels.com/v1/search") { req in
            req.headers.replaceOrAdd(name: .authorization, value: apiKey)
            req.headers.replaceOrAdd(name: .userAgent, value: userAgent)
            req.timeout = providerTimeout
            try req.query.encode(Query(query: term))
        }
        try checkStatus(response, provider: "Pexels")
        guard let photo = try response.content.decode(Response.self).photos?.first,
              let url = photo.src?.large.flatMap(URL.init(string:)) else { return nil }
        let credit = "Photo: \(photo.photographer ?? "Unknown") on Pexels"
        return DishImage(url: url, credit: credit, source: .pexels)
    }
}

// MARK: - Pixabay

/// Pixabay stock photos (free key, `PIXABAY_API_KEY`), food category only.
///
/// Known follow-up: Pixabay's terms forbid permanent hotlinking of `webformatURL`
/// (the links expire after ~24 h). We return it as-is for now; re-hosting the
/// image (or caching hits for under a day) is still to be built.
struct PixabayImageProvider: ImageProvider {
    let name = "pixabay"
    let maxConcurrent = 4
    let apiKey: String

    func terms(for dish: DishImageQuery) -> [String] {
        [[dish.nameWithKind, dish.cuisine].compactMap { $0 }.joined(separator: " ")]
    }

    func search(term: String, dish: DishImageQuery, client: any Client, logger: Logger) async throws -> DishImage? {
        struct Query: Content {
            let key: String
            let q: String
            var image_type = "photo"
            var category = "food"
            var safesearch = "true"
            var per_page = "3"
        }
        struct Response: Codable {
            struct Hit: Codable {
                var webformatURL: String?
                var user: String?
            }
            var hits: [Hit]?
        }
        let response = try await client.get("https://pixabay.com/api/") { req in
            req.headers.replaceOrAdd(name: .userAgent, value: userAgent)
            req.timeout = providerTimeout
            try req.query.encode(Query(key: apiKey, q: term))
        }
        try checkStatus(response, provider: "Pixabay")
        guard let hit = try response.content.decode(Response.self).hits?.first,
              let url = hit.webformatURL.flatMap(URL.init(string:)) else { return nil }
        let credit = "Photo: \(hit.user ?? "Unknown") on Pixabay"
        return DishImage(url: url, credit: credit, source: .pixabay)
    }
}

// MARK: - Shared

/// A provider said "too many requests". The chain stops calling it until the wait is over.
struct ImageProviderRateLimited: Error, CustomStringConvertible {
    let provider: String
    /// From the `Retry-After` header, when given in seconds.
    let retryAfter: Duration?
    var description: String { "\(provider) rate-limited us (retry after \(retryAfter.map { "\($0)" } ?? "unknown"))" }
}

/// Throws `ImageProviderRateLimited` on 429 and `Abort` on any other non-200.
func checkStatus(_ response: ClientResponse, provider: String) throws {
    if response.status == .tooManyRequests {
        let seconds = response.headers.first(name: "Retry-After").flatMap(Int.init)
        throw ImageProviderRateLimited(provider: provider, retryAfter: seconds.map { .seconds($0) })
    }
    guard response.status == .ok else {
        throw Abort(.badGateway, reason: "\(provider) returned \(response.status)")
    }
}

/// Section headings too broad to say what is on the plate.
private let genericSections: Set<String> = [
    "starter", "main", "side", "dessert", "drink", "beverage", "special", "other", "menu", "house", "appetizer",
    "entree", "antipasti", "antipasto", "primi", "primo", "secondi", "secondo", "contorni", "contorno", "dolci",
    "dolce", "bevande", "plat", "plats", "entrée", "entrées", "voorgerecht", "hoofdgerecht", "nagerecht", "extra",
    "kid", "children", "lunch", "dinner", "classic", "speciality", "specialty", "chef"]

extension DishImageQuery {
    /// The kind of dish to search and check photos for: the parser's own, else
    /// a one-word section heading made singular ("Pizzas" → "pizza").
    var searchKind: String? {
        if let kind = kind.nonEmpty?.lowercased() { return kind }
        let words = (section ?? "").lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 }
        guard words.count == 1, var word = words.first else { return nil }
        if word.hasSuffix("ies") { word = String(word.dropLast(3)) + "y" } else if word.hasSuffix("s"), !word.hasSuffix("ss") {
            word.removeLast()
        }
        return genericSections.contains(word) || genericSections.contains(words[0]) ? nil : word
    }

    /// "Allegra Pizza", or "Margherita pizza" when the name does not say it.
    var nameWithKind: String {
        guard let kind = searchKind, !name.lowercased().contains(kind) else { return name }
        return "\(name) \(kind)"
    }
}
