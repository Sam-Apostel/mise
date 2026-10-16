import Vapor
import NIOCore
import MiseShared

/// Wikimedia asks API clients to identify themselves.
private let userAgent = "Mise/0.1 (menu reader; contact via github)"

/// The HTTP deadline for one provider call. The chain also races each call against
/// its own timer, but an in-flight NIO request is not cancelled by task cancellation.
private let providerTimeout: TimeAmount = .seconds(8)

// MARK: - Wikimedia Commons

/// Searches Wikimedia Commons files (namespace 6) by the dish's original name,
/// then its English name. Free, no key; credit comes from the file's metadata.
struct CommonsImageProvider: ImageProvider {
    let name = "commons"
    private static let endpoint = "https://commons.wikimedia.org/w/api.php"

    func terms(for dish: DishImageQuery) -> [String] {
        var terms: [String] = []
        if let original = dish.originalName.nonEmpty { terms.append(original) }
        if let english = Optional(dish.name).nonEmpty, !terms.contains(english) { terms.append(english) }
        return terms
    }

    func search(term: String, client: any Client, logger: Logger) async throws -> DishImage? {
        struct Query: Content {
            var action = "query"
            var format = "json"
            var formatversion = "2"
            var generator = "search"
            let gsrsearch: String
            var gsrnamespace = "6"
            var gsrlimit = "8"
            var prop = "imageinfo"
            var iiprop = "url|extmetadata|mime"
            var iiextmetadatafilter = "Artist|LicenseShortName"
            var iiurlwidth = "800"
        }
        let response = try await client.get(URI(string: Self.endpoint)) { req in
            req.headers.replaceOrAdd(name: .userAgent, value: userAgent)
            req.timeout = providerTimeout
            try req.query.encode(Query(gsrsearch: term))
        }
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Commons returned \(response.status)")
        }
        return try Self.parse(response.content.decode(CommonsResponse.self))
    }

    /// Picks the best-ranked JPEG/PNG and builds its credit line.
    static func parse(_ response: CommonsResponse) -> DishImage? {
        let pages = (response.query?.pages ?? []).sorted { ($0.index ?? .max) < ($1.index ?? .max) }
        for page in pages {
            guard let info = page.imageinfo?.first,
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

    struct CommonsResponse: Codable {
        struct Query: Codable { var pages: [Page]? }
        struct Page: Codable {
            var index: Int?
            var title: String?
            var imageinfo: [Info]?
        }
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

/// Pexels stock photos (free key, `PEXELS_API_KEY`). Searches "<name> <cuisine> food".
struct PexelsImageProvider: ImageProvider {
    let name = "pexels"
    let apiKey: String

    func terms(for dish: DishImageQuery) -> [String] {
        [[dish.name, dish.cuisine, "food"].compactMap { $0 }.joined(separator: " ")]
    }

    func search(term: String, client: any Client, logger: Logger) async throws -> DishImage? {
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
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Pexels returned \(response.status)")
        }
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
    let apiKey: String

    func terms(for dish: DishImageQuery) -> [String] {
        [[dish.name, dish.cuisine].compactMap { $0 }.joined(separator: " ")]
    }

    func search(term: String, client: any Client, logger: Logger) async throws -> DishImage? {
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
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Pixabay returned \(response.status)")
        }
        guard let hit = try response.content.decode(Response.self).hits?.first,
              let url = hit.webformatURL.flatMap(URL.init(string:)) else { return nil }
        let credit = "Photo: \(hit.user ?? "Unknown") on Pixabay"
        return DishImage(url: url, credit: credit, source: .pixabay)
    }
}
