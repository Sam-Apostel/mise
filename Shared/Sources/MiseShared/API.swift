import Foundation

/// Request/response contracts shared by the app and the server.
public enum MiseAPI {
    /// Current API version prefix, e.g. `/v1/menu/parse`.
    public static let versionPrefix = "v1"
}

/// Optional hints the client can pass to improve parsing.
public struct MenuParseHints: Codable, Hashable, Sendable {
    /// Caller's preferred language for descriptions (BCP-47), e.g. "en".
    public var preferredLanguage: String?
    /// Currency to assume when the menu omits symbols.
    public var assumedCurrency: String?

    public init(preferredLanguage: String? = nil, assumedCurrency: String? = nil) {
        self.preferredLanguage = preferredLanguage
        self.assumedCurrency = assumedCurrency
    }
}

/// `POST /v1/menu/parse` request body.
///
/// OCR happens on-device; the client sends recognised text rather than the image.
public struct ParseMenuRequest: Codable, Hashable, Sendable {
    public var text: String
    public var hints: MenuParseHints?

    public init(text: String, hints: MenuParseHints? = nil) {
        self.text = text
        self.hints = hints
    }
}

/// `POST /v1/menu/parse` response body.
public struct ParseMenuResponse: Codable, Hashable, Sendable {
    public var menu: ParsedMenu
    /// Identifier of the parsing strategy that produced the menu ("anthropic" | "heuristic").
    public var parser: String

    public init(menu: ParsedMenu, parser: String) {
        self.menu = menu
        self.parser = parser
    }
}

/// Standard error envelope returned by the API.
public struct APIErrorResponse: Codable, Hashable, Sendable {
    public var error: String
    public var reason: String?

    public init(error: String, reason: String? = nil) {
        self.error = error
        self.reason = reason
    }
}
