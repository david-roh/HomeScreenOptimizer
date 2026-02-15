import Core
import Foundation

public struct UsageSignal: Codable, Hashable, Sendable {
    public var appID: UUID
    public var normalizedScore: Double

    public init(appID: UUID, normalizedScore: Double) {
        self.appID = appID
        self.normalizedScore = normalizedScore
    }
}

public protocol UsageSignalProviding: Sendable {
    func fetchUsageSignals() async throws -> [UsageSignal]
}

public struct StubUsageSignalProvider: UsageSignalProviding {
    public init() {}

    public func fetchUsageSignals() async throws -> [UsageSignal] {
        []
    }
}
