import Vapor
import MiseShared

struct ImageController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("images", use: images)
    }

    /// `POST /v1/images`: a typical photo per dish from the free chain, or `nil`.
    func images(req: Request) async throws -> DishImagesResponse {
        let body = try req.content.decode(DishImagesRequest.self)
        guard body.dishes.count <= DishImageService.maxBatch else {
            throw Abort(.badRequest, reason: "At most \(DishImageService.maxBatch) dishes per request.")
        }
        let results = await req.application.dishImages.images(
            for: body.dishes, client: req.client, logger: req.logger)
        return DishImagesResponse(results: results)
    }
}
