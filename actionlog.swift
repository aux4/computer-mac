import Foundation

// MARK: - action log + stop switch
//
// The stop switch and the action log are SHARED with aux4/computer (the core) and every other
// computer provider (contract v1), so a direct `aux4 computer mac ...` call can't bypass a stop
// turned on with `aux4 computer stop`:
//
//   state dir   ~/Library/Application Support/aux4-computer  (env AUX4_COMPUTER_STATE_DIR overrides it)
//   stop switch <state dir>/STOP, or env AUX4_COMPUTER_STOP=1
//   action log  <state dir>/actions.jsonl (0600, rotated to actions.jsonl.1 at 10MB)
//
// Every command that sends input or changes state appends one JSON line to the log and refuses to
// run while the switch is on. Read-only commands are never blocked.
//
// For one release the 0.6 locations keep working: the old STOP file
// (~/Library/Application Support/aux4-computer-mac/STOP) and AUX4_COMPUTER_MAC_STOP=1 still stop
// input, and `log` still reads the old ~/Library/Logs/aux4-computer-mac/actions.jsonl. When
// AUX4_COMPUTER_STATE_DIR is set, only that directory is used (tests never touch the real switch).
//
// AUX4_COMPUTER_MAC_LOG_FILE, AUX4_COMPUTER_MAC_STOP_FILE and AUX4_COMPUTER_MAC_LOG_MAX_BYTES
// (AUX4_COMPUTER_LOG_MAX_BYTES) relocate/resize them (used by the package's tests).

func envValue(_ name: String) -> String {
    return ProcessInfo.processInfo.environment[name] ?? ""
}

// envSeam reads a contract environment seam AUX4_COMPUTER_<name>, or its 0.6 alias
// AUX4_COMPUTER_MAC_<name> (DENY_PERMISSIONS, DRY_RUN, SIMULATE_BACKGROUND, STOP, ...).
func envSeam(_ name: String) -> String {
    let generic = envValue("AUX4_COMPUTER_" + name)
    if !generic.isEmpty { return generic }
    return envValue("AUX4_COMPUTER_MAC_" + name)
}

let providerName = "mac"

func stateDirOverridden() -> Bool {
    return !envValue("AUX4_COMPUTER_STATE_DIR").isEmpty
}

// sharedStateDir is the directory the core and every provider share for STOP and actions.jsonl.
func sharedStateDir() -> String {
    let custom = envValue("AUX4_COMPUTER_STATE_DIR")
    if !custom.isEmpty { return custom }
    return NSHomeDirectory() + "/Library/Application Support/aux4-computer"
}

let legacyStopFile = NSHomeDirectory() + "/Library/Application Support/aux4-computer-mac/STOP"
let legacyLogFile = NSHomeDirectory() + "/Library/Logs/aux4-computer-mac/actions.jsonl"

func actionLogPath() -> String {
    if stateDirOverridden() { return sharedStateDir() + "/actions.jsonl" }
    let custom = envValue("AUX4_COMPUTER_MAC_LOG_FILE")
    if !custom.isEmpty { return custom }
    return sharedStateDir() + "/actions.jsonl"
}

// legacyLogPaths are older logs `log` still reads (0.6 wrote to its own directory).
func legacyLogPaths() -> [String] {
    if stateDirOverridden() || !envValue("AUX4_COMPUTER_MAC_LOG_FILE").isEmpty { return [] }
    return [legacyLogFile]
}

// stopFilePaths are every STOP file that stops input; `stop` writes them all, `resume` removes them all.
func stopFilePaths() -> [String] {
    if stateDirOverridden() { return [sharedStateDir() + "/STOP"] }
    let custom = envValue("AUX4_COMPUTER_MAC_STOP_FILE")
    if !custom.isEmpty { return [custom] }
    return [sharedStateDir() + "/STOP", legacyStopFile]
}

func stopFilePath() -> String {
    return stopFilePaths()[0]
}

func actionLogMaxBytes() -> Int {
    if let n = Int(envSeam("LOG_MAX_BYTES")), n > 0 { return n }
    return 10 * 1024 * 1024
}

// createPrivateDirectory creates a state/log directory readable only by the user.
func createPrivateDirectory(_ dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true,
                                             attributes: [.posixPermissions: 0o700])
}

// logTimestamp is the log's ISO 8601 UTC timestamp with milliseconds (same format as the core's).
func logTimestamp(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

// The stop switch: why input is refused right now, or nil when it's allowed.
func stopReason() -> String? {
    if envValue("AUX4_COMPUTER_STOP") == "1" { return "AUX4_COMPUTER_STOP=1 is set" }
    if envValue("AUX4_COMPUTER_MAC_STOP") == "1" { return "AUX4_COMPUTER_MAC_STOP=1 is set" }
    for path in stopFilePaths() where FileManager.default.fileExists(atPath: path) {
        return "\(path) exists"
    }
    return nil
}

// Commands that send input or change state, with the names of their positional arguments (the
// order the package's .aux4 passes them). menu and dialog only act with --path / --press.
let actionArgNames: [String: [String]] = [
    "click": ["x", "y", "button", "count", "element", "app", "mode"],
    "move": ["x", "y"],
    "drag": ["x", "y", "toX", "toY"],
    "scroll": ["x", "y", "dx", "dy", "app", "mode"],
    "type": ["text", "delay", "app", "mode"],
    "shortcut": ["keys", "delay", "app", "mode"],
    "clipboard-copy": ["text", "app", "mode"],
    "clipboard-paste": ["text", "app", "mode"],
    "open": ["app", "mode", "file", "url", "wait", "hidden"],
    "focus": ["app"],
    "set": ["app", "element", "value", "checked", "option", "mode"],
    "select": ["app", "all", "text", "occurrence", "start", "length", "element", "mode"],
    "menu": ["app", "path", "depth", "mode"],
    "dialog": ["app", "press", "mode"],
    "window": ["action", "app", "title", "index", "mode"],
    "quit": ["app", "force", "timeout"],
    "hide": ["app"],
    "unhide": ["app"]
]

// window's arguments depend on its action (move: x y, resize: width height, fullscreen: enabled).
func actionArgNamesFor(_ command: String, _ args: [String]) -> [String] {
    if command == "window" { return windowArgNames(argAt(args, 0).lowercased()) }
    return actionArgNames[command] ?? []
}

func isActionInvocation(_ command: String, _ args: [String]) -> Bool {
    guard actionArgNames[command] != nil else { return false }
    if command == "menu" { return !argAt(args, 1).isEmpty }
    if command == "dialog" { return !argAt(args, 1).isEmpty }
    if command == "window" { return argAt(args, 0).lowercased() != "list" }
    return true
}

// Text the user typed or pasted can be private: the log keeps a short prefix and the length.
func truncatedForLog(_ s: String, limit: Int = 16) -> String {
    if s.count <= limit { return s }
    return String(s.prefix(limit)) + "… (\(s.count) chars)"
}

final class ActionLog: @unchecked Sendable {
    static let shared = ActionLog()
    private let lock = NSLock()
    private var command: String? = nil
    private var args: [String: Any] = [:]
    private var start = Date()

    func begin(_ command: String, _ positional: [String]) {
        var named: [String: Any] = [:]
        for (i, name) in actionArgNamesFor(command, positional).enumerated() {
            let v = argAt(positional, i)
            if v.isEmpty { continue }
            named[name] = (name == "text" || name == "value") ? truncatedForLog(v) : v
        }
        lock.lock()
        var logged = command.replacingOccurrences(of: "-", with: " ")
        if command == "window" { logged += " " + argAt(positional, 0).lowercased() }
        self.command = logged
        self.args = named
        self.start = Date()
        lock.unlock()
    }

    // finish writes the entry once: on the command's JSON output or on its error.
    func finish(result: [String: Any]?, error: [String: Any]?) {
        lock.lock()
        guard let command = command else { lock.unlock(); return }
        self.command = nil
        let args = self.args
        let start = self.start
        lock.unlock()
        let out = result ?? error ?? [:]
        // A dry run never touches anything: nothing to record.
        if out["dryRun"] as? Bool == true { return }

        var entry: [String: Any] = [
            "ts": logTimestamp(start),
            "provider": providerName,
            "command": command,
            "args": args,
            "ms": Int(Date().timeIntervalSince(start) * 1000)
        ]
        if let app = (out["app"] as? String) ?? (args["app"] as? String) { entry["app"] = app }
        if let mode = out["mode"] as? String { entry["mode"] = mode }
        if result != nil {
            entry["result"] = "ok"
            if let method = (out["method"] as? String) ?? (out["action"] as? String) { entry["method"] = method }
            if let reason = out["fallbackReason"] as? String { entry["fallbackReason"] = reason }
        } else {
            entry["result"] = "error"
            entry["error"] = truncatedForLog((out["error"] as? String) ?? "unknown error", limit: 300)
        }
        appendActionLog(entry)
    }
}

func appendActionLog(_ entry: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys, .withoutEscapingSlashes]) else { return }
    let path = actionLogPath()
    let fm = FileManager.default
    createPrivateDirectory((path as NSString).deletingLastPathComponent)
    // Rotate: the current file becomes actions.jsonl.1 (replacing an older one).
    if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? NSNumber,
       size.intValue + data.count + 1 > actionLogMaxBytes() {
        let rotated = path + ".1"
        try? fm.removeItem(atPath: rotated)
        try? fm.moveItem(atPath: path, toPath: rotated)
    }
    // O_APPEND keeps concurrent writers from interleaving within a line.
    let fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o600)
    if fd < 0 { return }
    var line = data
    line.append(0x0A)
    line.withUnsafeBytes { buf in _ = write(fd, buf.baseAddress, buf.count) }
    fchmod(fd, 0o600)
    close(fd)
}

func cmdLog(_ args: [String]) {
    let limitArg = argAt(args, 0)
    let limit = limitArg.isEmpty ? 20 : (Int(limitArg) ?? -1)
    guard limit > 0 else {
        fail("Invalid --limit '\(limitArg)': use a positive number")
    }
    let path = actionLogPath()
    var lines: [String] = []
    var paths: [String] = []
    // Newest entries are at the end; when the current file has fewer than asked, the rotated one
    // and then the 0.6 log (all older) supply the older ones.
    for base in [path] + legacyLogPaths() {
        for file in [base, base + ".1"] {
            guard let text = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            paths.append(file)
            guard lines.count < limit else { continue }
            let fileLines = text.split(separator: "\n").map(String.init)
            lines = Array(fileLines.suffix(limit - lines.count)) + lines
        }
    }
    var entries: [Any] = []
    for line in lines {
        if let data = line.data(using: .utf8), var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if obj["provider"] == nil { obj["provider"] = providerName }
            entries.append(obj)
        }
    }
    var out: [String: Any] = ["path": path, "paths": paths, "entries": entries, "stopped": stopReason() != nil]
    if let reason = stopReason() { out["stopReason"] = reason }
    printJSON(out)
}

func cmdStop() {
    let paths = stopFilePaths()
    let fm = FileManager.default
    let content = "stopped at \(logTimestamp()) by 'aux4 computer mac stop'; 'aux4 computer resume' removes this file\n"
    for path in paths {
        createPrivateDirectory((path as NSString).deletingLastPathComponent)
        guard fm.createFile(atPath: path, contents: content.data(using: .utf8), attributes: [.posixPermissions: 0o600]) else {
            fail("Could not create the stop file at \(path)")
        }
    }
    appendActionLog(["ts": logTimestamp(), "provider": providerName, "command": "stop", "args": [:], "result": "ok"])
    printJSON(["stopped": true, "file": paths[0], "files": paths])
}

func cmdResume() {
    let paths = stopFilePaths()
    let fm = FileManager.default
    for path in paths where fm.fileExists(atPath: path) {
        do { try fm.removeItem(atPath: path) } catch {
            fail("Could not remove the stop file at \(path): \(error.localizedDescription)")
        }
    }
    appendActionLog(["ts": logTimestamp(), "provider": providerName, "command": "resume", "args": [:], "result": "ok"])
    var out: [String: Any] = ["stopped": false, "file": paths[0], "files": paths]
    // The environment switch can't be undone from here: say so instead of claiming input is allowed.
    if let reason = stopReason() {
        out["stopped"] = true
        out["stopReason"] = reason + "; unset it to allow input"
    }
    printJSON(out)
}

// guardStopSwitch refuses an input/state command while the stop switch is on.
func guardStopSwitch(_ command: String) {
    guard let reason = stopReason() else { return }
    failJSON([
        "error": "Stopped: aux4 computer mac is not sending input or changing state (\(reason)). Run 'aux4 computer resume' (or 'aux4 computer mac resume') to allow it again.",
        "stopped": true,
        "command": command.replacingOccurrences(of: "-", with: " ")
    ])
}
