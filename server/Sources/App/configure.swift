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

    // Free dish-photo chain: Wikimedia Commons, then Pexels and Pixabay when keyed.
    // No AI image generation and no paid APIs: photos must cost $0/month.
    app.dishImages = .live(
        pexelsKey: Environment.get("PEXELS_API_KEY"),
        pixabayKey: Environment.get("PIXABAY_API_KEY")
    )

    app.phraseService = PhraseService(apiKey: app.menuParser.apiKey, model: app.menuParser.model)

    try routes(app)
}
