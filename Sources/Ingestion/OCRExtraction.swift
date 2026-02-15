import Foundation

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

public struct StubLayoutOCRExtractor: LayoutOCRExtracting {
    public init() {}

    public func extractAppLabels(from screenshotPath: String) async throws -> [OCRLabelCandidate] {
        _ = screenshotPath
        return []
    }
}
