import AppKit
import ApplicationServices
import Foundation

// MARK: - shared accessibility helpers for menu / select / set / state / dialog

// axRefOf computes an element's ref (the child-index path 'read' and 'find' print, which
// 'click --element' and 'set --element' accept) by walking up to the app element.
func axRefOf(_ element: AXUIElement, in app: AXUIElement) -> String? {
    var parts: [Int] = []
    var current = element
    for _ in 0..<40 {
        if CFEqual(current, app) { return parts.reversed().map(String.init).joined(separator: ".") }
        guard let parent = axParent(current) else {
            return nil
        }
        guard let idx = axChildren(parent).firstIndex(where: { CFEqual($0, current) }) else { return nil }
        parts.append(idx)
        current = parent
    }
    return nil
}

// normalizeTitle makes titles comparable: case-insensitive, trailing "…" / "..." ignored, curly
// apostrophes and quotes straightened ("Don’t Save" == "don't save"), whitespace collapsed.
func normalizeTitle(_ s: String) -> String {
    var t = s.lowercased()
        .replacingOccurrences(of: "\u{2019}", with: "'")
        .replacingOccurrences(of: "\u{2018}", with: "'")
        .replacingOccurrences(of: "\u{201C}", with: "\"")
        .replacingOccurrences(of: "\u{201D}", with: "\"")
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .trimmingCharacters(in: .whitespaces)
    while t.hasSuffix("…") { t = String(t.dropLast()).trimmingCharacters(in: .whitespaces) }
    while t.hasSuffix("...") { t = String(t.dropLast(3)).trimmingCharacters(in: .whitespaces) }
    return t.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
}

func axAnyValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
}

func axRange(_ element: AXUIElement, _ attribute: String) -> CFRange? {
    guard let v = axAnyValue(element, attribute), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    guard AXValueGetValue(v as! AXValue, .cfRange, &range) else { return nil }
    return range
}

// jsonValue turns an AXValue attribute into something JSON can carry (strings, numbers, bools).
func jsonValue(_ v: AnyObject?) -> Any {
    guard let v = v else { return NSNull() }
    if let s = v as? String { return s }
    if let n = v as? NSNumber {
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
        let d = n.doubleValue
        if d == d.rounded() && abs(d) < 1e15 { return n.intValue }
        return round2(d)
    }
    return String(describing: v)
}

let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXSecureTextField"]

// The element 'select' and 'set' act on: --element ref, or the app's focused element.
func targetElement(_ target: Target, ref: String) -> AXUIElement {
    if !ref.isEmpty {
        guard let el = resolveRef(target.axApp, ref) else {
            fail("Element not found for ref: \(ref)")
        }
        return el
    }
    guard let focused = focusedElement(target) else {
        fail("\(target.name) has no focused element: pass --element <ref> (from 'find' or 'state')")
    }
    return focused
}

func elementInfo(_ element: AXUIElement, _ target: Target) -> [String: Any] {
    var info = elementSummary(element)
    if let ref = axRefOf(element, in: target.axApp) { info["ref"] = ref }
    return info
}

// axSetSelection selects range in a text element through Accessibility (works on a background
// app: no keystrokes, no focus change). Returns the selected text and range, or why not.
func axSetSelection(_ element: AXUIElement, start: Int, length: Int) -> BackgroundOutcome {
    guard axSettable(element, kAXSelectedTextRangeAttribute) else {
        let role = axString(element, kAXRoleAttribute) ?? "element"
        return .unavailable("\(role) doesn't accept an accessibility text selection")
    }
    var range = CFRange(location: start, length: length)
    guard let value = AXValueCreate(.cfRange, &range) else { return .unavailable("could not build the range") }
    let result = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
    if result != .success {
        return .unavailable("setting AXSelectedTextRange failed (AXError \(result.rawValue))")
    }
    let actual = axRange(element, kAXSelectedTextRangeAttribute) ?? range
    let selected = axString(element, kAXSelectedTextAttribute) ?? ""
    if actual.location != start || actual.length != length {
        return .unavailable("the app kept a different selection (\(actual.location), \(actual.length)) than requested (\(start), \(length))")
    }
    return .done(["start": actual.location, "length": actual.length, "text": selected])
}

func axSelectAll(_ element: AXUIElement) -> BackgroundOutcome {
    let count = axNumber(element, kAXNumberOfCharactersAttribute)
        ?? ((axString(element, kAXValueAttribute) as NSString?)?.length)
    guard let n = count else { return .unavailable("element has no text to select") }
    return axSetSelection(element, start: 0, length: n)
}
