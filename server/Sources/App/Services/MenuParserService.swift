import Vapor
import MiseShared

/// Turns raw menu text into a structured, filterable `ParsedMenu`.
///
/// When an Anthropic API key is configured it uses the LLM parser; otherwise it
/// falls back to a deterministic heuristic so the server is always runnable.
struct MenuParserService: Sendable {
    let apiKey: String?
    let model: String

    func parse(
        text: String,
        hints: MenuParseHints?,
        client: any Client,
        logger: Logger
    ) async throws -> ParseMenuResponse {
        if let apiKey {
            do {
                let menu = try await AnthropicMenuParser(apiKey: apiKey, model: model)
                    .parse(text: text, hints: hints, client: client, logger: logger)
                return ParseMenuResponse(menu: menu, parser: "anthropic")
            } catch {
                // Never fail the request outright — degrade to the heuristic parser.
                logger.error("Anthropic parse failed, falling back to heuristic: \(error)")
            }
        }
        let menu = HeuristicMenuParser().parse(text: text, hints: hints)
        return ParseMenuResponse(menu: menu, parser: "heuristic")
    }
}

// MARK: - Application storage

extension Application {
    private struct MenuParserKey: StorageKey {
        typealias Value = MenuParserService
    }

    var menuParser: MenuParserService {
        get {
            guard let service = storage[MenuParserKey.self] else {
                fatalError("MenuParserService not configured. Call configure(_:) first.")
            }
            return service
        }
        set { storage[MenuParserKey.self] = newValue }
    }
}
