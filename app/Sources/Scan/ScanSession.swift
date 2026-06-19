import SwiftUI
import Observation
import MiseShared

/// Owns the scan → parse → browse lifecycle and the resulting menu state.
@MainActor
@Observable
final class ScanSession {
    enum Phase: Equatable {
        case idle
        case recognizing
        case parsing
        case failed(String)
    }

    var phase: Phase = .idle
    var menu: ParsedMenu?
    /// Which parser produced the current menu ("anthropic" | "heuristic").
    var parserUsed: String?
    /// IDs of dishes the diner added to "My picks".
    var pickedIDs: Set<Dish.ID> = []

    private let recognizer: VisionTextRecognizer
    private let api: APIClient

    init(recognizer: VisionTextRecognizer = VisionTextRecognizer(), api: APIClient = APIClient()) {
        self.recognizer = recognizer
        self.api = api
    }

    var isWorking: Bool {
        phase == .recognizing || phase == .parsing
    }

    /// Runs OCR on the picked image, then asks the backend to structure it.
    func scan(imageData: Data) async {
        phase = .recognizing
        do {
            let text = try await recognizer.recognizeText(in: imageData)
            phase = .parsing
            let response = try await api.parseMenu(text: text)
            menu = response.menu
            parserUsed = response.parser
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        menu = nil
        parserUsed = nil
        pickedIDs = []
        phase = .idle
    }

    // MARK: - My picks

    /// Picked dishes in menu order.
    var picks: [Dish] {
        (menu?.dishes ?? []).filter { pickedIDs.contains($0.id) }
    }

    func isPicked(_ dish: Dish) -> Bool { pickedIDs.contains(dish.id) }

    func togglePick(_ dish: Dish) {
        if pickedIDs.contains(dish.id) {
            pickedIDs.remove(dish.id)
        } else {
            pickedIDs.insert(dish.id)
        }
    }

    /// Sum of picked dish prices, when all have prices.
    var picksTotal: Decimal? {
        let priced = picks.compactMap(\.price)
        guard priced.count == picks.count, !picks.isEmpty else { return nil }
        return priced.reduce(0, +)
    }

    var picksCurrency: String? {
        picks.first?.currency ?? menu?.currency
    }

    /// Plain-text summary for sharing / showing the waiter.
    var picksShareText: String {
        var lines: [String] = []
        if let name = menu?.restaurantName { lines.append(name) }
        lines.append("My picks:")
        for dish in picks {
            var line = "• \(dish.name)"
            if let original = dish.originalName, original != dish.name {
                line += " (\(original))"
            }
            if let price = dish.price {
                line += " — \(formattedPrice(price, currency: dish.currency ?? picksCurrency))"
            }
            lines.append(line)
        }
        if let total = picksTotal {
            lines.append("Total: \(formattedPrice(total, currency: picksCurrency))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Previews

extension ScanSession {
    static var previewLoaded: ScanSession {
        let session = ScanSession()
        session.menu = ParsedMenu(
            restaurantName: "Antonio's Trattoria",
            sourceLanguage: "it",
            currency: "EUR",
            dishes: [
                Dish(name: "Tagliatelle al Ragù", originalName: "Tagliatelle al Ragù",
                     description: "Fresh egg tagliatelle in a 4-hour beef & pork ragù, finished with parmigiano. A house classic, rich and savoury.",
                     originalDescription: "Tagliatelle all'uovo con ragù di manzo e maiale, parmigiano.",
                     price: 16, currency: "EUR", course: .main,
                     dietaryTags: [], allergens: [.gluten, .egg, .dairy], spiceLevel: .mild,
                     ingredients: ["pasta", "beef", "pork", "parmigiano"], isPopular: true),
                Dish(name: "Melanzane Parmigiana", originalName: "Melanzane alla Parmigiana",
                     description: "Baked aubergine layered with tomato, basil and mozzarella.",
                     price: 13, currency: "EUR", course: .main,
                     dietaryTags: [.vegetarian], allergens: [.dairy], spiceLevel: .none,
                     ingredients: ["aubergine", "tomato", "basil", "mozzarella"]),
                Dish(name: "Vitello Tonnato", originalName: "Vitello Tonnato",
                     description: "Thin-sliced veal with a tuna-caper sauce.",
                     price: 14, currency: "EUR", course: .starter,
                     dietaryTags: [], allergens: [.fish, .egg], spiceLevel: .none,
                     ingredients: ["veal", "tuna", "capers"]),
                Dish(name: "Tiramisù", originalName: "Tiramisù",
                     description: "Coffee, mascarpone, cocoa.",
                     price: 7, currency: "EUR", course: .dessert,
                     dietaryTags: [.vegetarian, .containsAlcohol], allergens: [.dairy, .egg, .gluten],
                     spiceLevel: .none, ingredients: ["coffee", "mascarpone", "cocoa"]),
            ]
        )
        session.parserUsed = "heuristic"
        return session
    }
}
