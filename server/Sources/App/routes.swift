import Vapor
import MiseShared

func routes(_ app: Application) throws {
    app.get("health") { _ in
        HealthResponse(status: "ok")
    }

    let v1 = app.grouped(.constant(MiseAPI.versionPrefix))
    try v1.register(collection: MenuController())
    try v1.register(collection: ImageController())
    try v1.register(collection: PhraseController())
    try v1.register(collection: FilterController())
}

struct HealthResponse: Content {
    var status: String
}
