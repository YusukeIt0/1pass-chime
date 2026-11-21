import Foundation

// Languages live in `Resources/Languages/<code>.json`, one file per language. Adding a file
// adds the language: nothing in the code lists languages. `LanguageCatalog.problems` (run by
// the unit tests and by `OnePassChime --check-languages` in CI) rejects incomplete files.

/// One supported language and its text.
public struct AppLanguage: Hashable, Sendable, Identifiable {
    /// File name and stored setting value, for example "ja" or "pt-br".
    public let code: String
    /// Name in the language itself, shown in the language picker.
    public let nativeName: String
    /// Locale of the language.
    public let locale: Locale
    /// Position in the language picker.
    public let order: Int
    /// macOS language tags this language serves (see `LanguageCatalog.match`).
    public let matches: [String]
    /// Text by key, with English filled in for any missing key.
    let strings: [String: String]

    public var id: String { code }
    public static func == (a: AppLanguage, b: AppLanguage) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    /// Used only when no language file could be read (keys are shown as text).
    static let placeholder = AppLanguage(code: "en", nativeName: "English", locale: Locale(identifier: "en_US"),
                                         order: 0, matches: ["en"], strings: [:])
}

/// The contents of one language file.
struct LanguageFile: Decodable {
    var code: String
    var name: String
    var locale: String
    var order: Int
    var matches: [String]
    var strings: [String: String]
}

/// Language choice in Settings: automatic, or a language code.
public enum LanguageSetting: Hashable, Codable, Sendable {
    case automatic
    case fixed(String)

    /// Stored form: "automatic" or a language code. Accepts the 0.1.x values "japanese"/"english".
    public init(storedValue: String) {
        switch storedValue {
        case "", "automatic": self = .automatic
        case "japanese": self = .fixed("ja")
        case "english": self = .fixed("en")
        default: self = .fixed(storedValue)
        }
    }

    public var storedValue: String {
        switch self {
        case .automatic: return "automatic"
        case .fixed(let code): return code
        }
    }
}

/// All language files, read once.
public struct LanguageCatalog: Sendable {
    /// In picker order.
    public let languages: [AppLanguage]

    public init(languages: [AppLanguage]) {
        self.languages = languages.sorted { ($0.order, $0.code) < ($1.order, $1.code) }
    }

    public static let fileExtension = "json"
    public static let fallbackCode = "en"

    /// Reads every language file in `directory`. Missing keys fall back to English.
    public static func load(directory: URL) throws -> LanguageCatalog {
        let files = try readFiles(directory).map(\.file)
        let english = files.first { $0.code == fallbackCode }?.strings ?? [:]
        let languages = files.map { f in
            AppLanguage(code: f.code, nativeName: f.name, locale: Locale(identifier: f.locale), order: f.order,
                        matches: f.matches.map { $0.lowercased() }, strings: english.merging(f.strings) { _, own in own })
        }
        return LanguageCatalog(languages: languages)
    }

    /// The app's languages: `Contents/Resources/Languages` in the app bundle, or
    /// `Resources/Languages` above the executable when run from a source checkout.
    public static let main: LanguageCatalog = {
        guard let dir = bundledDirectory(), let c = try? load(directory: dir), !c.languages.isEmpty else {
            return LanguageCatalog(languages: [.placeholder])
        }
        return c
    }()

    public static func bundledDirectory(bundle: Bundle = .main) -> URL? {
        let fm = FileManager.default
        if let r = bundle.resourceURL?.appendingPathComponent("Languages"), fm.fileExists(atPath: r.path) { return r }
        var dir = bundle.executableURL?.deletingLastPathComponent()
        for _ in 0..<6 {
            guard let d = dir else { break }
            let candidate = d.appendingPathComponent("Resources/Languages")
            if fm.fileExists(atPath: candidate.path) { return candidate }
            dir = d.deletingLastPathComponent()
        }
        return nil
    }

    public func language(code: String) -> AppLanguage? { languages.first { $0.code == code } }

    public var english: AppLanguage { language(code: Self.fallbackCode) ?? languages.first ?? .placeholder }

    /// Settings shown in the picker: automatic, then each language.
    public var settings: [LanguageSetting] { [.automatic] + languages.map { .fixed($0.code) } }

    /// A fixed language that has no file (for example after it was removed) acts as automatic.
    /// Automatic picks the first supported macOS preferred language, otherwise English.
    public func resolve(_ setting: LanguageSetting, preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        if case .fixed(let code) = setting, let l = language(code: code) { return l }
        for tag in preferred {
            if let l = match(tag) { return l }
        }
        return english
    }

    /// Matches a macOS language tag against each language's `matches` patterns. A pattern
    /// matches when all its parts appear in the tag with the same base language; the
    /// pattern with the most parts wins ("zh-tw" over "zh"). When the tag names a script
    /// ("zh-Hans-TW"), its region is ignored, so the script decides.
    public func match(_ tag: String) -> AppLanguage? {
        var parts = tag.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        guard let base = parts.first else { return nil }
        if let script = parts.dropFirst().first(where: { $0.count == 4 && $0.allSatisfy(\.isLetter) }) {
            parts = [base, script]
        }
        var best: (AppLanguage, Int)?
        for lang in languages {
            for pattern in lang.matches {
                let p = pattern.split(separator: "-").map(String.init)
                guard p.first == base, p.allSatisfy(parts.contains) else { continue }
                if p.count > best?.1 ?? 0 { best = (lang, p.count) }
            }
        }
        return best?.0
    }

    // MARK: Checks

    private static func readFiles(_ directory: URL) throws -> [(url: URL, file: LanguageFile)] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            // Skips AppleDouble "._x.json" files that archive tools may leave next to the real ones.
            .filter { $0.pathExtension == fileExtension && !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { ($0, try JSONDecoder().decode(LanguageFile.self, from: Data(contentsOf: $0))) }
    }

    /// Everything wrong with the language files, as readable lines; empty when all is well.
    /// Each file must have every key with non-empty text and the same `{placeholders}` as English.
    public static func problems(directory: URL) -> [String] {
        let entries: [(url: URL, file: LanguageFile)]
        do { entries = try readFiles(directory) } catch { return ["cannot read language files: \(error)"] }
        var out: [String] = []
        guard let english = entries.first(where: { $0.file.code == fallbackCode })?.file else {
            return ["\(fallbackCode).\(fileExtension) is missing"]
        }
        let keys = Set(StringKey.allCases.map(\.rawValue))
        var owners: [String: String] = [:]
        var codes = Set<String>()
        for (url, f) in entries {
            let name = url.lastPathComponent
            if url.deletingPathExtension().lastPathComponent != f.code { out.append("\(name): code \"\(f.code)\" does not match the file name") }
            if !codes.insert(f.code).inserted { out.append("\(name): duplicate code \(f.code)") }
            if f.name.trimmingCharacters(in: .whitespaces).isEmpty { out.append("\(name): name is empty") }
            if f.locale.isEmpty { out.append("\(name): locale is empty") }
            if f.matches.isEmpty { out.append("\(name): matches is empty") }
            for m in f.matches.map({ $0.lowercased() }) {
                if let other = owners[m], other != f.code { out.append("\(name): match \"\(m)\" is also used by \(other)") }
                owners[m] = f.code
            }
            for k in keys.subtracting(f.strings.keys).sorted() { out.append("\(name): missing \"\(k)\"") }
            for k in Set(f.strings.keys).subtracting(keys).sorted() { out.append("\(name): unknown key \"\(k)\"") }
            for (k, v) in f.strings.sorted(by: { $0.key < $1.key }) where keys.contains(k) {
                if v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append("\(name): \"\(k)\" is empty"); continue }
                let expected = placeholders(english.strings[k] ?? "")
                let found = placeholders(v)
                if found != expected {
                    out.append("\(name): \"\(k)\" has placeholders \(found.sorted()) but English has \(expected.sorted())")
                }
            }
        }
        return out
    }

    static func placeholders(_ s: String) -> Set<String> {
        var found = Set<String>()
        var rest = s[...]
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            found.insert(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return found
    }
}


/// Keys of all user-facing text. Each language file has exactly these keys.
public enum StringKey: String, CaseIterable, Sendable {
    case statusWatching
    case statusWaiting
    case statusNotRunning
    case statusPaused
    case silenceThisRequest
    case playSound
    case pauseSounds
    case resumeSounds
    case settings
    case quit
    case sound
    case builtInChime
    case chooseFile
    case fileUnavailable
    case volume
    case whenRequestAppears
    case playOnce
    case repeatUntilApproved
    case repeatEvery
    case seconds
    case general
    case language
    case automatic
    case launchAtLogin
    case launchAtLoginNeedsApproval
    case updateAvailable
    case updateNow
    case updating
    case updateFailed
    case upToDate
    case checkingForUpdates
    case checkForUpdates
    case version
    case howItWorks
    case unofficial
}

/// All user-facing text in one language. Language changes apply without a restart.
public struct Strings: Sendable {
    public let lang: AppLanguage
    public init(_ lang: AppLanguage) { self.lang = lang }

    /// Text for a key; the key itself if no file had it.
    public subscript(_ key: StringKey) -> String { lang.strings[key.rawValue] ?? key.rawValue }

    /// Text with `{name}` placeholders filled.
    public func callAsFunction(_ key: StringKey, _ values: [String: String]) -> String {
        values.reduce(self[key]) { s, kv in s.replacingOccurrences(of: "{\(kv.key)}", with: kv.value) }
    }

    public func seconds(_ value: Double) -> String {
        self(.seconds, ["count": value.rounded() == value ? String(Int(value)) : String(value)])
    }

    public func updateAvailable(_ version: String) -> String { self(.updateAvailable, ["version": version]) }
}
