import Vapor

public func configure(_ app: Application) async throws {
    // Railway provides the port to bind via $PORT; default to 8080 locally.
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    // Menus can be large; allow a generous body for OCR text uploads.
    app.routes.defaultMaxBodySize = "1mb"

    // Build the parsing service once and stash it for handlers to reuse.
    app.menuParser = MenuParserService(
        apiKey: Environment.get("ANTHROPIC_API_KEY"),
        model: Environment.get("ANTHROPIC_MODEL") ?? "claude-opus-4-8"
    )
    if app.menuParser.apiKey == nil {
        app.logger.warning("ANTHROPIC_API_KEY not set — using the heuristic menu parser.")
    }

    try routes(app)
}
