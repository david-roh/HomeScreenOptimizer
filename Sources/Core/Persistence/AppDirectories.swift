import Foundation

public enum AppDirectories {
    public static func dataDirectory(appName: String = "HomeScreenOptimizer") throws -> URL {
        #if os(macOS)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #else
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #endif

        guard let base else {
            throw PersistenceError.notFound
        }

        let target = base.appendingPathComponent(appName, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }
}
