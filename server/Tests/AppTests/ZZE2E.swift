import VaporTesting
import Testing
import Foundation
@testable import App
@Test func e2e() async throws {
    setenv("TMINUS_KEY", "test", 1); setenv("TMINUS_URL", "http://127.0.0.1:8799/", 1)
    let app = try await Application.make(.testing)
    try await configure(app)
    app.get("boom") { _ -> String in throw Abort(.internalServerError, reason: "kaboom") }
    try await app.testing().test(.GET, "boom") { res async in #expect(res.status == .internalServerError) }
    try await Task.sleep(for: .seconds(2))
    try await app.asyncShutdown()
}
