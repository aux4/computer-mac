import Foundation

// MARK: - action log + stop switch
//
// Every command that sends input or changes state appends one JSON line to the action log
// (~/Library/Logs/aux4-computer-mac/actions.jsonl, rotated at 10MB), and refuses to run while the
// stop switch is on (a STOP file in ~/Library/Application Support/aux4-computer-mac, or
// AUX4_COMPUTER_MAC_STOP=1). Read-only commands are never blocked.
//
// AUX4_COMPUTER_MAC_LOG_FILE, AUX4_COMPUTER_MAC_STOP_FILE and AUX4_COMPUTER_MAC_LOG_MAX_BYTES
// relocate/resize them (used by the package's tests).

func envValue(_ name: String) -> String {
    return ProcessInfo.processInfo.environment[name] ?? ""
}

func actionLogPath() -> String {
    let custom = envValue("AUX4_COMPUTER_MAC_LOG_FILE")
    if !custom.isEmpty { return custom }
    return NSHomeDirectory() + "/Library/Logs/aux4-computer-mac/actions.jsonl"
}

func stopFilePath() -> String {
    let custom = envValue("AUX4_COMPUTER_MAC_STOP_FILE")
    if !custom.isEmpty { return custom }
    return NSHomeDirectory() + "/Library/Application Support/aux4-computer-mac/STOP"
}

func actionLogMaxBytes() -> Int {
    if let n = Int(envValue("AUX4_COMPUTER_MAC_LOG_MAX_BYTES")), n > 0 { return n }
    return 10 * 1024 * 1024
}

// The stop switch: why input is refused right now, or nil when it's allowed.
func stopReason() -> String? {
    if envValue("AUX4_COMPUTER_MAC_STOP") == "1" { return "AUX4_COMPUTER_MAC_STOP=1 is set" }
    if FileManager.default.fileExists(atPath: stopFilePath()) { return "\(stopFilePath()) exists" }
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

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var entry: [String: Any] = [
            "ts": formatter.string(from: start),
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
    try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
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
    // Newest entries are at the end; when the current file has fewer than asked, the rotated one
    // supplies the older ones.
    for file in [path, path + ".1"] {
        guard lines.count < limit, let text = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
        let fileLines = text.split(separator: "\n").map(String.init)
        lines = Array(fileLines.suffix(limit - lines.count)) + lines
    }
    var entries: [Any] = []
    for line in lines {
        if let data = line.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) {
            entries.append(obj)
        }
    }
    var out: [String: Any] = ["path": path, "entries": entries, "stopped": stopReason() != nil]
    if let reason = stopReason() { out["stopReason"] = reason }
    printJSON(out)
}

func cmdStop() {
    let path = stopFilePath()
    let fm = FileManager.default
    try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    let formatter = ISO8601DateFormatter()
    let content = "stopped at \(formatter.string(from: Date())) by 'aux4 computer mac stop'; 'aux4 computer mac resume' removes this file\n"
    guard fm.createFile(atPath: path, contents: content.data(using: .utf8)) else {
        fail("Could not create the stop file at \(path)")
    }
    appendActionLog(["ts": formatter.string(from: Date()), "command": "stop", "args": [:], "result": "ok"])
    printJSON(["stopped": true, "file": path])
}

func cmdResume() {
    let path = stopFilePath()
    let fm = FileManager.default
    if fm.fileExists(atPath: path) {
        do { try fm.removeItem(atPath: path) } catch {
            fail("Could not remove the stop file at \(path): \(error.localizedDescription)")
        }
    }
    appendActionLog(["ts": ISO8601DateFormatter().string(from: Date()), "command": "resume", "args": [:], "result": "ok"])
    var out: [String: Any] = ["stopped": false, "file": path]
    // The environment switch can't be undone from here: say so instead of claiming input is allowed.
    if envValue("AUX4_COMPUTER_MAC_STOP") == "1" {
        out["stopped"] = true
        out["stopReason"] = "AUX4_COMPUTER_MAC_STOP=1 is set; unset it to allow input"
    }
    printJSON(out)
}

// guardStopSwitch refuses an input/state command while the stop switch is on.
func guardStopSwitch(_ command: String) {
    guard let reason = stopReason() else { return }
    failJSON([
        "error": "Stopped: aux4 computer mac is not sending input or changing state (\(reason)). Run 'aux4 computer mac resume' to allow it again.",
        "stopped": true,
        "command": command.replacingOccurrences(of: "-", with: " ")
    ])
}
