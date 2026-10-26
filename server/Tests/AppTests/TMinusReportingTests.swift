import VaporTesting
import Testing
@testable import App

@Suite("T-Minus reporting")
struct TMinusReportingTests {
    private func withApp(_ test: (Application, Reported) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        let reported = Reported()
        do {
            app.middleware.use(TMinusErrorMiddleware { _, extra in
                reported.append(extra["path"] ?? "")
            })
            app.get("boom") { _ -> String in throw Abort(.internalServerError) }
            app.get("bad") { _ -> String in throw Abort(.badRequest) }
            try await test(app, reported)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("reports 5xx errors and still returns the error response")
    func reportsServerErrors() async throws {
        try await withApp { app, reported in
            try await app.testing().test(.GET, "boom") { res async in
                #expect(res.status == .internalServerError)
            }
            #expect(reported.paths == ["/boom"])
        }
    }

    @Test("ignores 4xx errors")
    func ignoresClientErrors() async throws {
        try await withApp { app, reported in
            try await app.testing().test(.GET, "bad") { res async in
                #expect(res.status == .badRequest)
            }
            #expect(reported.paths.isEmpty)
        }
    }
}

/// Paths the middleware reported, collected across the request's tasks.
private final class Reported: @unchecked Sendable {
    private let lock = NSLock()
    private var _paths: [String] = []
    var paths: [String] { lock.withLock { _paths } }
    func append(_ path: String) { lock.withLock { _paths.append(path) } }
}

@Suite("T-Minus error body")
struct TMinusErrorEventTests {
    @Test("an Abort reports its reason, type and the request details")
    func abortBody() throws {
        let event = TMinusErrorEvent(
            error: Abort(.badGateway, reason: "Anthropic timed out"),
            release: "abc1234", environment: "production", extra: ["path": "/v1/menu/parse"]
        )
        #expect(event.message == "Anthropic timed out")
        #expect(event.type == "Vapor.Abort")
        #expect(event.level == "error")
        #expect(event.extra["path"] == "/v1/menu/parse")
    }
}
