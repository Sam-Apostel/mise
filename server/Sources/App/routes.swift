import Vapor
import MiseShared

func routes(_ app: Application) throws {
    app.get("health") { _ in
        HealthResponse(status: "ok")
    }

    let v1 = app.grouped(.constant(MiseAPI.versionPrefix))
    try v1.register(collection: MenuController())
}

struct HealthResponse: Content {
    var status: String
}
