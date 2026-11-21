import Foundation

/// The app's own folder. Only the updater's log is written here.
public struct AppPaths: Sendable {
    public let supportDirectory: URL

    public init() {
        supportDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/1PassChime", isDirectory: true)
    }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }
}
