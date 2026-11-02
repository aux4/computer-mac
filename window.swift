import AppKit
import ApplicationServices
import Foundation

// MARK: - window (list / move / resize / minimize / restore / close / fullscreen / raise)
//
// Positional arguments: <action> <app> <title> <index> <mode> [action-specific...]
//   move: <x> <y>   resize: <width> <height>   fullscreen: <enabled>

let windowActions = ["list", "move", "resize", "minimize", "restore", "close", "fullscreen", "raise"]

func windowArgNames(_ action: String) -> [String] {
    let base = ["action", "app", "title", "index", "mode"]
    switch action {
    case "move": return base + ["x", "y"]
    case "resize": return base + ["width", "height"]
    case "fullscreen": return base + ["enabled"]
    default: return base
    }
}

func windowDescriptor(_ w: AXUIElement, axApp: AXUIElement, index: Int?) -> [String: Any] {
    var e: [String: Any] = ["title": axString(w, kAXTitleAttribute) ?? ""]
    if let i = index { e["index"] = i }
    if let ref = axRefOf(w, in: axApp) { e["ref"] = ref }
    if let f = axFrame(w) { e["frame"] = frameJSON(f) }
    e["minimized"] = axBool(w, kAXMinimizedAttribute) ?? false
    e["fullscreen"] = axBool(w, "AXFullScreen") ?? false
    if axBool(w, kAXMainAttribute) == true { e["main"] = true }
    if axBool(w, kAXFocusedAttribute) == true { e["focused"] = true }
    let sub = axSubrole(w)
    if !sub.isEmpty && sub != "AXStandardWindow" { e["subrole"] = sub }
    return e
}

// pickWindow selects the window to act on: --index (position in 'window list'), --title (exact,
// then contained, case-insensitive), or the app's main window (then focused, then first).
func pickWindow(_ target: Target, title: String, indexArg: String) -> (AXUIElement, Int) {
    let windows = axWindows(target.axApp)
    if windows.isEmpty { fail("\(target.name) has no windows") }
    if !indexArg.isEmpty {
        guard let i = Int(indexArg), i >= 0 else { fail("Invalid --index '\(indexArg)': use 0 or more") }
        guard i < windows.count else {
            fail("No window at --index \(i): \(target.name) has \(windows.count) window\(windows.count == 1 ? "" : "s")")
        }
        return (windows[i], i)
    }
    if !title.isEmpty {
        let want = normalizeTitle(title)
        let titles = windows.map { normalizeTitle(axString($0, kAXTitleAttribute) ?? "") }
        if let i = titles.firstIndex(of: want) ?? titles.firstIndex(where: { $0.contains(want) }) {
            return (windows[i], i)
        }
        let list = windows.map { "'\(axString($0, kAXTitleAttribute) ?? "")'" }.joined(separator: ", ")
        fail("No window titled '\(title)' in \(target.name). Windows: \(list)")
    }
    for attr in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
        if let w = axElementAttr(target.axApp, attr), let i = windows.firstIndex(where: { CFEqual($0, w) }) {
            return (w, i)
        }
    }
    let i = windows.firstIndex(where: { axSubrole($0) == "AXStandardWindow" }) ?? 0
    return (windows[i], i)
}

// pollUntil turns the run loop until the condition holds or the time runs out.
@discardableResult
func pollUntil(_ seconds: Double, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if condition() { return true }
        spinRunLoop(until: min(Date().addingTimeInterval(0.05), deadline))
    }
    return condition()
}

// restoreFrontmost puts the user's frontmost app back when the action made another app frontmost.
func restoreFrontmost(_ savedPid: pid_t?, target: pid_t) -> [String: Any]? {
    guard let pid = savedPid, pid != target else { return nil }
    spinRunLoop(0.2)
    if isFrontmost(pid) { return nil }
    guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
    return ["frontmost": bringToFront(app)]
}

func axSetPoint(_ el: AXUIElement, _ attr: String, _ p: CGPoint) -> AXError {
    var point = p
    guard let v = AXValueCreate(.cgPoint, &point) else { return .failure }
    return AXUIElementSetAttributeValue(el, attr as CFString, v)
}

func axSetSize(_ el: AXUIElement, _ attr: String, _ s: CGSize) -> AXError {
    var size = s
    guard let v = AXValueCreate(.cgSize, &size) else { return .failure }
    return AXUIElementSetAttributeValue(el, attr as CFString, v)
}

func requireNumber(_ raw: String, _ name: String) -> Double {
    guard let v = Double(raw) else { fail("Invalid --\(name) '\(raw)': use a number") }
    return v
}

func cmdWindow(_ args: [String]) {
    let action = argAt(args, 0).lowercased()
    let appArg = argAt(args, 1)
    let title = argAt(args, 2)
    let indexArg = argAt(args, 3)
    let mode = parseMode(argAt(args, 4))
    guard windowActions.contains(action) else {
        fail("Invalid window action '\(argAt(args, 0))': use \(windowActions.joined(separator: ", "))")
    }
    if !title.isEmpty && !indexArg.isEmpty { fail("Give either --title or --index, not both") }

    // Validate the action's own flags before touching anything.
    var point = CGPoint.zero
    var width: Double? = nil
    var height: Double? = nil
    var enabled = true
    switch action {
    case "move":
        if argAt(args, 5).isEmpty || argAt(args, 6).isEmpty { fail("--x and --y are required (screen points of the window's top-left corner)") }
        point = CGPoint(x: requireNumber(argAt(args, 5), "x"), y: requireNumber(argAt(args, 6), "y"))
    case "resize":
        if argAt(args, 5).isEmpty && argAt(args, 6).isEmpty { fail("--width or --height is required") }
        if !argAt(args, 5).isEmpty { width = requireNumber(argAt(args, 5), "width") }
        if !argAt(args, 6).isEmpty { height = requireNumber(argAt(args, 6), "height") }
        if (width ?? 1) <= 0 || (height ?? 1) <= 0 { fail("--width and --height must be positive") }
    case "fullscreen":
        enabled = parseBoolFlag(argAt(args, 5).isEmpty ? "true" : argAt(args, 5), name: "enabled")
    default:
        break
    }
    requireAccessibility()

    var base: [String: Any] = ["action": action]
    if !appArg.isEmpty { base["app"] = appArg }
    switch action {
    case "move": base["requested"] = ["x": point.x, "y": point.y]
    case "resize":
        var r: [String: Any] = [:]
        if let w = width { r["width"] = w }
        if let h = height { r["height"] = h }
        base["requested"] = r
    case "fullscreen": base["requested"] = ["fullscreen": enabled]
    default: break
    }

    if isDryRun() && action != "list" {
        let plan: BackgroundPlan = action == "raise"
            ? .inherentlyForeground("raising a window brings its app to the front")
            : .attempt({ .done([:]) })
        runAction("window \(action)", mode: mode, base: base, plan: plan) { [:] }
        return
    }

    let target = resolveTarget(appArg)
    base["app"] = target.name

    if action == "list" {
        let windows = axWindows(target.axApp)
        let list = windows.prefix(50).enumerated().map { windowDescriptor($0.element, axApp: target.axApp, index: $0.offset) }
        printJSON(["app": target.name, "pid": Int(target.pid), "windows": list])
        return
    }

    let (window, index) = pickWindow(target, title: title, indexArg: indexArg)
    let before = windowDescriptor(window, axApp: target.axApp, index: index)
    base["before"] = before
    let beforeFrame = axFrame(window)

    func settable(_ attr: String, _ what: String) {
        if !axSettable(window, attr) {
            fail("\(target.name)'s window '\(before["title"] as? String ?? "")' can't be \(what) (\(attr) is not settable\(axBool(window, "AXFullScreen") == true ? "; it is full screen" : ""))")
        }
    }

    func perform() -> BackgroundOutcome {
        let savedFront = frontmostAppPid()
        var out: [String: Any] = [:]
        switch action {
        case "move":
            settable(kAXPositionAttribute, "moved")
            let r = axSetPoint(window, kAXPositionAttribute, point)
            if r != .success { return .unavailable("setting AXPosition failed (AXError \(r.rawValue))") }
            pollUntil(1.0) { axFrame(window).map { abs($0.minX - point.x) < 1 && abs($0.minY - point.y) < 1 } ?? false }
            out["method"] = "AXPosition"
        case "resize":
            settable(kAXSizeAttribute, "resized")
            let current = beforeFrame?.size ?? .zero
            let size = CGSize(width: width ?? current.width, height: height ?? current.height)
            let r = axSetSize(window, kAXSizeAttribute, size)
            if r != .success { return .unavailable("setting AXSize failed (AXError \(r.rawValue))") }
            pollUntil(1.0) { axFrame(window).map { abs($0.width - size.width) < 1 && abs($0.height - size.height) < 1 } ?? false }
            if let f = axFrame(window), abs(f.width - size.width) >= 1 || abs(f.height - size.height) >= 1 {
                out["note"] = "the app kept the window at \(Int(f.width))x\(Int(f.height)) (its minimum/maximum size)"
            }
            out["method"] = "AXSize"
        case "minimize", "restore":
            let want = action == "minimize"
            settable(kAXMinimizedAttribute, want ? "minimized" : "restored")
            let r = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, want ? kCFBooleanTrue : kCFBooleanFalse)
            if r != .success { return .unavailable("setting AXMinimized failed (AXError \(r.rawValue))") }
            if !pollUntil(3.0, { axBool(window, kAXMinimizedAttribute) == want }) {
                return .unavailable("the window is still \(want ? "not minimized" : "minimized") after 3s")
            }
            out["method"] = "AXMinimized"
        case "fullscreen":
            settable("AXFullScreen", enabled ? "made full screen" : "taken out of full screen")
            let r = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, enabled ? kCFBooleanTrue : kCFBooleanFalse)
            if r != .success { return .unavailable("setting AXFullScreen failed (AXError \(r.rawValue))") }
            if !pollUntil(5.0, { axBool(window, "AXFullScreen") == enabled }) {
                return .unavailable("the window is still \(enabled ? "not full screen" : "full screen") after 5s")
            }
            // The full-screen animation keeps changing the frame for a moment.
            spinRunLoop(1.0)
            out["method"] = "AXFullScreen"
        case "close":
            guard let button = axElementAttr(window, kAXCloseButtonAttribute) else {
                return .unavailable("the window has no close button")
            }
            if axBool(button, kAXEnabledAttribute) == false { return .unavailable("the window's close button is disabled") }
            let r = AXUIElementPerformAction(button, kAXPressAction as CFString)
            if r != .success { return .unavailable("AXPress on the close button failed (AXError \(r.rawValue))") }
            var dialog: DialogInfo? = nil
            let closed = pollUntil(2.0) {
                if !axWindows(target.axApp).contains(where: { CFEqual($0, window) }) { return true }
                dialog = findDialog(target)
                return dialog != nil
            } && dialog == nil
            out["method"] = "AXPress"
            out["closed"] = closed
            if let d = dialog ?? (closed ? nil : findDialog(target)) {
                // An unsaved document asks first: answer with 'dialog --press'.
                out["dialog"] = dialogJSON(d)
                out["note"] = "\(target.name) asked before closing: answer with 'aux4 computer mac dialog --app \"\(target.name)\" --press <button>'"
            }
            if closed {
                out["after"] = NSNull()
                if let restored = restoreFrontmost(savedFront, target: target.pid) { out["restored"] = restored }
                return .done(out)
            }
        default:
            break
        }
        out["after"] = windowDescriptor(window, axApp: target.axApp, index: index)
        if let restored = restoreFrontmost(savedFront, target: target.pid) { out["restored"] = restored }
        return .done(out)
    }

    if action == "raise" {
        runAction("window raise", mode: mode, base: base, plan: .inherentlyForeground("raising a window brings its app to the front"),
                  targetApp: target.app) {
            let r = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            var out: [String: Any] = ["method": r == .success ? "AXRaise" : "AXMain"]
            spinRunLoop(0.2)
            out["after"] = windowDescriptor(window, axApp: target.axApp, index: index)
            out["frontmost"] = isFrontmost(target.pid)
            return out
        }
        return
    }

    // Accessibility moves/resizes/minimizes a window of a background app without activating it. In
    // foreground mode (or if that fails in auto) the app is brought forward and the action repeated.
    runAction("window \(action)", mode: mode, base: base, plan: .attempt(perform), targetApp: target.app) {
        switch perform() {
        case .done(let out): return out
        case .unavailable(let reason): fail("Could not \(action) the window: \(reason)")
        }
    }
}

// MARK: - quit / hide / unhide

// Apps that keep the session working: never quit them.
let neverQuitBundleIds: Set<String> = [
    "com.apple.loginwindow", "com.apple.dock", "com.apple.systemuiserver", "com.apple.WindowManager",
    "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.Spotlight"
]

func processAlive(_ pid: pid_t) -> Bool {
    return kill(pid, 0) == 0 || errno == EPERM
}

func cmdQuit(_ args: [String]) {
    let appArg = argAt(args, 0)
    let force = parseBoolFlag(argAt(args, 1), name: "force")
    let timeoutArg = argAt(args, 2).isEmpty ? "5s" : argAt(args, 2)
    let timeout = parseDuration(timeoutArg, name: "timeout")
    if appArg.isEmpty { fail("--app is required") }
    guard let app = findRunningApp(named: appArg), !app.isTerminated else {
        fail("App not running: \(appArg)")
    }
    let name = app.localizedName ?? appArg
    let bundleId = app.bundleIdentifier ?? ""
    if neverQuitBundleIds.contains(bundleId) {
        fail("Refusing to quit \(name) (\(bundleId)): macOS needs it to keep the session working")
    }
    if force && bundleId == "com.apple.finder" {
        fail("Refusing to force-quit Finder: use 'quit --app Finder' without --force (it relaunches), or leave it running")
    }
    if app.processIdentifier == getpid() { fail("Refusing to quit this process") }
    var out: [String: Any] = ["app": name, "pid": Int(app.processIdentifier), "force": force, "mode": "background",
                              "method": force ? "forceTerminate" : "terminate"]
    if !bundleId.isEmpty { out["bundleId"] = bundleId }
    if isDryRun() {
        out["dryRun"] = true
        printJSON(out)
        return
    }
    let pid = app.processIdentifier
    let target = Target(app: app, name: name, pid: pid, axApp: AXUIElementCreateApplication(pid), explicit: true)
    AXUIElementSetMessagingTimeout(target.axApp, 1.0)
    let hadDialog = findDialog(target).map { $0.element }
    let start = Date()
    let sent = force ? app.forceTerminate() : app.terminate()
    if !sent && processAlive(pid) {
        failJSON(out.merging(["error": "\(name) refused the quit request", "terminated": false]) { $1 })
    }
    var dialog: DialogInfo? = nil
    let deadline = start.addingTimeInterval(timeout)
    while Date() < deadline {
        if !processAlive(pid) { break }
        // An app with unsaved changes answers a quit with a sheet or alert instead of quitting.
        if !force, Date().timeIntervalSince(start) > 0.3, let d = findDialog(target),
           hadDialog.map({ !CFEqual($0, d.element) }) ?? true {
            dialog = d
            break
        }
        spinRunLoop(until: min(Date().addingTimeInterval(0.1), deadline))
    }
    out["waited"] = round2(Date().timeIntervalSince(start))
    if !processAlive(pid) {
        out["terminated"] = true
        printJSON(out)
        return
    }
    out["terminated"] = false
    if let d = dialog {
        out["dialog"] = dialogJSON(d)
        out["note"] = "\(name) asked before quitting: answer with 'aux4 computer mac dialog --app \"\(name)\" --press <button>' (it quits after), or --press Cancel to keep it running"
        printJSON(out)
        return
    }
    var err = out
    err["error"] = "\(name) did not quit within \(timeoutArg)\(force ? "" : ": it may be busy; retry, or use --force true (unsaved changes are lost)")"
    failJSON(err)
}

func appHidden(_ app: NSRunningApplication) -> Bool {
    return axBool(AXUIElementCreateApplication(app.processIdentifier), kAXHiddenAttribute) ?? app.isHidden
}

func cmdHide(_ args: [String], hide: Bool) {
    let appArg = argAt(args, 0)
    let verb = hide ? "hide" : "unhide"
    if appArg.isEmpty { fail("--app is required") }
    requireAccessibility()
    guard let app = findRunningApp(named: appArg), !app.isTerminated else {
        fail("App not running: \(appArg)")
    }
    let name = app.localizedName ?? appArg
    var out: [String: Any] = ["app": name, "pid": Int(app.processIdentifier), "mode": "background"]
    if isDryRun() {
        out["dryRun"] = true
        out["hidden"] = hide
        printJSON(out)
        return
    }
    let pid = app.processIdentifier
    let before = appHidden(app)
    out["before"] = ["hidden": before]
    if before == hide {
        out["hidden"] = hide
        out["changed"] = false
        printJSON(out)
        return
    }
    let savedFront = frontmostAppPid()
    _ = hide ? app.hide() : app.unhide()
    var method = "NSRunningApplication.\(verb)"
    if !pollUntil(1.0, { appHidden(app) == hide }) {
        // Some apps ignore the request from another process: set the accessibility attribute.
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXHiddenAttribute as CFString, hide ? kCFBooleanTrue : kCFBooleanFalse)
        method = "AXHidden"
    }
    if !pollUntil(2.0, { appHidden(app) == hide }) {
        var err = out
        err["error"] = "\(name) is still \(hide ? "visible" : "hidden") after asking it to \(verb)"
        failJSON(err)
    }
    out["hidden"] = hide
    out["changed"] = true
    out["method"] = method
    // Showing an app must not take the front from the user.
    if !hide, let restored = restoreFrontmost(savedFront, target: pid) { out["restored"] = restored }
    printJSON(out)
}
