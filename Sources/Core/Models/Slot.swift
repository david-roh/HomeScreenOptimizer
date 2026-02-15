import Foundation

public enum SlotType: String, Codable, Sendable {
    case app
    case dock
    case folder
    case widgetLocked
    case holding
}

public struct Slot: Codable, Hashable, Sendable {
    public var page: Int
    public var row: Int
    public var column: Int
    public var type: SlotType

    public init(page: Int, row: Int, column: Int, type: SlotType = .app) {
        self.page = page
        self.row = row
        self.column = column
        self.type = type
    }
}
