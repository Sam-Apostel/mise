import Foundation

/// How spicy a dish is. Drives the spice slider in Filters and the spice pill.
public enum SpiceLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case none
    case mild
    case medium
    case hot

    /// Numeric rank, used for the slider and comparisons.
    public var level: Int {
        switch self {
        case .none: return 0
        case .mild: return 1
        case .medium: return 2
        case .hot: return 3
        }
    }

    public var displayName: String {
        switch self {
        case .none: return "Not spicy"
        case .mild: return "Mild"
        case .medium: return "Medium"
        case .hot: return "Hot"
        }
    }

    /// Chili-pepper rendering, e.g. "🌶🌶" for medium.
    public var chiliIndicator: String {
        level == 0 ? "—" : String(repeating: "🌶", count: level)
    }

    public static func < (lhs: SpiceLevel, rhs: SpiceLevel) -> Bool {
        lhs.level < rhs.level
    }
}
