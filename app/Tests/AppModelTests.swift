import XCTest
import UIKit
import MiseShared
@testable import Mise

@MainActor
final class AppModelTests: XCTestCase {
    private func model() -> AppModel {
        let model = AppModel(store: .none)
        model.profiles = [SeedData.els, SeedData.luc]
        model.open(SeedData.auntieNids)
        return model
    }

    func testCrossedDishesSinkToTheEndOfTheirCourse() {
        let model = model()
        let soups = model.sections(sortingFor: SeedData.els, sorted: true).first!
        XCTAssertEqual(soups.title, "Salads and soups")
        XCTAssertEqual(soups.dishes.map(\.name), ["Tom Kha Gai", "Som Tam Thai"])
        let mains = model.sections(sortingFor: SeedData.els, sorted: true)[1].dishes.map(\.name)
        XCTAssertEqual(mains.last, "Pad Thai, prawns")
        XCTAssertEqual(Array(mains.suffix(3).prefix(2)), ["Green curry, chicken", "Morning glory"])
    }

    func testSummaryForEls() {
        let s = model().summary(for: SeedData.els)
        XCTAssertEqual(s.ask, 2)
        XCTAssertEqual(s.no, 2)
        XCTAssertEqual(s.total, 11)
    }

    func testHideCrossedAndHiddenSections() {
        let model = model()
        model.hideCrossed = true
        model.hiddenSections = ["Drinks"]
        let names = model.sections(sortingFor: SeedData.els, sorted: true).flatMap(\.dishes).map(\.name)
        XCTAssertFalse(names.contains("Som Tam Thai"))
        XCTAssertFalse(names.contains("Fresh coconut"))
    }

    func testPicksTotalAndHomeCurrency() {
        let model = model()
        let dishes = model.menu!.dishes
        model.add(dishes[0]); model.add(dishes[2]); model.add(dishes[2])
        XCTAssertEqual(model.pickCount, 3)
        XCTAssertEqual(model.picksTotal, 355)
        XCTAssertEqual(model.price(355), "฿355")
        XCTAssertEqual(model.homePrice(95), Money.format(Decimal(string: "2.5265")!, currency: "EUR", fractionDigits: 2))
        model.decrement(dishes[2]); model.decrement(dishes[2])
        XCTAssertEqual(model.pickCount, 1)
    }

    func testWaiterCardPhrasesForEls() {
        let set = model().phrases(for: SeedData.els)
        XCTAssertEqual(set.allergy.first, "แพ้ถั่วลิสง กุ้ง และปู")
        XCTAssertEqual(set.order, "ขอสั่ง")
    }

    func testSentenceBecomesFiltersAndWantedDishesComeFirst() {
        let model = AppModel(store: .none)
        model.open(ParsedMenu(dishes: [
            Dish(name: "Marinara", section: "Pizzas", ingredients: ["pomodoro", "aglio"]),
            Dish(name: "Margherita", section: "Pizzas", ingredients: ["pomodoro", "mozzarella"]),
            Dish(name: "Ortolana", section: "Pizzas", ingredients: ["mozzarella", "peperoni"]),
            Dish(name: "Boscaiola", section: "Pizzas", ingredients: ["mozzarella", "funghi", "peperoni"]),
            Dish(name: "Tiramisù", section: "Desserts", ingredients: ["mascarpone"]),
        ]))
        model.apply(FilterIntentParser.parse("only pizzas with mozzarella and bell pepper, no mushrooms",
                                             sections: ["Pizzas", "Desserts"]))
        XCTAssertEqual(model.hiddenSections, ["Desserts"])
        let names = model.sections(sortingFor: nil, sorted: true).flatMap(\.dishes).map(\.name)
        XCTAssertEqual(names, ["Ortolana", "Margherita", "Marinara", "Boscaiola"])
        XCTAssertEqual(model.verdict(for: model.menu!.dishes[1], profile: nil).reason, "No bell pepper")
    }

    func testIngredientChipCyclesWantAvoidOff() {
        let model = model()
        model.cycle("tomato")
        XCTAssertEqual(model.filter.preferredIngredients, ["tomato"])
        model.cycle("tomato")
        XCTAssertEqual(model.filter.avoidedIngredients, ["tomato"])
        XCTAssertTrue(model.filter.preferredIngredients.isEmpty)
        model.cycle("tomato")
        XCTAssertFalse(model.filter.isActive)
    }

    func testMyPhotoComesBackOnTheNextVisitOnly() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = AppModel(store: LocalStore(directory: folder))
        let first = ParsedMenu(restaurantName: "Pizzeria Da Michele",
                               dishes: [Dish(name: "Margherita Pizza", originalName: "MARGHERITA")])
        model.open(first)
        let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
        }
        let saved = await model.saveMyPhoto(png, for: first.dishes[0])
        XCTAssertTrue(saved)
        XCTAssertNotNil(model.myPhoto(for: first.dishes[0]))

        // A later scan of the same place, spelled differently: new ids, same photo.
        let again = ParsedMenu(restaurantName: "PIZZERIA DA MICHÈLE",
                               dishes: [Dish(name: "Margherita", originalName: "Margherita")])
        model.open(again)
        XCTAssertNotNil(model.myPhoto(for: again.dishes[0]))

        let elsewhere = ParsedMenu(restaurantName: "Sorbillo", dishes: [Dish(name: "Margherita", originalName: "Margherita")])
        model.open(elsewhere)
        XCTAssertNil(model.myPhoto(for: elsewhere.dishes[0]))

        // Kept across launches.
        let relaunched = AppModel(store: LocalStore(directory: folder))
        relaunched.open(again)
        let photo = relaunched.myPhoto(for: again.dishes[0])
        XCTAssertNotNil(photo)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photo.flatMap(relaunched.url(for:))?.path ?? ""))

        relaunched.removeMyPhoto(for: again.dishes[0])
        XCTAssertTrue(relaunched.myPhotos.isEmpty)
    }

    func testUnnamedRestaurantPhotosStayWithTheirMenu() {
        let dish = Dish(name: "Margherita")
        let menu = ParsedMenu(dishes: [dish])
        let photo = MyDishPhoto(restaurant: MyDishPhoto.restaurantKey(for: menu), dish: MyDishPhoto.dishKey(for: dish),
                                menuID: menu.id, file: "x.jpg", takenAt: .now)
        XCTAssertTrue(photo.matches(dish, in: menu))
        XCTAssertFalse(photo.matches(Dish(name: "Margherita"), in: ParsedMenu(dishes: [Dish(name: "Margherita")])))
    }
}
