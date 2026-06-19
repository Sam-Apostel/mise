import Foundation

/// App-wide configuration resolved at launch.
enum AppConfig {
    /// Base URL of the Mise backend.
    ///
    /// Read from the `MiseAPIBaseURL` Info.plist key (set in `project.yml`),
    /// falling back to localhost for simulator development.
    static let apiBaseURL: URL = {
        if let string = Bundle.main.object(forInfoDictionaryKey: "MiseAPIBaseURL") as? String,
           let url = URL(string: string) {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }()
}
