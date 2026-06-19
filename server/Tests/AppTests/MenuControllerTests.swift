import VaporTesting
import Testing
import MiseShared
@testable import App

@Suite("Menu API")
struct MenuControllerTests {
    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("health check responds ok")
    func health() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("parse rejects empty text")
    func emptyText() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "v1/menu/parse", beforeRequest: { req async throws in
                try req.content.encode(ParseMenuRequest(text: "   "))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("parse returns dishes via the heuristic parser")
    func parseHeuristic() async throws {
        try await withApp { app in
            let menuText = """
            STARTERS
            Tomato Soup - creamy and warm 6.50
            Vegan Buddha Bowl - quinoa and greens 12
            MAINS
            Spicy Beef Burger with bacon 14.00
            """
            try await app.testing().test(.POST, "v1/menu/parse", beforeRequest: { req async throws in
                try req.content.encode(ParseMenuRequest(text: menuText))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ParseMenuResponse.self)
                #expect(body.parser == "heuristic")
                #expect(body.menu.dishes.count >= 3)
                #expect(body.menu.dishes.contains { $0.dietaryTags.contains(.vegan) })
                #expect(body.menu.dishes.contains { $0.dietaryTags.contains(.spicy) })
            })
        }
    }
}
