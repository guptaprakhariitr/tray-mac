import Foundation

// MARK: - Clip model

/// What a captured clipboard entry looks like.
public enum ClipKind: String, Sendable {
    case text, url, color, image
}

/// A single clipboard-history entry.
public struct ClipItem: Identifiable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    public var text: String
    public var date: Date
    public var pinned: Bool

    public init(id: UUID = UUID(), kind: ClipKind, text: String, date: Date = Date(), pinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.date = date
        self.pinned = pinned
    }
}

// MARK: - Classification

/// Classify a string into a `ClipKind`:
/// - URL (`http://`, `https://`, or `www.`)
/// - hex color (`#RGB` / `#RRGGBB`)
/// - otherwise plain text.
public func classify(_ s: String) -> ClipKind {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") {
        return .url
    }
    if isHexColor(trimmed) { return .color }
    return .text
}

private func isHexColor(_ s: String) -> Bool {
    guard s.hasPrefix("#") else { return false }
    let hex = s.dropFirst()
    guard hex.count == 3 || hex.count == 6 else { return false }
    return hex.allSatisfy { $0.isHexDigit }
}

// MARK: - Inline arithmetic for notes

/// If `line` is a pure arithmetic expression (digits, `+ - * /`, `.`, parens,
/// and optional full-width parens), evaluate it via `NSExpression` and return
/// the result string; otherwise `nil`.
///
/// e.g. `"12*3"` → `"36"`, `"（2+2)/4"` → `"1"`, `"hello"` → `nil`.
public func evaluateInline(_ line: String) -> String? {
    // Normalise full-width parens that sneak in from CJK keyboards.
    let normalised = line
        .replacingOccurrences(of: "（", with: "(")
        .replacingOccurrences(of: "）", with: ")")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalised.isEmpty else { return nil }

    // Must be a *pure* arithmetic expression: only these characters.
    let allowed = CharacterSet(charactersIn: "0123456789+-*/.() ")
    guard normalised.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    // Need at least one operator so a bare number isn't "evaluated".
    guard normalised.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/")) != nil else { return nil }
    // Need at least one digit.
    guard normalised.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }

    // Force floating-point arithmetic: NSExpression does integer division for
    // integer literals (10/4 -> 2), so turn bare integers into doubles.
    let floated = floatify(normalised)

    let expr = NSExpression(format: floated)
    guard let value = expr.expressionValue(with: nil, context: nil) as? NSNumber else { return nil }

    let d = value.doubleValue
    guard d.isFinite else { return nil }
    if d == d.rounded() && abs(d) < 1e15 {
        return String(Int(d))
    }
    return String(d)
}

/// Append `.0` to integer literals so NSExpression uses floating-point division.
private func floatify(_ s: String) -> String {
    var out = ""
    let chars = Array(s)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if c.isNumber {
            var num = ""
            var sawDot = false
            while i < chars.count, chars[i].isNumber || chars[i] == "." {
                if chars[i] == "." { sawDot = true }
                num.append(chars[i])
                i += 1
            }
            out += sawDot ? num : num + ".0"
            continue
        }
        out.append(c)
        i += 1
    }
    return out
}

// MARK: - ClipboardStore

/// In-memory clipboard history with classification, consecutive de-duplication,
/// pinning and search. Capped to avoid unbounded growth.
@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    public let capacity: Int

    public init(capacity: Int = 200) {
        self.capacity = capacity
    }

    /// Add a captured string. Classifies it, ignores empties, and de-dupes when
    /// it matches the most-recent (non-pinned) entry's text.
    public func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let first = items.first, first.text == trimmed { return }

        let item = ClipItem(kind: classify(trimmed), text: trimmed)
        items.insert(item, at: 0)
        trim()
    }

    /// Case-insensitive substring search over the history text.
    public func search(_ q: String) -> [ClipItem] {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { $0.text.range(of: query, options: .caseInsensitive) != nil }
    }

    /// Toggle the pinned state of an item by id.
    public func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
    }

    private func trim() {
        guard items.count > capacity else { return }
        // Keep pinned items even past the cap; drop oldest unpinned first.
        var overflow = items.count - capacity
        var i = items.count - 1
        while overflow > 0 && i >= 0 {
            if !items[i].pinned {
                items.remove(at: i)
                overflow -= 1
            }
            i -= 1
        }
    }
}
