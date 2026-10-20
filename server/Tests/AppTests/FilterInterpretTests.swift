import Foundation
import VaporTesting
import Testing
import MiseShared
@testable import App

@Suite("Filters from a sentence")
struct FilterInterpretTests {
    let sections = ["Pizzas", "Calzoni", "Desserts"]

    @Test("Without a key the endpoint answers with the offline parser")
    func offlineEndpoint() async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            app.filterInterpreter = FilterInterpreter(apiKey: nil, model: "")
            let request = InterpretFiltersRequest(
                text: "I only want pizzas, with mozzarella and bell pepper. No mushrooms or seafood",
                sections: sections, ingredients: ["mozzarella", "bell pepper", "mushroom", "tuna"])
            try await app.testing().test(.POST, "v1/filters/interpret", beforeRequest: { req async throws in
                try req.content.encode(request)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let intent = try res.content.decode(FilterIntent.self)
                #expect(intent.onlySections == ["Pizzas"])
                #expect(intent.want == ["mozzarella", "bell pepper"])
                #expect(intent.avoid == ["mushroom", "seafood"])
            })
            try await app.testing().test(.POST, "v1/filters/interpret", beforeRequest: { req async throws in
                try req.content.encode(InterpretFiltersRequest(text: "  ", sections: sections, ingredients: []))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("The model's answer keeps only real sections and tidies names")
    func decode() throws {
        let json = #"""
        {"onlySections": ["Pizzas", "Pasta"], "hideSections": [], "want": ["Mozzarella", "bell pepper", "mozzarella"],
         "avoid": ["mushroom", " ", "seafood"], "requiredTags": ["vegetarian", "keto"], "maxSpice": "mild", "maxPrice": 12.5}
        """#
        let intent = try FilterInterpreter.decode(Data(json.utf8), sections: sections)
        #expect(intent.onlySections == ["Pizzas"])
        #expect(intent.want == ["mozzarella", "bell pepper"])
        #expect(intent.avoid == ["mushroom", "seafood"])
        #expect(intent.requiredTags == [.vegetarian])
        #expect(intent.maxSpice == .mild)
        #expect(intent.maxPrice == Decimal(string: "12.5"))
    }

    @Test("Section titles become an enum in the schema")
    func schema() throws {
        let text = String(decoding: try JSONEncoder().encode(FilterInterpreter.schema(sections: sections)), as: UTF8.self)
        #expect(text.contains("\"Calzoni\""))
        #expect(text.contains("\"maxPrice\""))
    }
}
