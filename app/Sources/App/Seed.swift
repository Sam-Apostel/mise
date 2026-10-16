import SwiftUI
import MiseShared

/// Launch arguments for development and screenshots.
///
///     -seedMenu 1|2|3        Auntie Nid's (Els) · Trattoria da Carmelo (Sam) · Jay Daeng's (photos loading)
///     -seedPerson everyone|els|luc|sam
///     -seedScreen dish|picks|waiter|filters|people
///     -seedCamera 1          the camera screen with the seeded Recent list
///     -demoViewfinder        the mockup's paper menu in the viewfinder (the simulator has no camera)
@MainActor
enum Seed {
    static var arguments: UserDefaults { .standard }

    static func makeModel() -> AppModel {
        let menu = arguments.integer(forKey: "seedMenu")
        if menu > 0 || arguments.bool(forKey: "seedCamera") { return preview(menu) }
        return AppModel()
    }

    static func preview(_ menu: Int) -> AppModel {
        let model = AppModel(store: .none)
        model.homeCurrency = "EUR"
        model.recents = [SeedData.auntieNids, SeedData.jokPrince]
        switch menu {
        case 2:
            model.profiles = [SeedData.sam]
            model.open(SeedData.carmelo)
            model.selectedProfileID = SeedData.sam.id
            model.filter.requiredTags = [.vegetarian]
        case 3:
            model.profiles = [SeedData.els, SeedData.luc]
            var menu = SeedData.jayDaeng
            menu.dishes = menu.dishes.map { var d = $0; d.imageURL = nil; return d }
            model.open(menu)
            model.imagePhase = .slow
            model.selectedProfileID = SeedData.els.id
        case 1:
            model.profiles = [SeedData.els, SeedData.luc]
            model.open(SeedData.auntieNids)
            model.selectedProfileID = SeedData.els.id
        default:
            model.profiles = [SeedData.els, SeedData.luc]
        }
        model.recents = [SeedData.auntieNids, SeedData.jokPrince]
        switch arguments.string(forKey: "seedPerson") {
        case "everyone": model.selectedProfileID = nil
        case "luc": model.selectedProfileID = SeedData.luc.id
        case "els": model.selectedProfileID = SeedData.els.id
        case "sam": model.selectedProfileID = SeedData.sam.id
        default: break
        }
        return model
    }

    /// Opens the screen named by `-seedScreen` on top of the seeded menu.
    static func openRequestedScreen(model: AppModel, path: Binding<NavigationPath>) {
        guard let screen = arguments.string(forKey: "seedScreen"), let menu = model.menu else { return }
        let ids = menu.dishes.map(\.id)
        if ["picks", "waiter"].contains(screen) {
            // Tom Kha ×1, pineapple rice ×2, Hat Yai ×1, coconut ×1.
            for (index, count) in [(0, 1), (2, 2), (3, 1), (9, 1)] where index < ids.count {
                for _ in 0..<count { model.add(menu.dishes[index]) }
            }
        } else if menu.dishes.count > 2 {
            model.add(menu.dishes[0]); model.add(menu.dishes[2])
        }
        NotificationCenter.default.post(name: .seedScreen, object: screen)
        if screen == "dish", let curry = menu.dishes.first(where: { $0.menuNumber == "05" }) ?? menu.dishes.first {
            path.wrappedValue.append(curry.id)
        }
    }
}

extension Notification.Name {
    static let seedScreen = Notification.Name("MiseSeedScreen")
}
