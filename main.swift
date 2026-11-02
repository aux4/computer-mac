import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import Vision

// MARK: - JSON helpers

func printJSON(_ obj: Any) {
    guard JSONSerialization.isValidJSONObject(obj) else {
        FileHandle.standardOutput.write("{\"error\":\"internal: invalid JSON object\"}\n".data(using: .utf8)!)
        return
    }
    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    } else {
        print("{\"error\":\"internal: failed to encode JSON\"}")
    }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    guard let data = try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys, .withoutEscapingSlashes]) else {
        FileHandle.standardError.write("{\"error\":\"internal: failed to encode error\"}\n".data(using: .utf8)!)
        exit(code)
    }
    FileHandle.standardError.write(data)
    FileHandle.standardError.write("\n".data(using: .utf8)!)
    exit(code)
}

func argAt(_ args: [String], _ index: Int) -> String {
    return index < args.count ? args[index] : ""
}

func parseDouble(_ s: String, default def: Double = 0) -> Double {
    return Double(s) ?? def
}

func parseInt(_ s: String, default def: Int = 0) -> Int {
    return Int(s) ?? def
}

// MARK: - Permission helpers

func accessibilityGranted() -> Bool {
    if permissionsDeniedForTesting() { return false }
    return AXIsProcessTrusted()
}

// AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 makes every permission check fail, so the
// missing-permission error paths can be tested without touching the real screen.
func permissionsDeniedForTesting() -> Bool {
    return ProcessInfo.processInfo.environment["AUX4_COMPUTER_MAC_DENY_PERMISSIONS"] == "1"
}

func screenRecordingGranted() -> Bool {
    if permissionsDeniedForTesting() { return false }
    return CGPreflightScreenCaptureAccess()
}

func requireAccessibility() {
    // A dry run never touches the UI, so it doesn't need the permission (unless denial is simulated).
    if ProcessInfo.processInfo.environment["AUX4_COMPUTER_MAC_DRY_RUN"] == "1" && !permissionsDeniedForTesting() { return }
    if !accessibilityGranted() {
        fail("Accessibility permission not granted. Open System Settings > Privacy & Security > Accessibility and enable this terminal/app, then re-run. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\"")
    }
}

func requireScreenRecording() {
    if !screenRecordingGranted() {
        fail("Screen Recording permission not granted. Open System Settings > Privacy & Security > Screen Recording and enable this terminal/app, then re-run. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\"")
    }
}

// MARK: - permissions command

func cmdPermissions() {
    let ax = accessibilityGranted()
    let sr = screenRecordingGranted()
    printJSON([
        "accessibility": [
            "granted": ax,
            "guidance": ax ? "Accessibility access is granted." : "Open System Settings > Privacy & Security > Accessibility and enable this terminal/app. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\""
        ],
        "screenRecording": [
            "granted": sr,
            "guidance": sr ? "Screen Recording access is granted." : "Open System Settings > Privacy & Security > Screen Recording and enable this terminal/app. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\""
        ]
    ])
}

// MARK: - cursor / screen

func cmdCursor() {
    guard let event = CGEvent(source: nil) else {
        fail("Unable to read cursor location")
    }
    let loc = event.location
    printJSON(["x": loc.x, "y": loc.y])
}

func cmdScreen() {
    var displayCount: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &displayCount)
    var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

    var displays: [[String: Any]] = []
    for (index, displayID) in displayIDs.enumerated() {
        let bounds = CGDisplayBounds(displayID)
        var scale: Double = 1.0
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescription(rawValue: "NSScreenNumber")] as? NSNumber,
               CGDirectDisplayID(num.uint32Value) == displayID {
                scale = Double(screen.backingScaleFactor)
                break
            }
        }
        displays.append([
            "index": index,
            "id": Int(displayID),
            "main": CGDisplayIsMain(displayID) != 0,
            "x": bounds.origin.x,
            "y": bounds.origin.y,
            "width": bounds.size.width,
            "height": bounds.size.height,
            "scale": scale
        ])
    }
    printJSON(["displays": displays])
}

typealias NSDeviceDescription = NSDeviceDescriptionKey

// MARK: - apps / windows / open / focus

func cmdApps() {
    let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    var result: [[String: Any]] = []
    for app in apps {
        result.append([
            "pid": app.processIdentifier,
            "name": app.localizedName ?? "",
            "bundleId": app.bundleIdentifier ?? "",
            "active": app.isActive,
            "hidden": app.isHidden
        ])
    }
    printJSON(["apps": result])
}

func windowList() -> [[String: Any]] {
    guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    var result: [[String: Any]] = []
    for info in infoList {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
        let title = info[kCGWindowName as String] as? String ?? ""
        let windowNumber = info[kCGWindowNumber as String] as? Int ?? 0
        let pid = info[kCGWindowOwnerPID as String] as? Int ?? 0
        var frame: [String: Any] = [:]
        if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
           let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
            frame = ["x": rect.origin.x, "y": rect.origin.y, "width": rect.size.width, "height": rect.size.height]
        }
        result.append([
            "id": windowNumber,
            "app": ownerName,
            "pid": pid,
            "title": title,
            "frame": frame
        ])
    }
    return result
}

func cmdWindows() {
    printJSON(["windows": windowList()])
}

func findRunningApp(named name: String) -> NSRunningApplication? {
    let lower = name.lowercased()
    let apps = NSWorkspace.shared.runningApplications
    if let exact = apps.first(where: { ($0.localizedName ?? "").lowercased() == lower }) {
        return exact
    }
    return apps.first(where: { ($0.localizedName ?? "").lowercased().contains(lower) })
}

func runOpen(_ appName: String, background: Bool) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    // -g launches/opens the app without bringing it to the foreground.
    process.arguments = background ? ["-g", "-a", appName] : ["-a", appName]
    let errPipe = Pipe()
    process.standardError = errPipe
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("Failed to open app: \(error.localizedDescription)")
    }
    if process.terminationStatus != 0 {
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        fail("Failed to open app '\(appName)': \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}

func applicationURL(named name: String) -> URL? {
    let fm = FileManager.default
    let fileName = name.lowercased().hasSuffix(".app") ? name : name + ".app"
    let dirs = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                "/Applications/Utilities", NSHomeDirectory() + "/Applications"]
    for dir in dirs {
        let path = dir + "/" + fileName
        if fm.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
    }
    return nil
}

func cmdOpen(_ args: [String]) {
    let appName = argAt(args, 0)
    if appName.isEmpty {
        fail("--app is required")
    }
    let mode = parseMode(argAt(args, 1))
    let plan: BackgroundPlan = .attempt({
        // Already running: it's open. Re-opening would make macOS bring it forward (a reopen
        // event activates the app even with 'open -g'), so leave it untouched.
        if let running = findRunningApp(named: appName), running.activationPolicy == .regular {
            return .done(["alreadyRunning": true, "app": running.localizedName ?? appName])
        }
        let saved = captureUserState()
        if let url = applicationURL(named: appName) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.addsToRecentItems = false
            var launchError: Error? = nil
            var finished = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                launchError = error
                finished = true
            }
            for _ in 0..<400 where !finished { spinRunLoop(0.025) }
            if let error = launchError {
                fail("Failed to open app '\(appName)': \(error.localizedDescription)")
            }
        } else {
            runOpen(appName, background: true)
        }
        // Some apps activate themselves on launch anyway; put the user's frontmost app back.
        spinRunLoop(0.5)
        if let front = saved.frontmost, !isFrontmost(front.processIdentifier) {
            return .done(["restored": ["frontmost": bringToFront(front)]])
        }
        return .done([:])
    })
    runAction("open", mode: mode, base: ["opened": appName], plan: plan) {
        runOpen(appName, background: false)
        return [:]
    }
}

func cmdFocus(_ args: [String]) {
    let appName = argAt(args, 0)
    if appName.isEmpty {
        fail("--app is required")
    }
    guard let app = findRunningApp(named: appName) else {
        fail("App not running: \(appName)")
    }
    if isDryRun() {
        printJSON(["focused": app.localizedName ?? appName, "success": true, "mode": "foreground", "dryRun": true])
        return
    }
    let activated = bringToFront(app)
    printJSON(["focused": app.localizedName ?? appName, "success": activated, "mode": "foreground"])
}

// MARK: - Accessibility tree walking

func axString(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let v = value else { return nil }
    if let s = v as? String { return s }
    if let n = v as? NSNumber { return n.stringValue }
    return nil
}

func axBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let v = value as? NSNumber else { return nil }
    return v.boolValue
}

func axFrame(_ element: AXUIElement) -> CGRect? {
    var posValue: AnyObject?
    var sizeValue: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
          AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
        return nil
    }
    var point = CGPoint.zero
    var size = CGSize.zero
    if let pv = posValue { AXValueGetValue(pv as! AXValue, .cgPoint, &point) }
    if let sv = sizeValue { AXValueGetValue(sv as! AXValue, .cgSize, &size) }
    return CGRect(origin: point, size: size)
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    guard result == .success, let children = value as? [AXUIElement] else { return [] }
    return children
}

func axRootElements(forAppNamed appName: String) -> (AXUIElement, String)? {
    let app: NSRunningApplication?
    if appName.isEmpty {
        app = NSWorkspace.shared.frontmostApplication
    } else {
        app = findRunningApp(named: appName)
    }
    guard let app = app else { return nil }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    return (axApp, app.localizedName ?? appName)
}

struct AXNode {
    let ref: String
    let role: String
    let label: String
    let value: String
    let frame: CGRect?
    let enabled: Bool
    let focused: Bool
}

func describeElement(_ element: AXUIElement, ref: String) -> AXNode {
    let role = axString(element, kAXRoleAttribute) ?? ""
    let label = axString(element, kAXTitleAttribute)
        ?? axString(element, kAXDescriptionAttribute)
        ?? axString(element, "AXLabel")
        ?? ""
    let value = axString(element, kAXValueAttribute) ?? ""
    let frame = axFrame(element)
    let enabled = axBool(element, kAXEnabledAttribute) ?? true
    let focused = axBool(element, kAXFocusedAttribute) ?? false
    return AXNode(ref: ref, role: role, label: label, value: value, frame: frame, enabled: enabled, focused: focused)
}

func nodeToJSON(_ node: AXNode) -> [String: Any] {
    var frameJSON: [String: Any] = [:]
    if let f = node.frame {
        frameJSON = ["x": f.origin.x, "y": f.origin.y, "width": f.size.width, "height": f.size.height]
    }
    return [
        "ref": node.ref,
        "role": node.role,
        "label": node.label,
        "value": node.value,
        "frame": frameJSON,
        "enabled": node.enabled,
        "focused": node.focused
    ]
}

func walkTree(_ element: AXUIElement, ref: String, depth: Int, maxDepth: Int, visit: (AXUIElement, AXNode) -> Void) {
    let node = describeElement(element, ref: ref)
    visit(element, node)
    if depth >= maxDepth { return }
    for (i, child) in axChildren(element).enumerated() {
        let childRef = ref.isEmpty ? "\(i)" : "\(ref).\(i)"
        walkTree(child, ref: childRef, depth: depth + 1, maxDepth: maxDepth, visit: visit)
    }
}

func resolveRef(_ root: AXUIElement, _ ref: String) -> AXUIElement? {
    if ref.isEmpty { return root }
    var current = root
    for part in ref.split(separator: ".") {
        guard let idx = Int(part) else { return nil }
        let children = axChildren(current)
        guard idx >= 0 && idx < children.count else { return nil }
        current = children[idx]
    }
    return current
}

// MARK: - read / find

func cmdRead(_ args: [String]) {
    requireAccessibility()
    let appArg = argAt(args, 0)
    let depth = parseInt(argAt(args, 1), default: 10)

    guard let (root, name) = axRootElements(forAppNamed: appArg) else {
        fail(appArg.isEmpty ? "No frontmost application found" : "App not running: \(appArg)")
    }

    var nodes: [[String: Any]] = []
    walkTree(root, ref: "", depth: 0, maxDepth: max(depth, 0)) { _, node in
        nodes.append(nodeToJSON(node))
    }
    printJSON(["app": name, "elements": nodes])
}

func cmdFind(_ args: [String]) {
    requireAccessibility()
    let text = argAt(args, 0).lowercased()
    let role = argAt(args, 1).lowercased()
    let appArg = argAt(args, 2)

    guard let (root, name) = axRootElements(forAppNamed: appArg) else {
        fail(appArg.isEmpty ? "No frontmost application found" : "App not running: \(appArg)")
    }

    // With --app, also report each match's center relative to the app's front window — the
    // coordinate space 'click --app' and 'screenshot --app' use.
    var windowOrigin: CGPoint? = nil
    if !appArg.isEmpty, let app = findRunningApp(named: appArg), let win = frontWindow(pid: app.processIdentifier) {
        windowOrigin = win.frame.origin
    }

    var matches: [[String: Any]] = []
    walkTree(root, ref: "", depth: 0, maxDepth: 30) { _, node in
        if !role.isEmpty && node.role.lowercased() != role { return }
        if !text.isEmpty {
            let haystack = (node.label + " " + node.value).lowercased()
            if !haystack.contains(text) { return }
        }
        if text.isEmpty && role.isEmpty { return }
        var entry = nodeToJSON(node)
        if let f = node.frame {
            entry["center"] = ["x": f.origin.x + f.size.width / 2, "y": f.origin.y + f.size.height / 2]
            if let o = windowOrigin {
                entry["windowCenter"] = ["x": f.origin.x + f.size.width / 2 - o.x, "y": f.origin.y + f.size.height / 2 - o.y]
            }
        }
        matches.append(entry)
    }
    printJSON(["app": name, "matches": matches])
}

// MARK: - action modes (background by default, real input as fallback)

enum ActionMode: String {
    case auto, background, foreground
}

func parseMode(_ s: String) -> ActionMode {
    if s.isEmpty { return .auto }
    guard let mode = ActionMode(rawValue: s.lowercased()) else {
        fail("Invalid --mode '\(s)': use auto, background or foreground")
    }
    return mode
}

// AUX4_COMPUTER_MAC_DRY_RUN=1 runs the background/foreground decision without touching the
// screen; AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable makes every background attempt
// fail, so the fallback logic and the JSON shape can be tested headless.
func isDryRun() -> Bool {
    return ProcessInfo.processInfo.environment["AUX4_COMPUTER_MAC_DRY_RUN"] == "1"
}

func simulatedBackgroundUnavailable() -> Bool {
    return ProcessInfo.processInfo.environment["AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND"] == "unavailable"
}

enum BackgroundOutcome {
    case done([String: Any])
    case unavailable(String)
}

enum BackgroundPlan {
    // Try this in the background; on .unavailable, auto falls back to real input.
    case attempt(() -> BackgroundOutcome)
    // Known up front that background can't do it; auto falls back to real input.
    case unavailable(String)
    // The action is foreground by nature (e.g. a system-wide hotkey); no fallback, no restore.
    case inherentlyForeground(String)
}

struct UserState {
    let cursor: CGPoint
    let frontmost: NSRunningApplication?
}

func currentCursor() -> CGPoint {
    return CGEvent(source: nil)?.location ?? .zero
}

func captureUserState() -> UserState {
    return UserState(cursor: currentCursor(), frontmost: NSWorkspace.shared.frontmostApplication)
}

func spinRunLoop(_ seconds: Double) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

func isFrontmost(_ pid: pid_t) -> Bool {
    let el = AXUIElementCreateApplication(pid)
    if let front = axBool(el, kAXFrontmostAttribute) { return front }
    return NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
}

// bringToFront makes an app frontmost. Accessibility's AXFrontmost is tried first because it
// isn't subject to macOS cooperative activation, which ignores activate() from a CLI process.
@discardableResult
func bringToFront(_ app: NSRunningApplication) -> Bool {
    let pid = app.processIdentifier
    if isFrontmost(pid) { return true }
    let el = AXUIElementCreateApplication(pid)
    AXUIElementSetAttributeValue(el, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    for _ in 0..<20 {
        if isFrontmost(pid) { return true }
        spinRunLoop(0.025)
    }
    app.activate(options: [])
    for _ in 0..<20 {
        if isFrontmost(pid) { return true }
        spinRunLoop(0.025)
    }
    return isFrontmost(pid)
}

func restoreUserState(_ state: UserState) -> [String: Any] {
    let moved = currentCursor()
    if abs(moved.x - state.cursor.x) > 0.01 || abs(moved.y - state.cursor.y) > 0.01 {
        CGWarpMouseCursorPosition(state.cursor)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    var frontRestored = true
    if let front = state.frontmost {
        frontRestored = bringToFront(front)
    }
    let now = currentCursor()
    let cursorRestored = abs(now.x - state.cursor.x) < 1 && abs(now.y - state.cursor.y) < 1
    return ["cursor": cursorRestored, "frontmost": frontRestored]
}

// runAction prints the action's JSON with "mode" ("background" | "foreground") and, when auto
// fell back, "fallbackReason" plus whether the cursor and frontmost app were restored.
func runAction(_ name: String,
               mode: ActionMode,
               base: [String: Any],
               plan: BackgroundPlan,
               targetApp: NSRunningApplication? = nil,
               foreground: () -> [String: Any]) {
    var out = base
    var fallbackReason: String? = nil
    let dryRun = isDryRun()
    if dryRun { out["dryRun"] = true }

    switch plan {
    case .attempt(let background):
        if mode != .foreground {
            let outcome: BackgroundOutcome
            if dryRun {
                outcome = simulatedBackgroundUnavailable() ? .unavailable("background simulated as unavailable") : .done([:])
            } else {
                outcome = background()
            }
            switch outcome {
            case .done(let extra):
                for (k, v) in extra { out[k] = v }
                out["mode"] = "background"
                printJSON(out)
                return
            case .unavailable(let reason):
                if mode == .background {
                    fail("Background mode not possible for \(name): \(reason)")
                }
                fallbackReason = reason
            }
        }
    case .unavailable(let reason):
        if mode == .background {
            fail("Background mode not possible for \(name): \(reason)")
        }
        if mode == .auto { fallbackReason = reason }
    case .inherentlyForeground(let reason):
        if mode == .background {
            fail("Background mode not possible for \(name): \(reason)")
        }
    }

    out["mode"] = "foreground"
    if let reason = fallbackReason { out["fallbackReason"] = reason }
    if dryRun {
        printJSON(out)
        return
    }

    // Auto fell back: act with real input, then put the cursor and frontmost app back so the
    // fallback is a brief blip rather than a takeover.
    let saved: UserState? = fallbackReason != nil ? captureUserState() : nil
    if let app = targetApp {
        if !bringToFront(app) {
            fail("Could not bring '\(app.localizedName ?? "app")' to the front for real input")
        }
        usleep(150_000)
    }
    for (k, v) in foreground() { out[k] = v }
    if let state = saved {
        usleep(150_000)
        out["restored"] = restoreUserState(state)
    }
    printJSON(out)
}

// MARK: - targets (app + window) and coordinates

struct WindowInfo {
    let id: CGWindowID
    let title: String
    let frame: CGRect
}

struct Target {
    let app: NSRunningApplication
    let name: String
    let pid: pid_t
    let axApp: AXUIElement
    let explicit: Bool
}

func frontWindow(pid: pid_t) -> WindowInfo? {
    guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    // Front-to-back order: the first normal-layer, visible, reasonably sized window of the app.
    for info in infoList {
        guard (info[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) == pid,
              (info[kCGWindowLayer as String] as? Int) == 0 else { continue }
        if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0 { continue }
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
              rect.width >= 40, rect.height >= 40 else { continue }
        let id = CGWindowID(info[kCGWindowNumber as String] as? Int ?? 0)
        return WindowInfo(id: id, title: info[kCGWindowName as String] as? String ?? "", frame: rect)
    }
    return nil
}

func frameJSON(_ r: CGRect) -> [String: Any] {
    return ["x": r.origin.x, "y": r.origin.y, "width": r.size.width, "height": r.size.height]
}

func resolveTarget(_ appArg: String) -> Target {
    let app: NSRunningApplication?
    if appArg.isEmpty {
        app = NSWorkspace.shared.frontmostApplication
    } else {
        app = findRunningApp(named: appArg)
    }
    guard let app = app else {
        fail(appArg.isEmpty ? "No frontmost application found" : "App not running: \(appArg)")
    }
    let pid = app.processIdentifier
    let axApp = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(axApp, 3.0)
    return Target(app: app, name: app.localizedName ?? appArg, pid: pid, axApp: axApp, explicit: !appArg.isEmpty)
}

// With --app, x/y are relative to the app's front window (the same window 'screenshot --app'
// captures); without --app they are screen points.
func screenPoint(x: Double, y: Double, target: Target) -> CGPoint {
    if !target.explicit { return CGPoint(x: x, y: y) }
    guard let win = frontWindow(pid: target.pid) else {
        fail("No on-screen window found for app: \(target.name)")
    }
    return CGPoint(x: win.frame.origin.x + x, y: win.frame.origin.y + y)
}

// MARK: - accessibility actions

func axActions(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success, let list = names as? [String] else { return [] }
    return list
}

func axParent(_ element: AXUIElement) -> AXUIElement? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
          let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
    return (v as! AXUIElement)
}

func axElementAttr(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
    return (v as! AXUIElement)
}

func axSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
    var settable: DarwinBoolean = false
    guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else { return false }
    return settable.boolValue
}

func axWindows(_ app: AXUIElement) -> [AXUIElement] {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return [] }
    return windows
}

func elementSummary(_ element: AXUIElement) -> [String: Any] {
    let node = describeElement(element, ref: "")
    return ["role": node.role, "label": node.label]
}

// hitTest finds the app's own element at a screen point, even when its window is covered.
func hitTest(_ target: Target, _ point: CGPoint) -> AXUIElement? {
    var hit: AXUIElement?
    if AXUIElementCopyElementAtPosition(target.axApp, Float(point.x), Float(point.y), &hit) == .success, let el = hit {
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        if pid == target.pid { return el }
    }
    // Manual hit test over the app's own tree: the smallest element containing the point.
    var best: (AXUIElement, CGFloat)? = nil
    func visit(_ el: AXUIElement, _ depth: Int) {
        if depth > 40 { return }
        if let f = axFrame(el) {
            guard f.contains(point) else { return }
            let area = f.width * f.height
            if best == nil || area <= best!.1 { best = (el, area) }
        }
        for child in axChildren(el) { visit(child, depth + 1) }
    }
    for window in axWindows(target.axApp) {
        guard let f = axFrame(window), f.contains(point) else { continue }
        visit(window, 0)
        break
    }
    return best?.0
}

// actionable walks up from a hit element (e.g. the label inside a button) to the nearest
// element that supports one of the wanted actions.
func actionable(_ element: AXUIElement, _ wanted: [String]) -> (AXUIElement, String)? {
    var current: AXUIElement? = element
    var hops = 0
    while let el = current, hops < 5 {
        let actions = axActions(el)
        for action in wanted where actions.contains(action) {
            return (el, action)
        }
        let role = axString(el, kAXRoleAttribute) ?? ""
        if role == kAXWindowRole || role == kAXApplicationRole { break }
        current = axParent(el)
        hops += 1
    }
    return nil
}

func focusedElement(_ target: Target) -> AXUIElement? {
    return axElementAttr(target.axApp, kAXFocusedUIElementAttribute)
}

// MARK: - mouse control

func postMouseEvent(type: CGEventType, point: CGPoint, button: CGMouseButton, clickCount: Int64 = 1) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
    event.setIntegerValueField(.mouseEventClickState, value: clickCount)
    event.post(tap: .cghidEventTap)
}

func hidClick(_ point: CGPoint, button: CGMouseButton, count: Int) {
    let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
    let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
    for i in 1...count {
        postMouseEvent(type: downType, point: point, button: button, clickCount: Int64(i))
        postMouseEvent(type: upType, point: point, button: button, clickCount: Int64(i))
    }
}

func cmdMove(_ args: [String]) {
    requireAccessibility()
    let x = parseDouble(argAt(args, 0))
    let y = parseDouble(argAt(args, 1))
    let point = CGPoint(x: x, y: y)
    if !isDryRun() {
        postMouseEvent(type: .mouseMoved, point: point, button: .left)
    }
    printJSON(["x": x, "y": y, "mode": "foreground"])
}

func cmdClick(_ args: [String]) {
    let xStr = argAt(args, 0)
    let yStr = argAt(args, 1)
    let buttonStr = argAt(args, 2).isEmpty ? "left" : argAt(args, 2).lowercased()
    let count = max(parseInt(argAt(args, 3), default: 1), 1)
    let elementRef = argAt(args, 4)
    let appArg = argAt(args, 5)
    let mode = parseMode(argAt(args, 6))

    guard buttonStr == "left" || buttonStr == "right" else {
        fail("Invalid --button '\(buttonStr)': use left or right")
    }
    if elementRef.isEmpty && (xStr.isEmpty || yStr.isEmpty) {
        fail("Provide --x/--y or --element")
    }
    requireAccessibility()
    let button: CGMouseButton = buttonStr == "right" ? .right : .left
    let wanted = button == .right ? ["AXShowMenu"] : ["AXPress", "AXConfirm", "AXPick"]

    if !elementRef.isEmpty {
        var base: [String: Any] = ["clicked": elementRef]
        if !appArg.isEmpty { base["app"] = appArg }
        if isDryRun() {
            runAction("click", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
            return
        }
        let target = resolveTarget(appArg)
        base["app"] = target.name
        guard let element = resolveRef(target.axApp, elementRef) else {
            fail("Element not found for ref: \(elementRef)")
        }
        let plan: BackgroundPlan = .attempt({
            guard let (el, action) = actionable(element, wanted) else {
                return .unavailable("element '\(elementRef)' has no \(wanted.joined(separator: "/")) action")
            }
            let result = AXUIElementPerformAction(el, action as CFString)
            if result != .success {
                return .unavailable("\(action) failed on element '\(elementRef)' (AXError \(result.rawValue))")
            }
            return .done(["action": action, "element": elementSummary(el)])
        })
        runAction("click", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
            guard let f = axFrame(element) else {
                fail("Element '\(elementRef)' has no on-screen frame to click")
            }
            let point = CGPoint(x: f.midX, y: f.midY)
            hidClick(point, button: button, count: count)
            return ["screen": ["x": point.x, "y": point.y]]
        }
        return
    }

    let x = parseDouble(xStr)
    let y = parseDouble(yStr)
    var base: [String: Any] = ["x": x, "y": y, "button": buttonStr, "count": count]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        let plan: BackgroundPlan = count > 1 ? .unavailable("multi-click has no accessibility equivalent") : .attempt({ .unavailable("dry run") })
        runAction("click", mode: mode, base: base, plan: plan) { [:] }
        return
    }

    let target = resolveTarget(appArg)
    base["app"] = target.name
    let point = screenPoint(x: x, y: y, target: target)
    base["screen"] = ["x": point.x, "y": point.y]

    let plan: BackgroundPlan
    if count > 1 {
        plan = .unavailable("multi-click has no accessibility equivalent")
    } else {
        plan = .attempt({
            guard let hit = hitTest(target, point) else {
                return .unavailable("no accessibility element of \(target.name) at (\(x), \(y))")
            }
            if let (el, action) = actionable(hit, wanted) {
                let result = AXUIElementPerformAction(el, action as CFString)
                if result == .success {
                    return .done(["action": action, "element": elementSummary(el)])
                }
                return .unavailable("\(action) failed (AXError \(result.rawValue))")
            }
            // A text field/area: clicking it means "put the focus here".
            if button == .left, axSettable(hit, kAXFocusedAttribute) {
                let role = axString(hit, kAXRoleAttribute) ?? ""
                if ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXSecureTextField"].contains(role) {
                    if AXUIElementSetAttributeValue(hit, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success {
                        return .done(["action": "AXFocus", "element": elementSummary(hit)])
                    }
                }
            }
            let summary = elementSummary(hit)
            return .unavailable("element at point (\(summary["role"] ?? "")) has no \(wanted.joined(separator: "/")) action")
        })
    }
    runAction("click", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
        hidClick(point, button: button, count: count)
        return [:]
    }
}

func cmdDrag(_ args: [String]) {
    requireAccessibility()
    let x = parseDouble(argAt(args, 0))
    let y = parseDouble(argAt(args, 1))
    let toX = parseDouble(argAt(args, 2))
    let toY = parseDouble(argAt(args, 3))

    let start = CGPoint(x: x, y: y)
    let end = CGPoint(x: toX, y: toY)

    if !isDryRun() {
        postMouseEvent(type: .mouseMoved, point: start, button: .left)
        postMouseEvent(type: .leftMouseDown, point: start, button: .left)

        let steps = 10
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let midPoint = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            postMouseEvent(type: .leftMouseDragged, point: midPoint, button: .left)
            usleep(5000)
        }

        postMouseEvent(type: .leftMouseUp, point: end, button: .left)
    }
    printJSON(["from": ["x": x, "y": y], "to": ["x": toX, "y": toY], "mode": "foreground"])
}

// axScroll scrolls the AXScrollArea at (or containing the focus near) the point by moving its
// scroll bar value, which the app applies without any mouse involvement.
func axScroll(_ target: Target, point: CGPoint?, dx: Int, dy: Int) -> BackgroundOutcome {
    var start: AXUIElement? = nil
    if let p = point { start = hitTest(target, p) }
    if start == nil { start = focusedElement(target) }
    guard var current = start else {
        return .unavailable("no accessibility element to scroll in \(target.name)")
    }
    var scrollArea: AXUIElement? = nil
    for _ in 0..<12 {
        if axString(current, kAXRoleAttribute) == kAXScrollAreaRole { scrollArea = current; break }
        guard let parent = axParent(current) else { break }
        current = parent
    }
    guard let area = scrollArea, let areaFrame = axFrame(area) else {
        return .unavailable("no scroll area at that point in \(target.name)")
    }
    let content = axChildren(area).first(where: { axString($0, kAXRoleAttribute) != kAXScrollBarRole })
    let contentFrame = content.flatMap { axFrame($0) }

    var result: [String: Any] = ["method": "accessibility"]
    func move(_ barAttr: String, _ delta: Int, _ viewLen: CGFloat, _ docLen: CGFloat?) -> String? {
        if delta == 0 { return nil }
        guard let bar = axElementAttr(area, barAttr) else { return "no scroll bar" }
        guard axSettable(bar, kAXValueAttribute) else { return "scroll bar not settable" }
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(bar, kAXValueAttribute as CFString, &value) == .success,
              let current = (value as? NSNumber)?.doubleValue else { return "scroll bar has no value" }
        let range = Double((docLen ?? viewLen) - viewLen)
        guard range > 0 else { return nil }
        // Negative delta scrolls down/right (the scroll wheel convention): the value grows.
        let next = min(max(current - Double(delta) / range, 0), 1)
        if AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: next)) != .success {
            return "setting scroll bar value failed"
        }
        result[barAttr == kAXVerticalScrollBarAttribute ? "vertical" : "horizontal"] = next
        return nil
    }
    if let err = move(kAXVerticalScrollBarAttribute, dy, areaFrame.height, contentFrame?.height) {
        return .unavailable("vertical: \(err)")
    }
    if let err = move(kAXHorizontalScrollBarAttribute, dx, areaFrame.width, contentFrame?.width) {
        return .unavailable("horizontal: \(err)")
    }
    return .done(result)
}

func makeScrollEvent(dx: Int, dy: Int) -> CGEvent? {
    return CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)
}

func cmdScroll(_ args: [String]) {
    let xStr = argAt(args, 0)
    let yStr = argAt(args, 1)
    let dx = parseInt(argAt(args, 2))
    let dy = parseInt(argAt(args, 3))
    let appArg = argAt(args, 4)
    let mode = parseMode(argAt(args, 5))
    requireAccessibility()

    var base: [String: Any] = ["dx": dx, "dy": dy]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("scroll", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    var point: CGPoint? = nil
    if !xStr.isEmpty && !yStr.isEmpty {
        point = screenPoint(x: parseDouble(xStr), y: parseDouble(yStr), target: target)
        base["screen"] = ["x": point!.x, "y": point!.y]
    }

    let plan: BackgroundPlan = .attempt({
        let ax = axScroll(target, point: point, dx: dx, dy: dy)
        if case .done = ax { return ax }
        if target.explicit, let p = point ?? frontWindow(pid: target.pid).map({ CGPoint(x: $0.frame.midX, y: $0.frame.midY) }),
           let event = makeScrollEvent(dx: dx, dy: dy) {
            event.location = p
            event.postToPid(target.pid)
            return .done(["method": "postToPid"])
        }
        if case .unavailable(let reason) = ax { return .unavailable(reason) }
        return ax
    })
    runAction("scroll", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
        if let p = point {
            postMouseEvent(type: .mouseMoved, point: p, button: .left)
        }
        makeScrollEvent(dx: dx, dy: dy)?.post(tap: .cghidEventTap)
        return [:]
    }
}

// MARK: - keyboard control

func postUnicode(_ text: String, pid: pid_t?) {
    for unit in text.utf16 {
        var units: [UniChar] = [unit]
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isDown) else { continue }
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            if let pid = pid { event.postToPid(pid) } else { event.post(tap: .cghidEventTap) }
        }
        usleep(2000)
    }
}

func axNumber(_ element: AXUIElement, _ attribute: String) -> Int? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let n = value as? NSNumber else { return nil }
    return n.intValue
}

func axSelectedLength(_ element: AXUIElement) -> Int? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
          let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    guard AXValueGetValue(v as! AXValue, .cfRange, &range) else { return nil }
    return range.length
}

// axInsertText inserts text at the focused element's cursor (replacing the selection), like
// typing, by setting AXSelectedText. Returns nil on success or a reason it isn't possible.
func axInsertText(_ target: Target, _ text: String) -> String? {
    guard let focused = focusedElement(target) else {
        return "\(target.name) has no focused element"
    }
    guard axSettable(focused, kAXSelectedTextAttribute) else {
        return "focused element doesn't accept accessibility text"
    }
    let before = axNumber(focused, kAXNumberOfCharactersAttribute)
    let selected = axSelectedLength(focused) ?? 0
    let result = AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFString)
    if result != .success {
        return "setting AXSelectedText failed (AXError \(result.rawValue))"
    }
    if let b = before, let after = axNumber(focused, kAXNumberOfCharactersAttribute),
       after == b, selected == 0, !text.isEmpty {
        return "app accepted AXSelectedText but the text did not change"
    }
    return nil
}

func cmdType(_ args: [String]) {
    let text = argAt(args, 0)
    let delayMs = parseInt(argAt(args, 1), default: 0)
    let appArg = argAt(args, 2)
    let mode = parseMode(argAt(args, 3))
    if text.isEmpty {
        fail("--text is required")
    }
    requireAccessibility()
    var base: [String: Any] = ["typed": text.count]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("type", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    if delayMs > 0 {
        usleep(UInt32(delayMs) * 1000)
    }
    let plan: BackgroundPlan = .attempt({
        guard let reason = axInsertText(target, text) else {
            return .done(["method": "accessibility"])
        }
        // Keystrokes posted to an app only land when it is frontmost (a background app has no
        // key window); either way nothing on screen moves.
        if isFrontmost(target.pid) {
            postUnicode(text, pid: target.pid)
            return .done(["method": "postToPid"])
        }
        return .unavailable(reason)
    })
    runAction("type", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
        postUnicode(text, pid: nil)
        return [:]
    }
}

let keyCodeMap: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "equal": 24, "9": 25,
    "7": 26, "minus": 27, "8": 28, "0": 29, "rightbracket": 30, "o": 31, "u": 32,
    "leftbracket": 33, "i": 34, "p": 35, "return": 36, "enter": 36, "l": 37, "j": 38,
    "quote": 39, "k": 40, "semicolon": 41, "backslash": 42, "comma": 43, "slash": 44,
    "n": 45, "m": 46, "period": 47, "tab": 48, "space": 49, "grave": 50,
    "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
    "f17": 64, "volumeup": 72, "volumedown": 73, "mute": 74, "f18": 79, "f19": 80,
    "f20": 90, "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100, "f9": 101,
    "f11": 103, "f13": 105, "f16": 106, "f14": 107, "f10": 109, "f12": 111,
    "f15": 113, "help": 114, "home": 115, "pageup": 116, "forwarddelete": 117,
    "f4": 118, "end": 119, "f2": 120, "pagedown": 121, "left": 123, "right": 124,
    "down": 125, "up": 126, "f1": 122
]

struct KeyCombo {
    let modifiers: [(CGKeyCode, CGEventFlags)]
    let key: CGKeyCode
    let keyName: String
}

// parseCombo parses "cmd+shift+4" generically: the last part is the key, the rest modifiers.
func parseCombo(_ combo: String) -> KeyCombo {
    let parts = combo.lowercased().split(separator: "+").map { String($0) }
    guard let keyName = parts.last else {
        fail("Invalid key combo: \(combo)")
    }
    guard let keyCode = keyCodeMap[keyName] else {
        fail("Unknown key: \(keyName)")
    }
    var modifiers: [(CGKeyCode, CGEventFlags)] = []
    for modifier in parts.dropLast() {
        switch modifier {
        case "cmd", "command": modifiers.append((55, .maskCommand))
        case "shift": modifiers.append((56, .maskShift))
        case "alt", "option": modifiers.append((58, .maskAlternate))
        case "ctrl", "control": modifiers.append((59, .maskControl))
        case "fn": modifiers.append((63, .maskSecondaryFn))
        default: fail("Unknown modifier: \(modifier)")
        }
    }
    return KeyCombo(modifiers: modifiers, key: keyCode, keyName: keyName)
}

// Menu-bar key equivalents: a shortcut like cmd+a is, in most apps, a menu item (Edit > Select
// All). Pressing that item through Accessibility works on a background app, whereas keystrokes
// sent to a background app are dropped (it has no key window to receive them).
let menuCharForKey: [String: String] = [
    "comma": ",", "period": ".", "slash": "/", "semicolon": ";", "quote": "'", "minus": "-",
    "equal": "=", "leftbracket": "[", "rightbracket": "]", "backslash": "\\", "grave": "`", "space": " "
]

func menuModifierMask(_ combo: KeyCombo) -> Int? {
    var mask = 8 // kAXMenuItemModifierNoCommand unless cmd is present
    for (_, flag) in combo.modifiers {
        if flag == .maskCommand { mask &= ~8 }
        else if flag == .maskShift { mask |= 1 }
        else if flag == .maskAlternate { mask |= 2 }
        else if flag == .maskControl { mask |= 4 }
        else { return nil }
    }
    return mask
}

func findMenuItem(_ target: Target, _ combo: KeyCombo) -> AXUIElement? {
    guard let mask = menuModifierMask(combo),
          let menuBar = axElementAttr(target.axApp, kAXMenuBarAttribute) else { return nil }
    let wantChar: String? = combo.keyName.count == 1 ? combo.keyName.uppercased() : menuCharForKey[combo.keyName]
    // Only enabled items count: in a background app, items that act on the focused view (Select
    // All, Undo, Copy...) are disabled because the app has no key window, and pressing them is a no-op.
    var found: AXUIElement? = nil
    func visit(_ el: AXUIElement, _ depth: Int) {
        if found != nil || depth > 6 { return }
        if axString(el, kAXRoleAttribute) == kAXMenuItemRole {
            let mods = axNumber(el, kAXMenuItemCmdModifiersAttribute) ?? 0
            var matches = false
            if let ch = axString(el, kAXMenuItemCmdCharAttribute), !ch.isEmpty {
                matches = wantChar != nil && ch.uppercased() == wantChar!
            } else if let vk = axNumber(el, kAXMenuItemCmdVirtualKeyAttribute) {
                matches = vk == Int(combo.key)
            }
            if matches && mods == mask && (axBool(el, kAXEnabledAttribute) ?? true) {
                found = el
                return
            }
        }
        for child in axChildren(el) { visit(child, depth + 1) }
    }
    visit(menuBar, 0)
    return found
}

// pressShortcutInBackground presses the combo on the app without input: via its menu item, or
// with keystrokes posted to the app when it is already frontmost (nothing moves either way).
func pressShortcutInBackground(_ target: Target, _ combo: KeyCombo) -> BackgroundOutcome {
    if let item = findMenuItem(target, combo) {
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        if result == .success {
            return .done(["method": "menu", "menuItem": axString(item, kAXTitleAttribute) ?? ""])
        }
    }
    if isFrontmost(target.pid) {
        if let error = postCombo(combo, pid: target.pid) { return .unavailable(error) }
        return .done(["method": "postToPid"])
    }
    return .unavailable("no enabled menu item for this shortcut in \(target.name), and keystrokes sent to a background app are dropped")
}

// postCombo presses the combo. Modifiers are sent as real key events (not just flags on the
// key) so system-wide hotkeys like cmd+space fire. With a pid the events go only to that app.
func postCombo(_ combo: KeyCombo, pid: pid_t?) -> String? {
    let source = CGEventSource(stateID: .hidSystemState)
    var flags: CGEventFlags = []
    func post(_ code: CGKeyCode, _ isDown: Bool) -> Bool {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: isDown) else {
            return false
        }
        event.flags = flags
        if let pid = pid { event.postToPid(pid) } else { event.post(tap: .cghidEventTap) }
        usleep(10_000)
        return true
    }
    for (code, flag) in combo.modifiers {
        flags.insert(flag)
        if !post(code, true) { return "Failed to create key event" }
    }
    if !post(combo.key, true) || !post(combo.key, false) {
        return "Failed to create key event"
    }
    for (code, flag) in combo.modifiers.reversed() {
        flags.remove(flag)
        if !post(code, false) { return "Failed to create key event" }
    }
    return nil
}

func cmdShortcut(_ args: [String]) {
    let keys = argAt(args, 0)
    let delayMs = parseInt(argAt(args, 1), default: 0)
    let appArg = argAt(args, 2)
    let mode = parseMode(argAt(args, 3))
    if keys.isEmpty {
        fail("--keys is required")
    }
    let combo = parseCombo(keys)
    if appArg.isEmpty && mode == .background {
        fail("Background mode not possible for shortcut: without --app it is a system-wide shortcut, which only real input can press")
    }
    requireAccessibility()
    var base: [String: Any] = ["keys": keys]
    if !appArg.isEmpty { base["app"] = appArg }

    if appArg.isEmpty {
        runAction("shortcut", mode: mode, base: base, plan: .inherentlyForeground("system-wide shortcut")) {
            if delayMs > 0 { usleep(UInt32(delayMs) * 1000) }
            if let error = postCombo(combo, pid: nil) { fail(error) }
            return [:]
        }
        return
    }
    if isDryRun() {
        runAction("shortcut", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    if delayMs > 0 { usleep(UInt32(delayMs) * 1000) }
    let plan: BackgroundPlan = .attempt({ pressShortcutInBackground(target, combo) })
    runAction("shortcut", mode: mode, base: base, plan: plan, targetApp: target.app) {
        if let error = postCombo(combo, pid: nil) { fail(error) }
        return [:]
    }
}

// MARK: - clipboard

func clipboardReadText() -> String {
    return NSPasteboard.general.string(forType: .string) ?? ""
}

func clipboardWriteText(_ text: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.setString(text, forType: .string)
}

func cmdClipboardRead() {
    printJSON(["text": clipboardReadText()])
}

func cmdClipboardCopy(_ args: [String]) {
    let text = argAt(args, 0)
    let appArg = argAt(args, 1)
    let mode = parseMode(argAt(args, 2))
    if !text.isEmpty {
        guard clipboardWriteText(text) else {
            fail("Failed to write to clipboard")
        }
        printJSON(["text": text])
        return
    }

    requireAccessibility()
    var base: [String: Any] = [:]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("clipboard copy", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    let copyCombo = parseCombo("cmd+c")
    let plan: BackgroundPlan = .attempt({
        if let focused = focusedElement(target) {
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &value) == .success,
               let selected = value as? String {
                if !selected.isEmpty && !clipboardWriteText(selected) {
                    return .unavailable("failed to write to clipboard")
                }
                return .done(["text": selected, "method": "accessibility"])
            }
        }
        let before = NSPasteboard.general.changeCount
        if case .done(let info) = pressShortcutInBackground(target, copyCombo) {
            usleep(250_000)
            if NSPasteboard.general.changeCount != before {
                return .done(["text": clipboardReadText(), "method": info["method"] ?? "menu"])
            }
        }
        return .unavailable("no accessible selection in \(target.name), and its Copy command didn't change the clipboard")
    })
    runAction("clipboard copy", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
        if let error = postCombo(copyCombo, pid: nil) { fail(error) }
        usleep(250_000)
        return ["text": clipboardReadText()]
    }
}

func cmdClipboardPaste(_ args: [String]) {
    let text = argAt(args, 0)
    let appArg = argAt(args, 1)
    let mode = parseMode(argAt(args, 2))
    requireAccessibility()
    if !text.isEmpty && !isDryRun() {
        guard clipboardWriteText(text) else {
            fail("Failed to write to clipboard")
        }
    }
    let pasteText = isDryRun() ? text : clipboardReadText()
    var base: [String: Any] = ["pasted": pasteText]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("clipboard paste", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    let plan: BackgroundPlan = pasteText.isEmpty
        ? .unavailable("the clipboard has no text to insert via accessibility")
        : .attempt({
            guard let reason = axInsertText(target, pasteText) else {
                return .done(["method": "accessibility"])
            }
            if case .done(let info) = pressShortcutInBackground(target, parseCombo("cmd+v")) {
                return .done(info)
            }
            return .unavailable(reason)
        })
    runAction("clipboard paste", mode: mode, base: base, plan: plan, targetApp: target.explicit ? target.app : nil) {
        if let error = postCombo(parseCombo("cmd+v"), pid: nil) { fail(error) }
        return [:]
    }
}

// MARK: - screenshot

func resizeImage(_ image: CGImage, maxWidth: Int) -> CGImage {
    let width = image.width
    let height = image.height
    if maxWidth <= 0 || width <= maxWidth {
        return image
    }
    let scale = Double(maxWidth) / Double(width)
    let newWidth = maxWidth
    let newHeight = Int(Double(height) * scale)

    guard let colorSpace = image.colorSpace,
          let context = CGContext(data: nil, width: newWidth, height: newHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return image
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    return context.makeImage() ?? image
}

func savePNG(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

func captureImage(filter: SCContentFilter, width: Int, height: Int) async throws -> CGImage {
    let config = SCStreamConfiguration()
    config.width = max(width, 1)
    config.height = max(height, 1)
    config.showsCursor = false
    return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
}

func cmdScreenshot(_ args: [String]) async {
    let outputArg = argAt(args, 0)
    let displayArg = argAt(args, 1)
    let appArg = argAt(args, 2)
    let maxWidth = parseInt(argAt(args, 3), default: 1568)

    var appWindow: WindowInfo? = nil
    var appName = ""
    if !appArg.isEmpty {
        guard let app = findRunningApp(named: appArg) else {
            fail("App not running: \(appArg)")
        }
        appName = app.localizedName ?? appArg
        guard let win = frontWindow(pid: app.processIdentifier) else {
            fail("No on-screen window found for app: \(appArg)")
        }
        appWindow = win
    }
    requireScreenRecording()

    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
        fail("Failed to enumerate screen content: \(error.localizedDescription)")
    }

    var image: CGImage?
    if let target = appWindow {
        guard let win = content.windows.first(where: { $0.windowID == target.id }) else {
            fail("No capturable window found for app: \(appArg)")
        }
        let filter = SCContentFilter(desktopIndependentWindow: win)
        do {
            image = try await captureImage(filter: filter, width: Int(win.frame.width), height: Int(win.frame.height))
        } catch {
            fail("Failed to capture window for app '\(appArg)': \(error.localizedDescription)")
        }
    } else {
        let displayIndex = parseInt(displayArg, default: 0)
        guard displayIndex >= 0 && displayIndex < content.displays.count else {
            fail("Invalid display index: \(displayArg)")
        }
        let display = content.displays[displayIndex]
        let filter = SCContentFilter(display: display, excludingWindows: [])
        do {
            image = try await captureImage(filter: filter, width: display.width, height: display.height)
        } catch {
            fail("Failed to capture display \(displayIndex): \(error.localizedDescription)")
        }
    }

    guard let cgImage = image else {
        fail("Failed to capture screenshot")
    }

    let resized = resizeImage(cgImage, maxWidth: maxWidth)

    let outputPath: String
    if outputArg.isEmpty {
        let tmpDir = NSTemporaryDirectory()
        outputPath = tmpDir + "aux4-computer-mac-\(Int(Date().timeIntervalSince1970 * 1000)).png"
    } else {
        outputPath = outputArg
    }

    guard savePNG(resized, to: outputPath) else {
        fail("Failed to save screenshot to \(outputPath)")
    }

    var out: [String: Any] = [
        "path": outputPath,
        "width": resized.width,
        "height": resized.height,
        "scale": Double(resized.width) / Double(max(cgImage.width, 1))
    ]
    if let win = appWindow {
        out["app"] = appName
        out["window"] = ["id": Int(win.id), "title": win.title, "frame": frameJSON(win.frame)]
    }
    printJSON(out)
}

// MARK: - ocr (Apple Vision text recognition on pixels)

// round1 keeps one decimal and serializes cleanly (a plain Double prints as 33.600000000000001).
func round1(_ v: Double) -> NSNumber {
    return NSDecimalNumber(string: String(format: "%.1f", v))
}

// textRange finds the filter in a recognized line, case-insensitively and ignoring whitespace
// differences (recognition sometimes splits "1,792" as "1 ,792").
func textRange(of filter: String, in text: String) -> Range<String.Index>? {
    if let r = text.range(of: filter, options: [.caseInsensitive]) { return r }
    let chars = filter.filter { !$0.isWhitespace }.map { NSRegularExpression.escapedPattern(for: String($0)) }
    if chars.isEmpty { return nil }
    return text.range(of: chars.joined(separator: "\\s*"), options: [.caseInsensitive, .regularExpression])
}

func rectJSON(_ r: CGRect) -> [String: Any] {
    return ["x": round1(r.origin.x), "y": round1(r.origin.y), "width": round1(r.size.width), "height": round1(r.size.height)]
}

func centerJSON(_ r: CGRect, minus origin: CGPoint = .zero) -> [String: Any] {
    return ["x": round1(r.midX - origin.x), "y": round1(r.midY - origin.y)]
}

func loadPNG(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

// captureForOCR captures at the content's native pixel density (asking ScreenCaptureKit for more
// pixels than the display has doesn't upscale: it pads, which would shift every position), then
// upscales in software to at least 2 pixels per point, where recognition is more reliable.
// Returns the image and its pixels per point.
func captureForOCR(filter: SCContentFilter, size: CGSize) async throws -> (CGImage, Double) {
    let native = max(Double(filter.pointPixelScale), 1)
    let captured = try await captureImage(filter: filter,
                                          width: Int((size.width * native).rounded()),
                                          height: Int((size.height * native).rounded()))
    // What was actually delivered, in case it differs from what was asked.
    let actual = size.width > 0 ? Double(captured.width) / Double(size.width) : native
    if actual >= 2 { return (captured, actual) }
    let factor = 2 / actual
    let w = Int((Double(captured.width) * factor).rounded())
    let h = Int((Double(captured.height) * factor).rounded())
    guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return (captured, actual)
    }
    context.interpolationQuality = .high
    context.draw(captured, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let upscaled = context.makeImage() else { return (captured, actual) }
    return (upscaled, Double(w) / Double(size.width))
}

struct RecognizedLine {
    let text: String
    let confidence: Double
    let box: CGRect                  // in image pixels, top-left origin
    let matchBox: CGRect?            // the --text substring, in image pixels
}

func recognizeText(_ image: CGImage, level: String, languages: [String], filter: String) -> [RecognizedLine] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level == "fast" ? .fast : .accurate
    request.usesLanguageCorrection = true
    if !languages.isEmpty {
        if let supported = try? request.supportedRecognitionLanguages() {
            for lang in languages where !supported.contains(lang) {
                fail("Unsupported OCR language '\(lang)' for level \(level). Supported: \(supported.joined(separator: ", "))")
            }
        }
        request.recognitionLanguages = languages
    }
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
        try handler.perform([request])
    } catch {
        fail("Text recognition failed: \(error.localizedDescription)")
    }
    let w = Double(image.width)
    let h = Double(image.height)
    // Vision boxes are normalized with a bottom-left origin; flip to top-left pixels.
    func toPixels(_ bb: CGRect) -> CGRect {
        return CGRect(x: bb.minX * w, y: (1 - bb.maxY) * h, width: bb.width * w, height: bb.height * h)
    }
    var lines: [RecognizedLine] = []
    for observation in request.results ?? [] {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let text = candidate.string
        var matchBox: CGRect? = nil
        if !filter.isEmpty {
            guard let range = textRange(of: filter, in: text) else { continue }
            if let sub = try? candidate.boundingBox(for: range) {
                matchBox = toPixels(sub.boundingBox)
            }
        }
        lines.append(RecognizedLine(text: text, confidence: Double(candidate.confidence), box: toPixels(observation.boundingBox), matchBox: matchBox))
    }
    // Reading order: top to bottom, then left to right for lines on the same row.
    lines.sort { a, b in
        if abs(a.box.midY - b.box.midY) > min(a.box.height, b.box.height) / 2 { return a.box.midY < b.box.midY }
        return a.box.minX < b.box.minX
    }
    return lines
}

func cmdOcr(_ args: [String]) async {
    let appArg = argAt(args, 0)
    let imageArg = argAt(args, 1)
    let filter = argAt(args, 2)
    let levelArg = argAt(args, 3).isEmpty ? "accurate" : argAt(args, 3).lowercased()
    let languages = argAt(args, 4).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    let mode = parseMode(argAt(args, 5))
    let imageScaleArg = parseDouble(argAt(args, 6), default: 1)

    guard levelArg == "accurate" || levelArg == "fast" else {
        fail("Invalid --level '\(levelArg)': use accurate or fast")
    }
    if !imageArg.isEmpty && !appArg.isEmpty {
        fail("Use either --app or --image, not both")
    }

    var out: [String: Any] = ["level": levelArg]
    var image: CGImage
    // Pixels per point of the analyzed image, and the screen-point origin of what it shows.
    var scale: Double = 1
    var origin = CGPoint.zero
    var windowOrigin: CGPoint? = nil

    if !imageArg.isEmpty {
        guard FileManager.default.fileExists(atPath: imageArg) else {
            fail("Image not found: \(imageArg)")
        }
        guard let loaded = loadPNG(imageArg) else {
            fail("Could not read image: \(imageArg)")
        }
        image = loaded
        scale = imageScaleArg > 0 ? imageScaleArg : 1
        out["source"] = "image"
        out["path"] = imageArg
        out["mode"] = "background"
    } else {
        var target: NSRunningApplication? = nil
        if !appArg.isEmpty {
            guard let app = findRunningApp(named: appArg) else {
                fail("App not running: \(appArg)")
            }
            target = app
        }
        requireScreenRecording()

        // Foreground (or auto when the window isn't on screen): bring the app to the front for the
        // capture, then put the previously frontmost app back.
        var saved: UserState? = nil
        var fallbackReason: String? = nil
        if let app = target {
            let onScreen = frontWindow(pid: app.processIdentifier) != nil
            if mode == .foreground || !onScreen {
                if !onScreen {
                    if mode == .background { fail("Background mode not possible for ocr: no on-screen window for app: \(appArg)") }
                    fallbackReason = "no on-screen window for app: \(appArg)"
                }
                saved = captureUserState()
                if !bringToFront(app) {
                    fail("Could not bring '\(app.localizedName ?? appArg)' to the front for capture")
                }
                usleep(300_000)
            }
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            fail("Failed to enumerate screen content: \(error.localizedDescription)")
        }

        if let app = target {
            guard let win = frontWindow(pid: app.processIdentifier) else {
                fail("No on-screen window found for app: \(appArg)")
            }
            guard let scWin = content.windows.first(where: { $0.windowID == win.id }) else {
                fail("No capturable window found for app: \(appArg)")
            }
            do {
                (image, scale) = try await captureForOCR(filter: SCContentFilter(desktopIndependentWindow: scWin), size: win.frame.size)
            } catch {
                fail("Failed to capture window for app '\(appArg)': \(error.localizedDescription)")
            }
            origin = win.frame.origin
            windowOrigin = win.frame.origin
            out["source"] = "window"
            out["app"] = app.localizedName ?? appArg
            out["window"] = ["id": Int(win.id), "title": win.title, "frame": frameJSON(win.frame)]
        } else {
            let mainID = CGMainDisplayID()
            guard let display = content.displays.first(where: { $0.displayID == mainID }) ?? content.displays.first else {
                fail("No display found to capture")
            }
            let bounds = CGDisplayBounds(display.displayID)
            do {
                (image, scale) = try await captureForOCR(filter: SCContentFilter(display: display, excludingWindows: []), size: bounds.size)
            } catch {
                fail("Failed to capture the main display: \(error.localizedDescription)")
            }
            origin = bounds.origin
            out["source"] = "screen"
            out["display"] = ["id": Int(display.displayID), "frame": frameJSON(bounds)]
        }

        out["mode"] = saved == nil ? "background" : "foreground"
        if let reason = fallbackReason { out["fallbackReason"] = reason }
        if let state = saved {
            usleep(150_000)
            out["restored"] = restoreUserState(state)
        }
    }

    // Convert image pixels to points in the coordinate space 'click' uses.
    func toPoints(_ r: CGRect) -> CGRect {
        return CGRect(x: origin.x + r.origin.x / scale, y: origin.y + r.origin.y / scale,
                      width: r.width / scale, height: r.height / scale)
    }

    var lines: [[String: Any]] = []
    for line in recognizeText(image, level: levelArg, languages: languages, filter: filter) {
        let frame = toPoints(line.box)
        var entry: [String: Any] = [
            "text": line.text,
            "confidence": NSDecimalNumber(string: String(format: "%.2f", line.confidence)),
            "frame": rectJSON(frame),
            "center": centerJSON(frame)
        ]
        if let o = windowOrigin { entry["windowCenter"] = centerJSON(frame, minus: o) }
        if let m = line.matchBox {
            let mf = toPoints(m)
            var match: [String: Any] = ["frame": rectJSON(mf), "center": centerJSON(mf)]
            if let o = windowOrigin { match["windowCenter"] = centerJSON(mf, minus: o) }
            entry["match"] = match
        }
        lines.append(entry)
    }

    out["width"] = round1(Double(image.width) / scale)
    out["height"] = round1(Double(image.height) / scale)
    out["scale"] = round1(scale)
    if !filter.isEmpty { out["text"] = filter }
    out["matches"] = lines
    printJSON(out)
}

// MARK: - entrypoint

let allArgs = CommandLine.arguments
guard allArgs.count > 1 else {
    fail("Usage: aux4-computer-mac <command> [args...]")
}
let command = allArgs[1]
let rest = Array(allArgs.dropFirst(2))

switch command {
case "permissions": cmdPermissions()
case "cursor": cmdCursor()
case "screen": cmdScreen()
case "apps": cmdApps()
case "windows": cmdWindows()
case "open": cmdOpen(rest)
case "focus": cmdFocus(rest)
case "read": cmdRead(rest)
case "find": cmdFind(rest)
case "click": cmdClick(rest)
case "move": cmdMove(rest)
case "drag": cmdDrag(rest)
case "scroll": cmdScroll(rest)
case "type": cmdType(rest)
case "shortcut": cmdShortcut(rest)
case "screenshot":
    // Window capture needs a CoreGraphics session; without it macOS aborts with a
    // CGS_REQUIRE_INIT assertion. NSApplication.shared sets it up without activating anything.
    _ = NSApplication.shared
    await cmdScreenshot(rest)
case "ocr":
    _ = NSApplication.shared
    await cmdOcr(rest)
case "clipboard-read": cmdClipboardRead()
case "clipboard-copy": cmdClipboardCopy(rest)
case "clipboard-paste": cmdClipboardPaste(rest)
default:
    fail("Unknown command: \(command)")
}
