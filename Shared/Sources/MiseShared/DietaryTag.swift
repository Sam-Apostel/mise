import Foundation

/// Dietary and preparation attributes used to drive the app's filters.
///
/// Stored as stable string raw values so they round-trip cleanly through JSON
/// between the server and the app.
public enum DietaryTag: String, Codable, CaseIterable, Sendable {
    case vegetarian
    case vegan
    case pescatarian
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case nutFree = "nut_free"
    case eggFree = "egg_free"
    case shellfishFree = "shellfish_free"
    case halal
    case kosher
    case spicy
    case containsAlcohol = "contains_alcohol"
    case containsPork = "contains_pork"
    case raw
    case healthy

    public var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten-free"
        case .dairyFree: return "Dairy-free"
        case .nutFree: return "Nut-free"
        case .eggFree: return "Egg-free"
        case .shellfishFree: return "Shellfish-free"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        case .spicy: return "Spicy"
        case .containsAlcohol: return "Contains alcohol"
        case .containsPork: return "Contains pork"
        case .raw: return "Raw"
        case .healthy: return "Healthy"
        }
    }

    /// SF Symbol name, handy for chips and filter rows in the UI.
    public var systemImageName: String {
        switch self {
        case .vegetarian, .vegan, .healthy: return "leaf"
        case .pescatarian, .shellfishFree: return "fish"
        case .glutenFree: return "allergens"
        case .dairyFree, .eggFree, .nutFree: return "exclamationmark.shield"
        case .halal, .kosher: return "checkmark.seal"
        case .spicy: return "flame"
        case .containsAlcohol: return "wineglass"
        case .containsPork: return "fork.knife"
        case .raw: return "snowflake"
        }
    }
}
