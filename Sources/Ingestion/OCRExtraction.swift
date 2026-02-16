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

public struct LocatedOCRLabelCandidate: Codable, Hashable, Sendable {
    public var text: String
    public var confidence: Double
    public var centerX: Double
    public var centerY: Double

    public init(text: String, confidence: Double, centerX: Double, centerY: Double) {
        self.text = text
        self.confidence = confidence
        self.centerX = centerX
        self.centerY = centerY
    }
}

public protocol LayoutOCRExtracting: Sendable {
    func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate]
}

public protocol LayoutOCRLocating: Sendable {
    func extractLocatedAppLabels(from screenshotPath: String) async throws -> [LocatedOCRLabelCandidate]
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

public struct VisionLayoutOCRExtractor: LayoutOCRExtracting, LayoutOCRLocating {
    private let postProcessor: OCRPostProcessor

    public init(postProcessor: OCRPostProcessor = OCRPostProcessor()) {
        self.postProcessor = postProcessor
    }

    public func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate] {
        let located = try await extractLocatedAppLabels(from: screenshotPath)
        return located.map { OCRLabelCandidate(text: $0.text, confidence: $0.confidence) }
    }

    public func extractLocatedAppLabels(from screenshotPath: String) async throws -> [LocatedOCRLabelCandidate] {
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

        var bestByText: [String: LocatedOCRLabelCandidate] = [:]

        for observation in request.results ?? [] {
            guard let top = observation.topCandidates(1).first else {
                continue
            }

            let cleaned = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                continue
            }

            let rawCandidate = OCRLabelCandidate(text: cleaned, confidence: Double(top.confidence))
            guard let normalized = postProcessor.normalize(rawCandidate) else {
                continue
            }

            let centerX = Double(observation.boundingBox.midX)
            let centerY = Double(observation.boundingBox.midY)
            let located = LocatedOCRLabelCandidate(
                text: normalized.text,
                confidence: normalized.confidence,
                centerX: centerX,
                centerY: centerY
            )

            let key = normalized.text.lowercased()
            if let existing = bestByText[key], existing.confidence >= located.confidence {
                continue
            }

            bestByText[key] = located
        }

        return bestByText.values.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.text < rhs.text
            }

            return lhs.confidence > rhs.confidence
        }
        #else
        _ = screenshotPath
        throw OCRExtractionError.visionUnavailable
        #endif
    }
}

public struct StubLayoutOCRExtractor: LayoutOCRExtracting, LayoutOCRLocating {
    public init() {}

    public func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate] {
        _ = screenshotPath
        return []
    }

    public func extractLocatedAppLabels(from screenshotPath: String) async throws -> [LocatedOCRLabelCandidate] {
        _ = screenshotPath
        return []
    }
}
