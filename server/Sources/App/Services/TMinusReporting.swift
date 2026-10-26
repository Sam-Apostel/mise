import Vapor

/// Reports server errors to T-Minus (https://t-min.sams.works). Does nothing without `TMINUS_KEY`.
///
/// Posts with Vapor's own HTTP client rather than TMinusKit: TMinusKit sends through
/// FoundationNetworking, which doesn't link into the `--static-swift-stdlib` Docker build.
enum TMinusReporting {
    static func start(_ app: Application) {
        guard let key = Environment.get("TMINUS_KEY"), !key.isEmpty else { return }
        let base = (Environment.get("TMINUS_URL").flatMap { $0.isEmpty ? nil : $0 } ?? "https://t-min.sams.works")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let uri = URI(string: base + "/ingest/v1/errors")
        let release = Environment.get("RAILWAY_GIT_COMMIT_SHA").map { String($0.prefix(7)) }
        let environment = Environment.get("RAILWAY_ENVIRONMENT_NAME") ?? app.environment.name
        let client = app.client
        let logger = app.logger

        app.middleware.use(TMinusErrorMiddleware { error, extra in
            let event = TMinusErrorEvent(error: error, release: release, environment: environment, extra: extra)
            Task {
                do {
                    let res = try await client.post(uri, headers: ["Authorization": "Bearer \(key)"]) { req in
                        try req.content.encode(event, as: .json)
                        req.timeout = .seconds(5)
                    }
                    if res.status.code >= 300 { logger.warning("T-Minus report failed: \(res.status.code)") }
                } catch {
                    logger.warning("T-Minus report failed: \(error)")
                }
            }
        })
    }
}

/// Sits inside Vapor's `ErrorMiddleware` and reports errors that become a 5xx. 4xx are the client's
/// fault (empty text, bad JSON) and only add noise.
struct TMinusErrorMiddleware: AsyncMiddleware {
    let report: @Sendable (any Error, [String: String]) -> Void

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let status = (error as? any AbortError)?.status ?? .internalServerError
            if status.code >= 500 {
                report(error, ["method": request.method.rawValue, "path": request.url.path, "status": "\(status.code)"])
            }
            throw error
        }
    }
}

/// The `/ingest/v1/errors` body.
struct TMinusErrorEvent: Content {
    var message: String
    var type: String
    var level = "error"
    var release: String?
    var environment: String?
    var extra: [String: String]

    init(error: any Error, release: String?, environment: String?, extra: [String: String]) {
        message = (error as? any AbortError)?.reason ?? String(describing: error)
        type = String(reflecting: Swift.type(of: error))
        self.release = release
        self.environment = environment
        self.extra = extra
    }
}
