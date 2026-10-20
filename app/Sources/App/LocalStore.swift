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

    func loadMyPhotos() -> [MyDishPhoto] { load("my-photos.json") ?? [] }
    func saveMyPhotos(_ photos: [MyDishPhoto]) { save(photos, to: "my-photos.json") }

    /// Where the diner's own dish photos live, one JPEG each.
    var photosDirectory: URL? { directory?.appendingPathComponent("DishPhotos", isDirectory: true) }

    func photoURL(_ file: String) -> URL? { photosDirectory?.appendingPathComponent(file) }

    /// Writes a JPEG and returns its file name, or `nil` when nothing is stored.
    func writePhoto(_ jpeg: Data) -> String? {
        guard let folder = photosDirectory else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: folder.appendingPathComponent(file), options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    func deletePhoto(_ file: String) {
        guard let url = photoURL(file) else { return }
        try? FileManager.default.removeItem(at: url)
    }

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
