import Foundation

/// Allergens a dish *contains*. Powers the "Avoid allergens" filter section and
/// the "contains gluten / no nuts" pills on the dish detail screen.
public enum Allergen: String, Codable, CaseIterable, Sendable {
    case gluten
    case dairy
    case nuts
    case peanuts
    case shellfish
    case fish
    case egg
    case soy
    case sesame

    public var displayName: String {
        switch self {
        case .gluten: return "Gluten"
        case .dairy: return "Dairy"
        case .nuts: return "Tree nuts"
        case .peanuts: return "Peanuts"
        case .shellfish: return "Shellfish"
        case .fish: return "Fish"
        case .egg: return "Egg"
        case .soy: return "Soy"
        case .sesame: return "Sesame"
        }
    }

    public var systemImageName: String {
        switch self {
        case .gluten: return "allergens"
        case .dairy: return "drop"
        case .nuts, .peanuts: return "circle.hexagongrid"
        case .shellfish, .fish: return "fish"
        case .egg: return "oval"
        case .soy: return "leaf"
        case .sesame: return "circle.grid.2x2"
        }
    }
}
