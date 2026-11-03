import AppKit
import ApplicationServices
import Foundation

// MARK: - select (text selection through Accessibility)

func cmdSelect(_ args: [String]) {
    let appArg = argAt(args, 0)
    let all = parseBoolFlag(argAt(args, 1), name: "all")
    let text = argAt(args, 2)
    let occurrenceArg = argAt(args, 3)
    let startArg = argAt(args, 4)
    let lengthArg = argAt(args, 5)
    let elementRef = argAt(args, 6)
    let mode = parseMode(argAt(args, 7))

    let byRange = !startArg.isEmpty || !lengthArg.isEmpty
    let ways = [all, !text.isEmpty, byRange].filter { $0 }.count
    if ways == 0 {
        fail("Say what to select: --all true, --text <text> [--occurrence N], or --start N --length N")
    }
    if ways > 1 {
        fail("Give only one of --all, --text, or --start/--length")
    }
    var start = 0, length = 0
    if byRange {
        guard let s = Int(startArg), s >= 0 else { fail("Invalid --start '\(startArg)': use a character offset (0 or more)") }
        guard let l = Int(lengthArg.isEmpty ? "0" : lengthArg), l >= 0 else { fail("Invalid --length '\(lengthArg)': use 0 or more characters") }
        start = s; length = l
    }
    let occurrence = occurrenceArg.isEmpty ? 1 : (Int(occurrenceArg) ?? 0)
    if occurrence < 1 { fail("Invalid --occurrence '\(occurrenceArg)': use 1 for the first match, 2 for the second...") }
    if !occurrenceArg.isEmpty && text.isEmpty { fail("--occurrence goes with --text") }
    requireAccessibility()

    var base: [String: Any] = [:]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("select", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    let element = targetElement(target, ref: elementRef)
    base["element"] = elementInfo(element, target)

    func attempt() -> BackgroundOutcome {
        let value = (axString(element, kAXValueAttribute) ?? "") as NSString
        var s = start, l = length
        if all {
            return axSelectAll(element).withMethod("accessibility")
        }
        if !text.isEmpty {
            var searchFrom = 0
            var found: NSRange? = nil
            for _ in 0..<occurrence {
                let r = value.range(of: text, options: [.caseInsensitive], range: NSRange(location: searchFrom, length: value.length - searchFrom))
                if r.location == NSNotFound { found = nil; break }
                found = r
                searchFrom = r.location + max(r.length, 1)
                if searchFrom > value.length { break }
            }
            guard let r = found else {
                let count = value.components(separatedBy: text).count - 1
                fail("Text '\(text)' \(occurrence > 1 ? "occurrence \(occurrence) " : "")not found in the element (\(count) occurrence\(count == 1 ? "" : "s"), \(value.length) characters)")
            }
            s = r.location; l = r.length
        } else if s + l > value.length {
            fail("Range \(s)+\(l) is past the end of the text (\(value.length) characters)")
        }
        return axSetSelection(element, start: s, length: l).withMethod("accessibility")
    }
    runAction("select", mode: mode, base: base, plan: .attempt(attempt), targetApp: target.app) {
        // Real input: with the app frontmost, cmd+a selects everything; anything else is retried
        // through Accessibility (some apps only accept a selection while active).
        if all {
            if let error = postCombo(parseCombo("cmd+a"), pid: nil) { fail(error) }
            usleep(150_000)
            let r = axRange(element, kAXSelectedTextRangeAttribute)
            return ["method": "keys", "start": r?.location ?? 0, "length": r?.length ?? 0,
                    "text": axString(element, kAXSelectedTextAttribute) ?? ""]
        }
        switch attempt() {
        case .done(let out): return out
        case .unavailable(let reason): fail("Could not select: \(reason)")
        }
    }
}

extension BackgroundOutcome {
    // withMethod reshapes a selection outcome for select's JSON: selected text + range.
    func withMethod(_ method: String) -> BackgroundOutcome {
        switch self {
        case .unavailable: return self
        case .done(let info):
            var text = info["text"] as? String ?? ""
            var out: [String: Any] = [
                "range": ["start": info["start"] ?? 0, "length": info["length"] ?? 0],
                "method": method
            ]
            if text.count > 4000 {
                out["selectedTruncated"] = true
                text = String(text.prefix(4000))
            }
            out["selected"] = text
            return .done(out)
        }
    }
}

// MARK: - set (field value / checkbox / popup option)

func cmdSet(_ args: [String]) {
    let appArg = argAt(args, 0)
    let elementRef = argAt(args, 1)
    let value = argAt(args, 2)
    let checkedArg = argAt(args, 3).lowercased()
    let option = argAt(args, 4)
    let mode = parseMode(argAt(args, 5))

    if elementRef.isEmpty {
        fail("--element is required: the element's ref from 'find' or 'state'")
    }
    let ways = [!value.isEmpty, !checkedArg.isEmpty, !option.isEmpty].filter { $0 }.count
    if ways == 0 { fail("Say what to set: --value <text|number>, --checked true|false, or --option <title>") }
    if ways > 1 { fail("Give only one of --value, --checked, or --option") }
    if !checkedArg.isEmpty && checkedArg != "true" && checkedArg != "false" {
        fail("Invalid --checked '\(argAt(args, 3))': use true or false")
    }
    requireAccessibility()

    var base: [String: Any] = ["element": ["ref": elementRef]]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        if !value.isEmpty && simulatedDocumentEdit() {
            base["documentEdited"] = false
            base["warning"] = documentEditWarningMessage(appArg.isEmpty ? "the app" : appArg)
        }
        runAction("set", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name
    guard let element = resolveRef(target.axApp, elementRef) else {
        fail("Element not found for ref: \(elementRef)")
    }
    var summary = elementSummary(element)
    summary["ref"] = elementRef
    base["element"] = summary
    let role = axString(element, kAXRoleAttribute) ?? ""

    func attempt() -> BackgroundOutcome {
        if !value.isEmpty { return setValue(element, role: role, value) }
        if !checkedArg.isEmpty { return setChecked(element, role: role, checkedArg == "true") }
        return setOption(element, role: role, option)
    }
    runAction("set", mode: mode, base: base, plan: .attempt(attempt), targetApp: target.app) {
        // Some apps only accept changes while active: the same accessibility change, frontmost.
        switch attempt() {
        case .done(let out): return out
        case .unavailable(let reason): fail("Could not set the element: \(reason)")
        }
    }
}

func setValue(_ element: AXUIElement, role: String, _ value: String) -> BackgroundOutcome {
    guard axSettable(element, kAXValueAttribute) else {
        return .unavailable("\(role.isEmpty ? "element" : role)'s value can't be set through Accessibility")
    }
    let before = axAnyValue(element, kAXValueAttribute)
    var newValue: CFTypeRef = value as CFString
    // Sliders, steppers and other numeric values take a number.
    if before is NSNumber || ["AXSlider", "AXIncrementor", "AXLevelIndicator", "AXValueIndicator"].contains(role) {
        guard let d = Double(value) else {
            return .unavailable("\(role) takes a number, not '\(value)'")
        }
        newValue = NSNumber(value: d)
    }
    let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue)
    if result != .success {
        return .unavailable("setting AXValue failed (AXError \(result.rawValue))")
    }
    usleep(50_000)
    let after = axAnyValue(element, kAXValueAttribute)
    var info: [String: Any] = ["method": "AXValue", "before": truncatedValue(before), "after": truncatedValue(after)]
    if let w = documentEditWarning(element, app: appNameFor(element) ?? role) {
        info["documentEdited"] = w.documentEdited
        info["warning"] = w.warning
    }
    return .done(info)
}

// appNameFor reads the owning application's name for an element, for the warning message
// ("shortcut cmd+s --app <name>"). Walks up to the AXApplication ancestor.
func appNameFor(_ element: AXUIElement) -> String? {
    var current: AXUIElement? = element
    for _ in 0..<40 {
        guard let el = current else { return nil }
        if axRole(el) == kAXApplicationRole {
            return axString(el, kAXTitleAttribute)
        }
        current = axParent(el)
    }
    return nil
}

func truncatedValue(_ v: AnyObject?) -> Any {
    let j = jsonValue(v)
    if let s = j as? String, s.count > 500 { return String(s.prefix(500)) + "…" }
    return j
}

func setChecked(_ element: AXUIElement, role: String, _ want: Bool) -> BackgroundOutcome {
    func state() -> Int? { (axAnyValue(element, kAXValueAttribute) as? NSNumber)?.intValue }
    guard let before = state() else {
        return .unavailable("\(role.isEmpty ? "element" : role) has no checked state (expected a checkbox, radio button or switch)")
    }
    guard axActions(element).contains(kAXPressAction) else {
        return .unavailable("\(role) can't be pressed through Accessibility")
    }
    // A mixed checkbox (2) may need two presses to reach on/off. A press that changes nothing isn't
    // repeated: the app may have acted on it anyway (some only update the state while in front), and
    // pressing again could toggle it back.
    var presses = 0
    var current = before
    while (current == 1) != want && presses < 2 {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result != .success { return .unavailable("AXPress failed (AXError \(result.rawValue))") }
        presses += 1
        var next = current
        for _ in 0..<6 {
            usleep(50_000)
            next = state() ?? current
            if next != current { break }
        }
        if next == current {
            return .unavailable("pressing didn't change the element's state while \(presses == 1 ? "the app is" : "it was") in the background")
        }
        current = next
    }
    let after = current
    if (after == 1) != want {
        return .unavailable("the element is still \(after == 1 ? "checked" : "unchecked") after \(presses) presses")
    }
    return .done(["method": presses == 0 ? "unchanged" : "AXPress", "before": before == 1, "after": after == 1, "presses": presses])
}

func setOption(_ element: AXUIElement, role: String, _ option: String) -> BackgroundOutcome {
    let want = normalizeTitle(option)
    func title(_ el: AXUIElement) -> String {
        return axString(el, kAXTitleAttribute) ?? axString(el, kAXDescriptionAttribute) ?? axString(el, kAXValueAttribute) ?? ""
    }
    let before = axAnyValue(element, kAXValueAttribute)
    switch role {
    case "AXComboBox":
        return setValue(element, role: role, option)
    case "AXRadioGroup", "AXTabGroup":
        let options = axChildren(element).filter { ["AXRadioButton", "AXTab"].contains(axString($0, kAXRoleAttribute) ?? "") }
        guard let hit = options.first(where: { normalizeTitle(title($0)) == want }) else {
            return .unavailable("no option '\(option)'. Available: \(options.map(title).joined(separator: ", "))")
        }
        let result = AXUIElementPerformAction(hit, kAXPressAction as CFString)
        if result != .success { return .unavailable("AXPress failed (AXError \(result.rawValue))") }
        return .done(["method": "AXPress", "before": NSNull(), "after": title(hit)])
    case "AXPopUpButton", "AXMenuButton":
        break
    default:
        return .unavailable("--option works on a pop-up button, combo box or radio group, not \(role.isEmpty ? "this element" : role)")
    }
    // The pop-up's items live in an AXMenu child; most apps only create it while the menu is open.
    func menuItems() -> [AXUIElement] {
        for child in axChildren(element) where axString(child, kAXRoleAttribute) == "AXMenu" {
            return axChildren(child).filter { axString($0, kAXRoleAttribute) == kAXMenuItemRole && !title($0).isEmpty }
        }
        return []
    }
    var items = menuItems()
    var opened = false
    if items.isEmpty {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result != .success { return .unavailable("opening the pop-up failed (AXError \(result.rawValue))") }
        opened = true
        for _ in 0..<20 where items.isEmpty {
            usleep(50_000)
            items = menuItems()
        }
    }
    func closeMenu() {
        for child in axChildren(element) where axString(child, kAXRoleAttribute) == "AXMenu" {
            AXUIElementPerformAction(child, kAXCancelAction as CFString)
        }
    }
    guard let hit = items.first(where: { normalizeTitle(title($0)) == want }) else {
        if opened { closeMenu() }
        let available = items.map(title)
        return .unavailable(available.isEmpty ? "the pop-up's options aren't available to Accessibility" : "no option '\(option)'. Available: \(available.joined(separator: ", "))")
    }
    let result = AXUIElementPerformAction(hit, kAXPressAction as CFString)
    if result != .success {
        if opened { closeMenu() }
        return .unavailable("pressing option '\(option)' failed (AXError \(result.rawValue))")
    }
    usleep(100_000)
    return .done(["method": "menu", "before": truncatedValue(before), "after": truncatedValue(axAnyValue(element, kAXValueAttribute))])
}
