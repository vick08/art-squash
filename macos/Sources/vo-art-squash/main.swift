import AppKit
import Foundation

// MARK: - Configuration

/// Applies the entries to every application.
let anyApplication = "SCRAnyApplication"

/// Box Drawing (U+2500–257F) and Block Elements (U+2580–259F).
let squashedScalars: [Unicode.Scalar] = (0x2500...0x259F).compactMap(Unicode.Scalar.init)
let squashedStrings = Set(squashedScalars.map { String(Character($0)) })

/// VoiceOver accepts a NUL substitution and speaks nothing for it.
let nullReplacement = "\u{0}"

let pronunciationPrefix = "custom.pronunciation."
let voiceOverBundleID = "com.apple.VoiceOver"
let voiceOverAppPath = "/System/Library/CoreServices/VoiceOver.app"

let defaultPrefsDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/group.com.apple.VoiceOver/Library/Preferences/com.apple.VoiceOver4")
let backupRoot = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/vo-art-squash/backups")

// MARK: - Errors / output

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func printErr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

// MARK: - Options

struct Options {
    var command = ""
    var prefsDir = defaultPrefsDir
    var dryRun = false
    var force = false
    var restartVoiceOver = false
}

let usage = """
    Usage: vo-art-squash <command> [options]

    Silences decorative box-drawing and block characters (U+2500–259F) in
    all apps by adding VoiceOver pronunciation entries that replace each
    character with a NUL (spoken as nothing).

    Commands:
      install     Add entries (skips any that already exist)
      remove      Remove entries previously added by this tool
      list        Show how many squash entries are installed

    Options:
      --restart-voiceover    Quit VoiceOver, write changes, then relaunch it
      --force                Write even while VoiceOver is running (it may overwrite the changes)
      --dry-run              Show what would change without writing
      --prefs-dir <path>     VoiceOver4 preferences directory (for testing)
      -h, --help             Show this help
    """

func parseOptions(_ args: [String]) throws -> Options {
    var opts = Options()
    var it = args.makeIterator()
    while let arg = it.next() {
        switch arg {
        case "-h", "--help":
            print(usage)
            exit(0)
        case "--restart-voiceover": opts.restartVoiceOver = true
        case "--force": opts.force = true
        case "--dry-run": opts.dryRun = true
        case "--prefs-dir":
            guard let path = it.next() else { throw ToolError("--prefs-dir needs a path") }
            opts.prefsDir = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        default:
            if arg.hasPrefix("-") || !opts.command.isEmpty { throw ToolError("Unexpected argument: \(arg)\n\n\(usage)") }
            opts.command = arg
        }
    }
    guard !opts.command.isEmpty else { throw ToolError(usage) }
    return opts
}

// MARK: - VoiceOver process control

func voiceOverIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: voiceOverBundleID).isEmpty
        || run("/usr/bin/pgrep", ["-x", "VoiceOver"]) == 0
}

@discardableResult
func run(_ path: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.2)
    }
    return condition()
}

func quitVoiceOver() throws {
    run("/usr/bin/osascript", ["-e", "tell application \"VoiceOver\" to quit"])
    if waitUntil(timeout: 5, { !voiceOverIsRunning() }) { return }
    run("/usr/bin/killall", ["VoiceOver"])
    guard waitUntil(timeout: 5, { !voiceOverIsRunning() }) else {
        throw ToolError("Could not quit VoiceOver.")
    }
}

func launchVoiceOver() {
    run("/usr/bin/open", [voiceOverAppPath])
}

// MARK: - Preference store

typealias Plist = [String: Any]

struct PrefsStore {
    let dir: URL
    var defaults: Plist
    var journal: Plist

    var defaultURL: URL { dir.appendingPathComponent("default.plist") }
    var journalURL: URL { dir.appendingPathComponent("journal.plist") }

    init(dir: URL) throws {
        self.dir = dir
        defaults = try Self.read(dir.appendingPathComponent("default.plist"))
        let journalURL = dir.appendingPathComponent("journal.plist")
        journal = FileManager.default.fileExists(atPath: journalURL.path) ? try Self.read(journalURL) : [:]
    }

    static func read(_ url: URL) throws -> Plist {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw ToolError("Cannot read \(url.path). Is VoiceOver set up for this user?")
        }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? Plist else {
            throw ToolError("\(url.path) is not a dictionary property list.")
        }
        return plist
    }

    /// Pronunciation entries keyed by their full preference key.
    var pronunciations: [String: Plist] {
        defaults.reduce(into: [:]) { result, pair in
            if pair.key.hasPrefix(pronunciationPrefix), let entry = pair.value as? Plist {
                result[pair.key] = entry
            }
        }
    }

    /// Entries this tool owns: a squashed character replaced with NUL.
    func squashEntries() -> [String: Plist] {
        pronunciations.filter { _, e in
            (e["SCRSubText"] as? String) == nullReplacement
                && squashedStrings.contains(e["SCRSearchText"] as? String ?? "")
        }
    }

    func backup() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        var dest = backupRoot.appendingPathComponent(stamp)
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            n += 1
            dest = backupRoot.appendingPathComponent("\(stamp)-\(n)")
        }
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        for url in [defaultURL, journalURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.copyItem(at: url, to: dest.appendingPathComponent(url.lastPathComponent))
        }
        return dest
    }

    /// Binary format is required: XML plists cannot represent U+0000.
    func save() throws {
        for (plist, url) in [(defaults, defaultURL), (journal, journalURL)] {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try data.write(to: url, options: .atomic)
        }
    }

    mutating func touchJournal(_ key: String, at time: TimeInterval) {
        journal[key] = time
    }
}

// MARK: - Commands

func makePrimaryKeys(count: Int, avoiding existing: Set<String>) -> [String] {
    // VoiceOver uses "<seconds since 2001>.<microseconds>" as primary keys.
    var keys: [String] = []
    var micros = Int64(Date().timeIntervalSinceReferenceDate * 1_000_000)
    while keys.count < count {
        let key = String(format: "%lld.%06lld", micros / 1_000_000, micros % 1_000_000)
        if !existing.contains(pronunciationPrefix + key) { keys.append(key) }
        micros += 1
    }
    return keys
}

func install(store: inout PrefsStore) -> Int {
    let existing = Set(store.pronunciations.values.compactMap { e -> String? in
        (e["SCRDomainIdentifier"] as? String) == anyApplication ? e["SCRSearchText"] as? String : nil
    })
    let wanted = squashedScalars.map { String(Character($0)) }.filter { !existing.contains($0) }

    let keys = makePrimaryKeys(count: wanted.count, avoiding: Set(store.defaults.keys))
    let now = Date().timeIntervalSinceReferenceDate
    for (text, pk) in zip(wanted, keys) {
        let key = pronunciationPrefix + pk
        store.defaults[key] = [
            "SCRComponent": "SCROutputSpeechComponent",
            "SCRDomainIdentifier": anyApplication,
            "SCREnabled": "1",
            "SCRIgnoreCase": "0",
            "SCRPrimaryKey": pk,
            "SCRSearchText": text,
            "SCRSubText": nullReplacement,
        ] as Plist
        store.touchJournal(key, at: now)
    }

    print("\(wanted.count) added, \(squashedScalars.count - wanted.count) already present")
    return wanted.count
}

func remove(store: inout PrefsStore) -> Int {
    // Also catches per-app entries left by earlier versions of this tool.
    let doomed = store.squashEntries()
    let now = Date().timeIntervalSinceReferenceDate
    for key in doomed.keys {
        store.defaults.removeValue(forKey: key)
        // Keep the journal entry with a fresh timestamp so the deletion is recorded.
        store.touchJournal(key, at: now)
    }
    print("\(doomed.count) entries removed")
    return doomed.count
}

func list(store: PrefsStore) {
    let byDomain = Dictionary(grouping: store.squashEntries().values) { $0["SCRDomainIdentifier"] as? String ?? "?" }
    if byDomain.isEmpty { print("No squash entries installed.") }
    for (domain, entries) in byDomain.sorted(by: { $0.key < $1.key }) {
        let label = domain == anyApplication ? "All applications" : domain
        print("\(label): \(entries.count) of \(squashedScalars.count) characters silenced")
    }
}

// MARK: - Main

func main() throws {
    let opts = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    switch opts.command {
    case "list":
        list(store: try PrefsStore(dir: opts.prefsDir))
        return
    case "install", "remove":
        break
    default:
        throw ToolError("Unknown command: \(opts.command)\n\n\(usage)")
    }

    let isLivePrefs = opts.prefsDir.standardizedFileURL == defaultPrefsDir.standardizedFileURL
    let mustRestart = !opts.dryRun && isLivePrefs && voiceOverIsRunning()
    if mustRestart && !opts.restartVoiceOver && !opts.force {
        throw ToolError("""
            VoiceOver is running and may overwrite the changes. Re-run with
            --restart-voiceover (quits VoiceOver, writes, relaunches it) or --force.
            """)
    }

    // Quit before reading so VoiceOver can't flush stale prefs over our edit.
    let restart = mustRestart && opts.restartVoiceOver
    if restart { try quitVoiceOver() }
    defer { if restart { launchVoiceOver() } }

    var store = try PrefsStore(dir: opts.prefsDir)
    let changed = opts.command == "install" ? install(store: &store) : remove(store: &store)

    if opts.dryRun {
        print("Dry run: nothing written.")
    } else if changed > 0 {
        let backup = try store.backup()
        try store.save()
        print("Saved. Backup of previous prefs: \(backup.path)")
    }
}

do {
    try main()
} catch {
    printErr("error: \(error)")
    exit(1)
}
