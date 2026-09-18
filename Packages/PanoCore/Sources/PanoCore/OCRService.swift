import Foundation
import Vision

/// Extracts text from an image with the Vision framework (docs/06-roadmap.md). Runs off the main
/// thread; the capture loop calls it on a background task after an image is stored, then writes the
/// result back so screenshots become searchable.
public enum OCRService {
    public static func recognizeText(in imageData: Data) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en-US", "tr-TR"]

                let handler = VNImageRequestHandler(data: imageData, options: [:])
                try? handler.perform([request])

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: (text?.isEmpty == false) ? text : nil)
            }
        }
    }
}
