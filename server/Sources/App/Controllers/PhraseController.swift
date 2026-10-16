import Vapor
import MiseShared

struct PhraseController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("phrases", use: phrases)
    }

    /// `POST /v1/phrases`: waiter-card phrases in the menu's language. Always 200;
    /// unknown languages without a model fall back to English.
    func phrases(req: Request) async throws -> PhraseSet {
        let body = try req.content.decode(PhrasesRequest.self)
        guard !body.language.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "`language` must not be empty.")
        }
        return await req.application.phraseService.phrases(for: body, client: req.client, logger: req.logger)
    }
}
