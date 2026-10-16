import Foundation
import Vision
import CoreImage

/// On-device OCR using the Vision framework. Keeps menu photos on the device;
/// only the recognised text is sent to the backend.
struct VisionTextRecognizer {
    enum RecognitionError: LocalizedError {
        case invalidImage
        case noText

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "That image couldn't be read."
            case .noText: return "No text was found in the image."
            }
        }
    }

    /// Recognises text from raw image data (e.g. a JPEG/PNG/HEIC from the photo picker).
    func recognizeText(in imageData: Data) async throws -> String {
        guard let ciImage = CIImage(data: imageData) else {
            throw RecognitionError.invalidImage
        }
        // Camera photos store pixels sensor-side up and carry the real
        // orientation in EXIF; Vision needs it or portrait menus read sideways.
        let orientation = (ciImage.properties[kCGImagePropertyOrientation as String] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        return try await recognizeText(in: ciImage, orientation: orientation)
    }

    func recognizeText(in image: CIImage, orientation: CGImagePropertyOrientation = .up) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: RecognitionError.noText)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Vision defaults to English, so correction pushes Italian words
            // toward English. Prefer Italian and let Vision detect the rest.
            request.recognitionLanguages = ["it-IT", "en-US", "fr-FR", "es-ES", "de-DE"]
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(ciImage: image, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
