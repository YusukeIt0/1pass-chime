import AppKit
import ChimeCore

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    // CI: checks that the language files shipped in this build are complete.
    if args.contains("--check-languages") {
        guard let dir = LanguageCatalog.bundledDirectory() else {
            print("language files not found")
            exit(1)
        }
        let problems = LanguageCatalog.problems(directory: dir)
        problems.forEach { print($0) }
        print("\(LanguageCatalog.main.languages.count) languages in \(dir.path), \(problems.count) problems")
        exit(problems.isEmpty ? 0 : 1)
    }
    // Developer aid: writes the app icon and menu bar images as PNGs into a folder.
    if let i = args.firstIndex(of: "--render-icons"), i + 1 < args.count {
        exit(IconExport.run(outputDir: args[i + 1]))
    }
    // Developer aid: prints what the watcher sees, once per change, for `seconds` (default 60).
    if let i = args.firstIndex(of: "--watch") {
        let seconds = (i + 1 < args.count ? Double(args[i + 1]) : nil) ?? 60
        WatchCheck.run(seconds: seconds)
        exit(0)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
