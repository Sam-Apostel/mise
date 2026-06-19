import Vapor
import MiseShared

struct MenuController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let menu = routes.grouped("menu")
        menu.post("parse", use: parse)
    }

    /// `POST /v1/menu/parse` — OCR text in, structured + enriched menu out.
    func parse(req: Request) async throws -> ParseMenuResponse {
        let body = try req.content.decode(ParseMenuRequest.self)

        let trimmed = body.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw Abort(.badRequest, reason: "`text` must not be empty.")
        }

        return try await req.application.menuParser.parse(
            text: trimmed,
            hints: body.hints,
            client: req.client,
            logger: req.logger
        )
    }
}
