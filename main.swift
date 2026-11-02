import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

// MARK: - JSON helpers

func printJSON(_ obj: Any) {
    guard JSONSerialization.isValidJSONObject(obj) else {
        FileHandle.standardOutput.write("{\"error\":\"internal: invalid JSON object\"}\n".data(using: .utf8)!)
        return
    }
    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    } else {
        print("{\"error\":\"internal: failed to encode JSON\"}")
    }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    guard let data = try? JSONSerialization.data(withJSONObject: ["error": message], options: [.sortedKeys]) else {
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
    return AXIsProcessTrusted()
}

func screenRecordingGranted() -> Bool {
    return CGPreflightScreenCaptureAccess()
}

func requireAccessibility() {
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

func cmdOpen(_ args: [String]) {
    let appName = argAt(args, 0)
    if appName.isEmpty {
        fail("--app is required")
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appName]
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
    printJSON(["opened": appName])
}

func cmdFocus(_ args: [String]) {
    let appName = argAt(args, 0)
    if appName.isEmpty {
        fail("--app is required")
    }
    guard let app = findRunningApp(named: appName) else {
        fail("App not running: \(appName)")
    }
    let activated = app.activate(options: [])
    printJSON(["focused": app.localizedName ?? appName, "success": activated])
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
        }
        matches.append(entry)
    }
    printJSON(["app": name, "matches": matches])
}

// MARK: - mouse control

func postMouseEvent(type: CGEventType, point: CGPoint, button: CGMouseButton, clickCount: Int64 = 1) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
    event.setIntegerValueField(.mouseEventClickState, value: clickCount)
    event.post(tap: .cghidEventTap)
}

func cmdMove(_ args: [String]) {
    requireAccessibility()
    let x = parseDouble(argAt(args, 0))
    let y = parseDouble(argAt(args, 1))
    let point = CGPoint(x: x, y: y)
    postMouseEvent(type: .mouseMoved, point: point, button: .left)
    printJSON(["x": x, "y": y])
}

func cmdClick(_ args: [String]) {
    requireAccessibility()
    let xStr = argAt(args, 0)
    let yStr = argAt(args, 1)
    let buttonStr = argAt(args, 2)
    let count = max(parseInt(argAt(args, 3), default: 1), 1)
    let elementRef = argAt(args, 4)
    let appArg = argAt(args, 5)

    if !elementRef.isEmpty {
        guard let (root, name) = axRootElements(forAppNamed: appArg) else {
            fail(appArg.isEmpty ? "No frontmost application found" : "App not running: \(appArg)")
        }
        guard let element = resolveRef(root, elementRef) else {
            fail("Element not found for ref: \(elementRef)")
        }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result != .success {
            fail("Failed to click element '\(elementRef)' on app '\(name)' (AXError \(result.rawValue))")
        }
        printJSON(["clicked": elementRef, "app": name])
        return
    }

    guard !xStr.isEmpty, !yStr.isEmpty else {
        fail("Provide --x/--y or --element")
    }
    let x = parseDouble(xStr)
    let y = parseDouble(yStr)
    let point = CGPoint(x: x, y: y)
    let button: CGMouseButton = buttonStr == "right" ? .right : .left
    let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
    let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp

    for i in 1...count {
        postMouseEvent(type: downType, point: point, button: button, clickCount: Int64(i))
        postMouseEvent(type: upType, point: point, button: button, clickCount: Int64(i))
    }
    printJSON(["x": x, "y": y, "button": buttonStr.isEmpty ? "left" : buttonStr, "count": count])
}

func cmdDrag(_ args: [String]) {
    requireAccessibility()
    let x = parseDouble(argAt(args, 0))
    let y = parseDouble(argAt(args, 1))
    let toX = parseDouble(argAt(args, 2))
    let toY = parseDouble(argAt(args, 3))

    let start = CGPoint(x: x, y: y)
    let end = CGPoint(x: toX, y: toY)

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
    printJSON(["from": ["x": x, "y": y], "to": ["x": toX, "y": toY]])
}

func cmdScroll(_ args: [String]) {
    requireAccessibility()
    let xStr = argAt(args, 0)
    let yStr = argAt(args, 1)
    let dx = parseInt(argAt(args, 2))
    let dy = parseInt(argAt(args, 3))

    if !xStr.isEmpty && !yStr.isEmpty {
        let point = CGPoint(x: parseDouble(xStr), y: parseDouble(yStr))
        postMouseEvent(type: .mouseMoved, point: point, button: .left)
    }

    guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else {
        fail("Failed to create scroll event")
    }
    event.post(tap: .cghidEventTap)
    printJSON(["dx": dx, "dy": dy])
}

// MARK: - keyboard control

func cmdType(_ args: [String]) {
    requireAccessibility()
    let text = argAt(args, 0)
    let delayMs = parseInt(argAt(args, 1), default: 0)
    if text.isEmpty {
        fail("--text is required")
    }
    if delayMs > 0 {
        usleep(UInt32(delayMs) * 1000)
    }
    for scalar in text.utf16.map({ $0 }) {
        var units: [UniChar] = [scalar]
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        down.post(tap: .cghidEventTap)
        guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        up.post(tap: .cghidEventTap)
        usleep(2000)
    }
    printJSON(["typed": text.count])
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

// postShortcut posts a key combo like "cmd+c". Returns an error string on failure, nil on success.
func postShortcut(_ combo: String) -> String? {
    let parts = combo.lowercased().split(separator: "+").map { String($0) }
    guard let keyName = parts.last else {
        return "Invalid key combo: \(combo)"
    }
    guard let keyCode = keyCodeMap[keyName] else {
        return "Unknown key: \(keyName)"
    }

    var flags: CGEventFlags = []
    for modifier in parts.dropLast() {
        switch modifier {
        case "cmd", "command": flags.insert(.maskCommand)
        case "shift": flags.insert(.maskShift)
        case "alt", "option": flags.insert(.maskAlternate)
        case "ctrl", "control": flags.insert(.maskControl)
        case "fn": flags.insert(.maskSecondaryFn)
        default: return "Unknown modifier: \(modifier)"
        }
    }

    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        return "Failed to create key event"
    }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return nil
}

func cmdShortcut(_ args: [String]) {
    requireAccessibility()
    let combo = argAt(args, 0)
    let delayMs = parseInt(argAt(args, 1), default: 0)
    if combo.isEmpty {
        fail("--keys is required")
    }
    if delayMs > 0 {
        usleep(UInt32(delayMs) * 1000)
    }
    if let error = postShortcut(combo) {
        fail(error)
    }
    printJSON(["keys": combo])
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
    if !text.isEmpty {
        guard clipboardWriteText(text) else {
            fail("Failed to write to clipboard")
        }
        printJSON(["text": text])
        return
    }

    requireAccessibility()
    if let error = postShortcut("cmd+c") {
        fail(error)
    }
    usleep(200_000)
    printJSON(["text": clipboardReadText()])
}

func cmdClipboardPaste(_ args: [String]) {
    let text = argAt(args, 0)
    if !text.isEmpty {
        guard clipboardWriteText(text) else {
            fail("Failed to write to clipboard")
        }
    }

    requireAccessibility()
    if let error = postShortcut("cmd+v") {
        fail(error)
    }
    printJSON(["pasted": clipboardReadText()])
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
    requireScreenRecording()
    let outputArg = argAt(args, 0)
    let displayArg = argAt(args, 1)
    let appArg = argAt(args, 2)
    let maxWidth = parseInt(argAt(args, 3), default: 1568)

    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
        fail("Failed to enumerate screen content: \(error.localizedDescription)")
    }

    var image: CGImage?

    if !appArg.isEmpty {
        guard let app = findRunningApp(named: appArg) else {
            fail("App not running: \(appArg)")
        }
        guard let win = content.windows.first(where: { $0.owningApplication?.processID == app.processIdentifier }) else {
            fail("No window found for app: \(appArg)")
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

    printJSON(["path": outputPath, "width": resized.width, "height": resized.height, "scale": Double(resized.width) / Double(max(cgImage.width, 1))])
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
case "screenshot": await cmdScreenshot(rest)
case "clipboard-read": cmdClipboardRead()
case "clipboard-copy": cmdClipboardCopy(rest)
case "clipboard-paste": cmdClipboardPaste(rest)
default:
    fail("Unknown command: \(command)")
}
