import Foundation

public enum PersistenceError: Error, Equatable {
    case notFound
    case failedToDecode
    case failedToEncode
}
