import AppKit
import ApplicationServices
import CoreText
import Foundation

// MARK: - screenshot --annotate (numbered set-of-marks boxes over the accessibility tree)

// Roles an agent can act on: what --roles actionable (the default) marks.
let actionableMarkRoles: Set<String> = [
    "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
    "AXMenuButton", "AXComboBox", "AXSearchField", "AXSecureTextField", "AXSlider", "AXIncrementor",
    "AXTab", "AXRow", "AXMenuItem", "AXMenuBarItem", "AXDisclosureTriangle", "AXSwitch", "AXColorWell"
]

// --roles all also marks what an agent reads: text, images, headings, cells, indicators.
let readableMarkRoles: Set<String> = [
    "AXStaticText", "AXImage", "AXHeading", "AXCell", "AXProgressIndicator", "AXLevelIndicator",
    "AXValueIndicator", "AXBusyIndicator"
]

// Controls whose children (the label inside a button, a combo box's arrow) would only duplicate them.
let leafMarkRoles: Set<String> = [
    "AXButton", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXTextField",
    "AXSearchField", "AXSecureTextField", "AXComboBox", "AXSlider", "AXIncrementor", "AXDisclosureTriangle",
    "AXSwitch", "AXColorWell", "AXMenuItem", "AXTextArea", "AXStaticText", "AXImage"
]

// Containers that clip what's inside them: an element scrolled out of a scroll area isn't visible.
let clippingRoles: Set<String> = ["AXScrollArea", "AXWindow", "AXSheet"]

struct Mark {
    let ref: String
    let role: String
    let label: String
    let value: String
    let frame: CGRect      // the element's accessibility frame (screen points)
    let visible: CGRect    // the part of it inside the capture and its scroll areas (screen points)
}

// collectMarks walks the windows' trees and keeps the wanted roles whose visible part is at least
// a few points in each direction. Bounded in nodes and time: a huge tree yields a partial result.
func collectMarks(windows: [(AXUIElement, String)], region: CGRect, roles: Set<String>) -> (marks: [Mark], cutShort: Bool) {
    var marks: [Mark] = []
    var visited = 0
    var cutShort = false
    let started = Date()
    func visit(_ el: AXUIElement, ref: String, clip: CGRect, depth: Int) {
        if depth > 40 { return }
        if visited >= 6000 || Date().timeIntervalSince(started) > 5 { cutShort = true; return }
        visited += 1
        let role = axRole(el)
        if axBool(el, kAXHiddenAttribute) == true { return }
        var childClip = clip
        if let f = axFrame(el), f.width > 0, f.height > 0 {
            if clippingRoles.contains(role) { childClip = clip.intersection(f) }
            if roles.contains(role) {
                let vis = f.intersection(clip)
                if !vis.isNull && vis.width >= 4 && vis.height >= 4 {
                    var label = axString(el, kAXTitleAttribute) ?? axString(el, kAXDescriptionAttribute) ?? axString(el, "AXLabel") ?? ""
                    var value = axString(el, kAXValueAttribute) ?? ""
                    if label.isEmpty, textRoles.contains(role) { label = axString(el, kAXPlaceholderValueAttribute) ?? "" }
                    if label.isEmpty, role == "AXButton" { label = axSubrole(el) }
                    if role == "AXStaticText" && label.isEmpty { label = value; value = "" }
                    if role == "AXSecureTextField" { value = "" }
                    if role == "AXStaticText" && label.isEmpty {
                        // Empty text: nothing to show.
                    } else {
                        marks.append(Mark(ref: ref, role: role, label: label, value: value, frame: f, visible: vis))
                    }
                    if leafMarkRoles.contains(role) { return }
                }
            }
        }
        if childClip.isNull || childClip.width < 1 || childClip.height < 1 { return }
        if role == "AXTextArea" || role == "AXStaticText" { return }
        for (i, child) in axChildren(el).enumerated() {
            visit(child, ref: ref.isEmpty ? "\(i)" : "\(ref).\(i)", clip: childClip, depth: depth + 1)
        }
    }
    for (window, ref) in windows {
        visit(window, ref: ref, clip: region, depth: 0)
    }
    // Reading order: rows top to bottom (elements whose centers are within a few points share a
    // row), left to right inside a row.
    let sorted = marks.sorted { a, b in
        let ay = (a.visible.midY / 8).rounded(), by = (b.visible.midY / 8).rounded()
        if ay != by { return ay < by }
        return a.visible.minX < b.visible.minX
    }
    return (sorted, cutShort)
}

// markWindows picks the accessibility windows to annotate: with an app window capture, the AX
// window at that frame (plus its sheets, which are its children); for a display, the frontmost app's
// windows on that display.
func markWindows(axApp: AXUIElement, capturedFrame: CGRect?, region: CGRect) -> [(AXUIElement, String)] {
    let windows = axWindows(axApp)
    var picked: [AXUIElement] = []
    if let cf = capturedFrame {
        if let w = windows.first(where: { w in
            guard let f = axFrame(w) else { return false }
            return abs(f.minX - cf.minX) < 2 && abs(f.minY - cf.minY) < 2 && abs(f.width - cf.width) < 2 && abs(f.height - cf.height) < 2
        }) {
            picked = [w]
        } else if let main = axElementAttr(axApp, kAXMainWindowAttribute) ?? windows.first {
            picked = [main]
        }
    } else {
        picked = windows.filter { w in
            guard let f = axFrame(w) else { return false }
            return f.intersects(region) && axBool(w, kAXMinimizedAttribute) != true
        }
    }
    return picked.compactMap { w in axRefOf(w, in: axApp).map { (w, $0) } }
}

let markPalette: [(CGFloat, CGFloat, CGFloat)] = [
    (0.90, 0.10, 0.29), (0.00, 0.36, 0.90), (0.00, 0.55, 0.24),
    (0.96, 0.51, 0.00), (0.57, 0.12, 0.71), (0.00, 0.50, 0.50)
]

// drawMarks draws each mark's box and its number onto the image. Rects are in image pixels with a
// top-left origin. Number tags try a few spots around the box and take the first one that stays
// inside the image and doesn't cover another tag.
func drawMarks(_ image: CGImage, _ boxes: [(Int, CGRect)], pixelsPerPoint k: CGFloat) -> CGImage? {
    let width = image.width
    let height = image.height
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let H = CGFloat(height)
    let W = CGFloat(width)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
    // Work in top-left coordinates like the marks: flip once.
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)

    let lineWidth = max(2, (1.5 * k).rounded())
    let fontSize = min(max(11, (11 * k).rounded()), 30)
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    let pad = max(2, (2 * k).rounded())
    var placed: [CGRect] = []

    for (n, box) in boxes {
        let c = markPalette[(n - 1) % markPalette.count]
        let color = CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(lineWidth)
        ctx.stroke(box.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))

        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): white
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "\(n)", attributes: attrs))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let tagW = (textWidth + 2 * pad).rounded(.up)
        let tagH = (ascent + descent + 2 * pad).rounded(.up)
        let candidates = [
            CGRect(x: box.minX, y: box.minY - tagH, width: tagW, height: tagH),          // above, left
            CGRect(x: box.minX, y: box.minY, width: tagW, height: tagH),                 // inside, top left
            CGRect(x: box.maxX - tagW, y: box.minY - tagH, width: tagW, height: tagH),   // above, right
            CGRect(x: box.minX - tagW, y: box.minY, width: tagW, height: tagH),          // left of the box
            CGRect(x: box.maxX, y: box.minY, width: tagW, height: tagH),                 // right of the box
            CGRect(x: box.minX, y: box.maxY, width: tagW, height: tagH),                 // below, left
            CGRect(x: box.maxX - tagW, y: box.maxY - tagH, width: tagW, height: tagH)    // inside, bottom right
        ]
        let bounds = CGRect(x: 0, y: 0, width: W, height: H)
        let inImage = candidates.filter { bounds.contains($0) }
        var tag = inImage.first(where: { r in !placed.contains(where: { $0.intersects(r) }) })
            ?? inImage.first
            ?? CGRect(x: min(max(box.minX, 0), max(W - tagW, 0)), y: min(max(box.minY, 0), max(H - tagH, 0)), width: tagW, height: tagH)
        tag = tag.integral
        placed.append(tag)
        ctx.setFillColor(color)
        ctx.fill(tag)
        // A thin white edge keeps a tag readable on top of a box of the same color.
        ctx.setStrokeColor(white)
        ctx.setLineWidth(1)
        ctx.stroke(tag.insetBy(dx: 0.5, dy: 0.5))
        // Text is drawn in an unflipped space at its baseline.
        ctx.saveGState()
        ctx.translateBy(x: tag.minX + pad, y: tag.maxY - pad - descent)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
    return ctx.makeImage()
}

struct AnnotateResult {
    let image: CGImage
    let out: [String: Any]
}

// annotateScreenshot finds the marks for the captured region, draws them on the (already resized)
// image and returns the marks JSON. region is the capture in screen points; windowOrigin is set for
// an app window capture (windowCenter is relative to it, like find/click --app).
func annotateScreenshot(_ image: CGImage, region: CGRect, capturedWindow: CGRect?, pid: pid_t, roles: String, limit: Int) -> AnnotateResult {
    let wanted: Set<String> = roles == "all" ? actionableMarkRoles.union(readableMarkRoles) : actionableMarkRoles
    let axApp = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(axApp, 2.0)
    let windows = markWindows(axApp: axApp, capturedFrame: capturedWindow, region: region)
    let (all, cutShort) = collectMarks(windows: windows, region: region, roles: wanted)
    let shown = Array(all.prefix(limit))
    let k = CGFloat(image.width) / max(region.width, 1)
    var boxes: [(Int, CGRect)] = []
    var marks: [[String: Any]] = []
    for (i, m) in shown.enumerated() {
        let n = i + 1
        let px = CGRect(x: ((m.visible.minX - region.minX) * k).rounded(), y: ((m.visible.minY - region.minY) * k).rounded(),
                        width: (m.visible.width * k).rounded(), height: (m.visible.height * k).rounded())
        boxes.append((n, px))
        var e: [String: Any] = [
            "n": n,
            "ref": m.ref,
            "role": m.role,
            "label": m.label.count > 80 ? String(m.label.prefix(80)) + "…" : m.label,
            "frame": frameJSON(m.frame),
            // The center of the visible part: a point that lands on the element on screen.
            "center": centerJSON(m.visible),
            "image": ["x": Int(px.minX), "y": Int(px.minY), "width": Int(px.width), "height": Int(px.height)]
        ]
        if !m.value.isEmpty { e["value"] = m.value.count > 80 ? String(m.value.prefix(80)) + "…" : m.value }
        if let w = capturedWindow { e["windowCenter"] = centerJSON(m.visible, minus: w.origin) }
        marks.append(e)
    }
    var out: [String: Any] = ["annotated": true, "roles": roles, "marks": marks]
    if all.count > shown.count || cutShort {
        out["truncated"] = true
        out["note"] = cutShort
            ? "stopped walking a large accessibility tree: showing \(shown.count) marks; use --app for one window or 'find' for more"
            : "showing \(shown.count) of \(all.count) marks (--limit \(limit)); raise --limit or use 'find'"
    }
    if windows.isEmpty { out["note"] = "no accessibility window found for the captured area: no marks drawn" }
    let drawn = drawMarks(image, boxes, pixelsPerPoint: k) ?? image
    return AnnotateResult(image: drawn, out: out)
}
