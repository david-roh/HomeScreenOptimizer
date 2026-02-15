import Foundation
#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(Vision)
import CoreGraphics
import ImageIO
import Vision
#endif

public struct OCRLabelCandidate: Codable, Hashable, Sendable {
    public var text: String
    public var confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
    }
}

public protocol LayoutOCRExtracting: Sendable {
    func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate]
}

public enum OCRExtractionError: Error, LocalizedError {
    case visionUnavailable
    case failedToLoadImage

    public var errorDescription: String? {
        switch self {
        case .visionUnavailable:
            return "Vision OCR is unavailable on this platform."
        case .failedToLoadImage:
            return "Failed to load screenshot image for OCR."
        }
    }
}

public struct VisionLayoutOCRExtractor: LayoutOCRExtracting {
    private let postProcessor: OCRPostProcessor

    public init(postProcessor: OCRPostProcessor = OCRPostProcessor()) {
        self.postProcessor = postProcessor
    }

    public func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate] {
        #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(Vision)
        let url = URL(fileURLWithPath: screenshotPath)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw OCRExtractionError.failedToLoadImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.015

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let rawCandidates = (request.results ?? []).compactMap { observation -> OCRLabelCandidate? in
            guard let top = observation.topCandidates(1).first else {
                return nil
            }

            let cleaned = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                return nil
            }

            return OCRLabelCandidate(text: cleaned, confidence: Double(top.confidence))
        }

        return postProcessor.process(rawCandidates)
        #else
        _ = screenshotPath
        throw OCRExtractionError.visionUnavailable
        #endif
    }
}

public struct StubLayoutOCRExtractor: LayoutOCRExtracting {
    public init() {}

    public func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate] {
        _ = screenshotPath
        return []
    }
}
