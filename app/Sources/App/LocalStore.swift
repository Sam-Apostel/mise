import Foundation
import MiseShared

/// Profiles and recent menus as JSON in Application Support, so a menu read at
/// the table still opens when roaming drops before dessert.
struct LocalStore: Sendable {
    var directory: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Mise", isDirectory: true)

    /// A store that reads and writes nothing (seeded runs, previews, tests).
    static let none = LocalStore(directory: nil)

    func loadProfiles() -> [Profile] { load("profiles.json") ?? [] }
    func saveProfiles(_ profiles: [Profile]) { save(profiles, to: "profiles.json") }

    func loadRecents() -> [ParsedMenu] { load("recents.json") ?? [] }
    func saveRecents(_ menus: [ParsedMenu]) { save(menus, to: "recents.json") }

    private func load<T: Decodable>(_ name: String) -> T? {
        guard let url = directory?.appendingPathComponent(name),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to name: String) {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
