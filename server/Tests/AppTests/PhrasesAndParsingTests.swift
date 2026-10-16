import Foundation
import VaporTesting
import Testing
import MiseShared
@testable import App

@Suite("Phrases and LLM mapping")
struct PhrasesAndParsingTests {
    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            app.phraseService = PhraseService(apiKey: nil, model: "")
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("POST /v1/phrases answers Thai from the PhraseBook")
    func thaiPhrases() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "v1/phrases", beforeRequest: { req async throws in
                try req.content.encode(PhrasesRequest(language: "th", allergens: [.peanuts, .shellfish]))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(PhraseSet.self)
                #expect(body == PhraseBook.phrases(language: "th", allergens: [.peanuts, .shellfish]))
                #expect(body.language == "th")
                #expect(body.allergy.count == 2)
            })
        }
    }

    @Test("POST /v1/phrases falls back to English without a key")
    func unknownLanguage() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "v1/phrases", beforeRequest: { req async throws in
                try req.content.encode(PhrasesRequest(language: "ja", allergens: [.peanuts]))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(PhraseSet.self)
                #expect(body.language == "en")
                #expect(body.allergy == ["Allergic to peanuts. None, please."])
            })
        }
    }

    @Test("Model phrase JSON maps into a PhraseSet")
    func phraseDecoding() throws {
        let json = #"{"order":"注文します","thanks":"ありがとう","allergy":["ピーナッツアレルギーです"],"allergyTranslation":null}"#
        let set = try PhraseService.decode(Data(json.utf8), language: "ja", englishAllergy: "Allergic to peanuts.")
        #expect(set.order == "注文します")
        #expect(set.allergyTranslation == "Allergic to peanuts.")
    }

    @Test("LLM menu JSON with the new fields maps into Dish")
    func llmMapping() throws {
        let json = #"""
        {
          "restaurantName": "Auntie Nid's Kitchen",
          "originalRestaurantName": "ครัวป้านิด",
          "cuisine": "Thai",
          "sourceLanguage": "th",
          "currency": "THB",
          "dishes": [{
            "name": "Green papaya salad",
            "originalName": "ส้มตำ",
            "description": "Shredded green papaya pounded with lime, chilli and peanuts.",
            "originalDescription": null,
            "menuNumber": "07",
            "section": "Salads and soups",
            "price": 95,
            "currency": null,
            "course": "starter",
            "dietaryTags": ["spicy"],
            "allergens": ["peanuts", "shellfish"],
            "allergenSources": [{"allergen": "peanuts", "ingredient": "Peanuts"},
                                {"allergen": "shellfish", "ingredient": "dried shrimp"},
                                {"allergen": "bogus", "ingredient": "x"}],
            "likelyIngredients": [{"name": "Fish sauce", "allergens": ["fish"], "breaks": ["vegetarian", "vegan"],
                                   "question": "ใส่น้ำปลาไหม", "questionTranslation": "Does it have fish sauce?",
                                   "note": null}],
            "protein": "Dried shrimp",
            "spiceLevel": "hot",
            "ingredients": ["green papaya", "lime"],
            "isPopular": true,
            "plate": "salad",
            "confidence": 0.9
          }, {
            "name": "Mystery", "originalName": null, "description": "", "originalDescription": null,
            "menuNumber": null, "section": null, "price": null, "currency": null, "course": "main",
            "dietaryTags": [], "allergens": [], "allergenSources": [], "likelyIngredients": [],
            "protein": null, "spiceLevel": "none", "ingredients": [], "isPopular": false,
            "plate": "space_food", "confidence": 0.5
          }]
        }
        """#
        let menu = try AnthropicMenuParser.decodeMenu(Data(json.utf8), defaultCurrency: "EUR")
        #expect(menu.restaurantName == "Auntie Nid's Kitchen")
        #expect(menu.originalRestaurantName == "ครัวป้านิด")
        #expect(menu.cuisine == "Thai")
        #expect(menu.currency == "THB")

        let dish = try #require(menu.dishes.first)
        #expect(dish.menuNumber == "07")
        #expect(dish.section == "Salads and soups")
        #expect(dish.sectionTitle == "Salads and soups")
        #expect(dish.price == 95)
        #expect(dish.currency == "THB")
        #expect(dish.course == .starter)
        #expect(dish.allergens == [.peanuts, .shellfish])
        #expect(dish.allergenSources == [AllergenSource(allergen: .peanuts, ingredient: "peanuts"),
                                         AllergenSource(allergen: .shellfish, ingredient: "dried shrimp")])
        #expect(dish.likelyIngredients == [LikelyIngredient(
            name: "fish sauce", allergens: [.fish], breaks: [.vegetarian, .vegan],
            question: "ใส่น้ำปลาไหม", questionTranslation: "Does it have fish sauce?", note: nil)])
        #expect(dish.protein == "Dried shrimp")
        #expect(dish.spiceLevel == .hot)
        #expect(dish.plate == .salad)
        #expect(dish.isPopular)

        let mystery = menu.dishes[1]
        #expect(mystery.plate == .generic)
        #expect(mystery.description == nil)
        #expect(mystery.menuNumber == nil)
        #expect(mystery.sectionTitle == "Mains")
    }

    @Test("The schema requires every new field")
    func schemaHasNewFields() throws {
        let data = try JSONEncoder().encode(AnthropicMenuParser.schema)
        let text = String(decoding: data, as: UTF8.self)
        for field in ["menuNumber", "section", "allergenSources", "likelyIngredients", "protein", "plate",
                      "originalRestaurantName", "cuisine", "questionTranslation"] {
            #expect(text.contains("\"\(field)\""), "missing \(field)")
        }
    }
}
