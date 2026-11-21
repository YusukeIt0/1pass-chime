import Foundation

/// The sound to play: the built-in chime, a macOS alert sound by name, or a file the user chose.
public enum SoundChoice: Hashable, Sendable {
    case builtIn
    case system(String)
    case file(String)

    /// Stored form: "builtin", "system:<name>" or "file:<path>". Anything else is the built-in chime.
    public init(storedValue: String) {
        if storedValue.hasPrefix("system:"), storedValue.count > 7 {
            self = .system(String(storedValue.dropFirst(7)))
        } else if storedValue.hasPrefix("file:"), storedValue.count > 5 {
            self = .file(String(storedValue.dropFirst(5)))
        } else {
            self = .builtIn
        }
    }

    public var storedValue: String {
        switch self {
        case .builtIn: return "builtin"
        case .system(let name): return "system:\(name)"
        case .file(let path): return "file:\(path)"
        }
    }
}

/// macOS alert sounds: /System/Library/Sounds and ~/Library/Sounds.
public enum SystemSounds {
    public static let fileExtensions: Set<String> = ["aiff", "aif", "wav", "caf", "m4a", "mp3"]

    public static var directories: [URL] {
        [URL(fileURLWithPath: "/System/Library/Sounds"),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Sounds")]
    }

    /// Sound names (file names without extension), sorted, without duplicates.
    public static func names(in directories: [URL] = directories) -> [String] {
        var names = Set<String>()
        for dir in directories {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for f in files where fileExtensions.contains(f.pathExtension.lowercased()) {
                names.insert(f.deletingPathExtension().lastPathComponent)
            }
        }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public static func url(named name: String, in directories: [URL] = directories) -> URL? {
        for dir in directories {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            if let f = files.first(where: {
                $0.deletingPathExtension().lastPathComponent == name && fileExtensions.contains($0.pathExtension.lowercased())
            }) { return f }
        }
        return nil
    }
}
