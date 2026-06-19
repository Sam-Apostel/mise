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

    /// Sends recognised menu text to the backend and returns the parsed menu.
    func parseMenu(text: String, hints: MenuParseHints? = nil) async throws -> ParseMenuResponse {
        let url = baseURL
            .appendingPathComponent(MiseAPI.versionPrefix)
            .appendingPathComponent("menu")
            .appendingPathComponent("parse")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
