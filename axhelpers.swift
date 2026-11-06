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

// MARK: - label fallback (unlabelled controls)

// axLabel resolves a human-readable label for an element. Most controls expose AXTitle or
// AXDescription, but some (NSSavePanel's name field, its "File Format" pop-up) report neither --
// an agent reading 'dialog'/'state'/'find'/'read' then sees label "" and can't tell fields apart.
// Fall back, in order: AXTitleUIElement (the AX-standard pointer from a control to the static
// text that labels it, when the app sets it), then the nearest static text to the element's left
// on the same row, then the nearest one directly above -- both scoped to the element's own
// container (its parent, or grandparent if the parent has no static text of its own, since some
// apps put the label and the control in separate sub-groups).
func axLabel(_ element: AXUIElement) -> String {
    if let t = axString(element, kAXTitleAttribute), !t.isEmpty { return t }
    if let d = axString(element, kAXDescriptionAttribute), !d.isEmpty { return d }
    if let l = axString(element, "AXLabel"), !l.isEmpty { return l }
    if let titleEl = axElementAttr(element, "AXTitleUIElement") {
        let t = axString(titleEl, kAXValueAttribute) ?? axString(titleEl, kAXTitleAttribute) ?? ""
        if !t.isEmpty { return t }
    }
    return nearbyStaticTextLabel(element)
}

func axRangesOverlap(_ aMin: CGFloat, _ aMax: CGFloat, _ bMin: CGFloat, _ bMax: CGFloat) -> Bool {
    return aMin < bMax && bMin < aMax
}

func nearbyStaticTextLabel(_ element: AXUIElement) -> String {
    guard let frame = axFrame(element) else { return "" }
    func candidates(in container: AXUIElement) -> [(CGRect, String)] {
        return descendants(container, maxDepth: 3) { el, role in role == "AXStaticText" }
            .compactMap { el -> (CGRect, String)? in
                guard let f = axFrame(el) else { return nil }
                let text = (axString(el, kAXValueAttribute) ?? axString(el, kAXTitleAttribute) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : (f, text)
            }
    }
    var pool: [(CGRect, String)] = []
    if let parent = axParent(element) {
        pool = candidates(in: parent)
        if pool.isEmpty, let grandparent = axParent(parent) {
            pool = candidates(in: grandparent)
        }
    }
    guard !pool.isEmpty else { return "" }
    let midY = frame.origin.y + frame.height / 2
    // Same row: the candidate's vertical midpoint falls within the element's vertical span.
    let sameRow = pool.filter { $0.0.origin.y <= midY && $0.0.origin.y + $0.0.height >= midY }
    let left = sameRow.filter { $0.0.origin.x + $0.0.width <= frame.origin.x + 2 }
    if let nearest = left.max(by: { $0.0.origin.x < $1.0.origin.x }) { return nearest.1 }
    // Directly above: horizontally overlapping, ends at or before the element's top.
    let above = pool.filter {
        $0.0.origin.y + $0.0.height <= frame.origin.y + 2
            && axRangesOverlap($0.0.minX, $0.0.maxX, frame.minX, frame.maxX)
    }
    if let nearest = above.max(by: { $0.0.origin.y < $1.0.origin.y }) { return nearest.1 }
    return ""
}

// MARK: - silent data-loss warning (Accessibility text edit in a document window)

// documentWindow walks up from element to the ancestor AXWindow, returning it only when it
// looks like a document window (exposes AXDocument, i.e. it's backed by a file / NSDocument).
// A window with no AXDocument (most panels, Calculator, dialogs) isn't one.
func documentWindow(_ element: AXUIElement) -> AXUIElement? {
    var current: AXUIElement? = element
    for _ in 0..<40 {
        guard let el = current else { return nil }
        if axRole(el) == kAXWindowRole {
            return axString(el, kAXDocumentAttribute) != nil ? el : nil
        }
        current = axParent(el)
    }
    return nil
}

// documentEditWarning flags the silent-data-loss case: setting text through Accessibility
// (type/set --value/clipboard paste in the background) changes an element's value, but macOS
// only marks a document window "edited" (dot in the close button, "keep changes?" sheet on
// close) when the change comes from real keystrokes or a menu action -- never from
// AXUIElementSetAttributeValue. So the window's edited flag stays false and closing it discards
// the text with no prompt. AXModified isn't a standard attribute most apps expose, but when an
// app does expose it and it already reads true, the app is tracking the edit some other way and
// there's nothing to warn about.
func documentEditWarning(_ element: AXUIElement, app: String) -> (documentEdited: Bool, warning: String)? {
    guard let window = documentWindow(element) else { return nil }
    if axBool(window, "AXModified") == true { return nil }
    return (false, documentEditWarningMessage(app))
}

// documentEditWarningMessage builds the warning text; shared with the AUX4_COMPUTER_MAC_SIMULATE_DOCUMENT_EDIT
// dry-run seam so the real and simulated outputs are the same shape.
func documentEditWarningMessage(_ app: String) -> String {
    return "This edit went through Accessibility, not real keystrokes: \(app) does not mark the document edited, so closing the window now would discard it without asking. Save explicitly first (e.g. 'shortcut cmd+s --app \(app)' or 'menu --path \"File > Save\" --app \(app)'), or re-run with --mode foreground to type real keystrokes."
}
