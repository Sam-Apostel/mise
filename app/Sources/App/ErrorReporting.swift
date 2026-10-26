import Foundation
#if canImport(TMinusKit)
import TMinusKit
#endif

/// Error and crash reporting to T-Minus (https://t-min.sams.works). Off unless the build sets
/// `TMINUS_KEY` (see `Config/Mise.xcconfig`); crashes arrive through MetricKit on the next launch.
enum ErrorReporting {
    static func start() {
        #if canImport(TMinusKit)
        guard let key = infoValue("TMINUS_KEY") else { return }
        let url = infoValue("TMINUS_URL").flatMap { URL(string: $0) } ?? TMinus.defaultURL
        #if DEBUG
        let environment = "debug"
        #else
        let environment = "production"
        #endif
        TMinus.start(.init(url: url, key: key, environment: environment))
        #endif
    }

    /// Reports errors worth a look. What the diner can fix (a blurry photo, no signal) and the
    /// server's own 5xx (it reports those itself) are left out.
    static func capture(_ error: any Error, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if canImport(TMinusKit)
        switch error {
        case is VisionTextRecognizer.RecognitionError, is URLError, is CancellationError:
            return
        case APIClient.APIError.badStatus(let code, _) where code >= 400:
            return
        default:
            TMinus.capture(error, file: file, function: function, line: line)
        }
        #endif
    }

    /// An Info.plist value, or `nil` when the build setting behind it is empty.
    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}
