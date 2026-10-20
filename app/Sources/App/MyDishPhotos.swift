import Foundation
import UIKit
import MiseShared

/// A photo the diner took of their own plate. It stays on the device and comes
/// back the next time a menu from the same restaurant is read.
struct MyDishPhoto: Codable, Hashable, Identifiable {
    var id = UUID()
    /// `restaurantKey(for:)` of the menu it was taken from; empty when the menu had no name.
    var restaurant: String
    /// `dishKey(for:)` of the dish.
    var dish: String
    /// The menu it was taken from: an unnamed restaurant only matches its own menu.
    var menuID: UUID
    /// File name in the photos folder.
    var file: String
    var takenAt: Date

    /// "Pizzeria Da Michele" and "PIZZERIA DA MICHÈLE" are the same place.
    static func restaurantKey(for menu: ParsedMenu) -> String {
        normalize(menu.restaurantName ?? menu.originalRestaurantName ?? "")
    }

    /// The dish's own name ("MARGHERITA"), so a rescan with a different
    /// translation still finds it; the translated name when there is none.
    static func dishKey(for dish: Dish) -> String {
        normalize(dish.originalName ?? dish.name)
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    func matches(_ dish: Dish, in menu: ParsedMenu) -> Bool {
        guard self.dish == Self.dishKey(for: dish) else { return false }
        if menuID == menu.id { return true }
        return !restaurant.isEmpty && restaurant == Self.restaurantKey(for: menu)
    }

    /// Shrinks a camera or library photo to at most 1600 px and re-encodes it as
    /// JPEG, which also drops the location and other metadata.
    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
