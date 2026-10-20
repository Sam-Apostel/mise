import Foundation
import MiseShared

/// Thin async wrapper around the Mise backend.
struct APIClient: Sendable {
    var baseURL: URL = AppConfig.apiBaseURL
    var urlSession: URLSession = .shared

    enum APIError: LocalizedError {
        case badStatus(Int, String?)
        case decoding(any Error)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code, let reason):
                return "Server error (\(code))\(reason.map { ": \($0)" } ?? "")."
            case .decoding:
                return "Couldn't read the server's response."
            }
        }
    }

    private func post<Body: Encodable, Response: Decodable>(
        _ path: String, body: Body, timeout: TimeInterval
    ) async throws -> Response {
        var url = baseURL.appendingPathComponent(MiseAPI.versionPrefix)
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badStatus(-1, "No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let reason = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.reason
            throw APIError.badStatus(http.statusCode, reason)
        }
        do { return try JSONDecoder().decode(Response.self, from: data) } catch { throw APIError.decoding(error) }
    }

    /// Typical photos for one batch of dishes (the server caps a batch at 60)
    /// from the server's free image chain.
    func dishImages(_ queries: [DishImageQuery]) async throws -> [DishImageResult] {
        let response: DishImagesResponse = try await post("images", body: DishImagesRequest(dishes: queries), timeout: 45)
        return response.results
    }

    /// "Only pizzas, no mushrooms" → filters, read by the server's model against this menu.
    func interpretFilters(_ request: InterpretFiltersRequest) async throws -> FilterIntent {
        try await post("filters/interpret", body: request, timeout: 25)
    }

    /// Waiter-card phrases for a language the app does not carry offline.
    func phrases(_ request: PhrasesRequest) async throws -> PhraseSet {
        try await post("phrases", body: request, timeout: 30)
    }

    /// Today's ECB rate from Frankfurter (free, no key): units of `to` per one `from`.
    func exchangeRate(from home: String, to currency: String) async throws -> ExchangeRate {
        struct Rates: Decodable { let rates: [String: Double] }
        var components = URLComponents(string: "https://api.frankfurter.app/latest")!
        components.queryItems = [.init(name: "from", value: home), .init(name: "to", value: currency)]
        let (data, _) = try await urlSession.data(from: components.url!)
        let rates = try JSONDecoder().decode(Rates.self, from: data)
        guard let value = rates.rates[currency] else { throw APIError.badStatus(404, "No rate for \(currency)") }
        return ExchangeRate(home: home, perHome: Decimal(value), fetchedAt: .now)
    }

    /// Sends recognised menu text to the backend and returns the parsed menu.
    func parseMenu(text: String, hints: MenuParseHints? = nil) async throws -> ParseMenuResponse {
        let url = baseURL
            .appendingPathComponent(MiseAPI.versionPrefix)
            .appendingPathComponent("menu")
            .appendingPathComponent("parse")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // An Opus parse of a long menu over roaming data can outlast the 60 s default.
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ParseMenuRequest(text: text, hints: hints))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(-1, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let reason = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.reason
                ?? String(data: data, encoding: .utf8)
            throw APIError.badStatus(http.statusCode, reason)
        }

        do {
            return try JSONDecoder().decode(ParseMenuResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
