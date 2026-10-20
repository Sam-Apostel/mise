import Vapor
import MiseShared

struct FilterController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.grouped("filters").post("interpret", use: interpret)
    }

    /// `POST /v1/filters/interpret`: a spoken or typed sentence in, filters out.
    /// Always 200; an empty intent means "not a filter, treat it as a search".
    func interpret(req: Request) async throws -> FilterIntent {
        let body = try req.content.decode(InterpretFiltersRequest.self)
        let text = body.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else {
            throw Abort(.badRequest, reason: "`text` must be 1–500 characters.")
        }
        return await req.application.filterInterpreter.interpret(body, client: req.client, logger: req.logger)
    }
}
