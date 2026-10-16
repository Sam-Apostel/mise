import Foundation

/// The drawn plate a dish falls back to when the image chain finds no photo,
/// and that every tile shows while photos are still loading.
///
/// The parser picks the closest archetype; the app draws it. Unknown raw values
/// decode as `.generic` so the server can add archetypes before the app draws them.
public enum PlateArchetype: String, Codable, CaseIterable, Sendable {
    case creamySoup = "creamy_soup"     // tom kha, chowder, bisque
    case spicySoup = "spicy_soup"       // tom yum, clear red broth
    case noodleSoup = "noodle_soup"     // kuay teow, pho, ramen
    case porridge                       // jok, congee, risotto
    case salad                          // som tam, slaw, insalata
    case curry                          // green curry, stew in a ring of rice
    case friedNoodles = "fried_noodles" // pad thai, pasta, chow mein
    case friedRice = "fried_rice"
    case riceInFruit = "rice_in_fruit"  // pineapple fried rice
    case riceWithEgg = "rice_with_egg"  // kra pao, rice plate with a fried egg
    case chickenRice = "chicken_rice"   // khao man gai, sliced meat on rice
    case greens                         // morning glory, stir-fried vegetables
    case friedChicken = "fried_chicken" // fried or grilled pieces
    case wholeFish = "whole_fish"
    case fishRolls = "fish_rolls"       // involtini, rolled or sliced fish
    case sweet                          // mango sticky rice, cake, pastry
    case coconut                        // a drinking coconut
    case drink                          // a tall glass
    case generic

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlateArchetype(rawValue: raw) ?? .generic
    }
}
