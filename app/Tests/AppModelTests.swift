import XCTest
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
}
