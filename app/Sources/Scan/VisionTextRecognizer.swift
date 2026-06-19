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
        return try await recognizeText(in: ciImage)
    }

    func recognizeText(in image: CIImage) async throws -> String {
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

            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
