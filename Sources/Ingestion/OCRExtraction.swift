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
    public var boxWidth: Double
    public var boxHeight: Double

    public init(
        text: String,
        confidence: Double,
        centerX: Double,
        centerY: Double,
        boxWidth: Double = 0,
        boxHeight: Double = 0
    ) {
        self.text = text
        self.confidence = confidence
        self.centerX = centerX
        self.centerY = centerY
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
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
        let ocrImage = upscaledForOCRIfNeeded(image)

        let observations = try recognizeTextObservations(in: ocrImage)

        var bestByTextClusters: [String: [LocatedOCRLabelCandidate]] = [:]

        for observation in observations {
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
                centerY: centerY,
                boxWidth: Double(observation.boundingBox.width),
                boxHeight: Double(observation.boundingBox.height)
            )

            let key = normalized.text.lowercased()
            var clusters = bestByTextClusters[key, default: []]
            if let nearbyIndex = clusters.firstIndex(where: { isNearby($0, located) }) {
                if clusters[nearbyIndex].confidence < located.confidence {
                    clusters[nearbyIndex] = located
                }
            } else {
                clusters.append(located)
            }
            bestByTextClusters[key] = clusters
        }

        return bestByTextClusters.values
            .flatMap { $0 }
            .sorted { lhs, rhs in
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

    #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(Vision)
    private func isNearby(_ lhs: LocatedOCRLabelCandidate, _ rhs: LocatedOCRLabelCandidate) -> Bool {
        let dx = lhs.centerX - rhs.centerX
        let dy = lhs.centerY - rhs.centerY
        let distance = sqrt((dx * dx) + (dy * dy))
        return distance <= 0.08
    }

    private func recognizeTextObservations(in image: CGImage) throws -> [VNRecognizedTextObservation] {
        var merged: [VNRecognizedTextObservation] = []
        merged.append(contentsOf: try performTextRecognition(in: image, level: .accurate, minimumTextHeight: 0.006))
        merged.append(contentsOf: try performTextRecognition(in: image, level: .fast, minimumTextHeight: 0.004))
        return merged
    }

    private func performTextRecognition(
        in image: CGImage,
        level: VNRequestTextRecognitionLevel,
        minimumTextHeight: Float
    ) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]
        request.customWords = commonAppVocabulary
        request.minimumTextHeight = minimumTextHeight

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    private var commonAppVocabulary: [String] {
        [
            "Safari", "Messages", "Phone", "Mail", "Maps", "Calendar", "Photos", "Files", "Watch",
            "Fitness", "Contacts", "Preview", "Utilities", "News", "Health", "Wallet", "Settings",
            "Camera", "Reminders", "Music", "Weather", "Clock", "Notes", "FaceTime", "App Store",
            "Home", "Podcasts", "Stocks", "Translate", "Shortcuts", "Voice Memos", "Freeform"
        ]
    }

    private func upscaledForOCRIfNeeded(_ image: CGImage) -> CGImage {
        let targetWidth = 1080.0
        let currentWidth = Double(image.width)
        guard currentWidth > 0 else {
            return image
        }

        let scale = min(3.0, max(1.0, targetWidth / currentWidth))
        guard scale > 1.01 else {
            return image
        }

        let width = Int(round(Double(image.width) * scale))
        let height = Int(round(Double(image.height) * scale))
        guard width > image.width, height > image.height else {
            return image
        }

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = image.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let alphaInfo = bitmapInfo != 0 ? CGBitmapInfo(rawValue: bitmapInfo) : CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: alphaInfo.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
    #endif
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
