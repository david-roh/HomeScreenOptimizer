import Foundation

public struct DataClassPermission: Codable, Hashable, Sendable {
    public var name: String
    public var isEnabled: Bool

    public init(name: String, isEnabled: Bool) {
        self.name = name
        self.isEnabled = isEnabled
    }
}

public struct PrivacyPolicyState: Codable, Hashable, Sendable {
    public var localOnlyProcessing: Bool
    public var permissions: [DataClassPermission]

    public init(localOnlyProcessing: Bool = true, permissions: [DataClassPermission] = []) {
        self.localOnlyProcessing = localOnlyProcessing
        self.permissions = permissions
    }
}
