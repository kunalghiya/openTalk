import Foundation

enum ModelManager {
    /// Shown immediately while the async fetch is in flight, and as a
    /// fallback if the network is unavailable.
    static let fallbackModelNames: [String] = [
        "openai_whisper-tiny.en",
        "openai_whisper-base.en",
        "openai_whisper-small.en",
        "openai_whisper-tiny",
        "openai_whisper-base",
    ]

    /// Display label derived from a raw WhisperKit model name.
    /// e.g. "openai_whisper-large-v3-turbo" → "Large v3 Turbo"
    ///      "openai_whisper-base.en"        → "Base (English)"
    ///      "distil-whisper_distil-large-v3" → "Distil Large v3"
    static func displayLabel(for modelName: String) -> String {
        var s = modelName
        if let r = s.range(of: "openai_whisper-") { s.removeSubrange(r) }
        if let r = s.range(of: "distil-whisper_") { s.removeSubrange(r) }
        var english = false
        if s.hasSuffix(".en") {
            english = true
            s = String(s.dropLast(".en".count))
        }
        let pieces = s.split(separator: "-").map { piece -> String in
            let str = String(piece)
            if str.first?.isLetter != true { return str }
            if str.allSatisfy({ $0.isLetter }) {
                return str.prefix(1).uppercased() + str.dropFirst()
            }
            return str
        }
        var pretty = pieces.joined(separator: " ")
        if english { pretty += " (English)" }
        return pretty.isEmpty ? modelName : pretty
    }

    /// Order models in a human-friendly progression: tiny → base → small →
    /// medium → large, with .en variants directly after their non-.en sibling,
    /// then any "distil-" variants, then everything else alphabetically.
    static func sortedForDisplay(_ names: [String]) -> [String] {
        let sizeOrder = ["tiny", "base", "small", "medium", "large"]
        func bucket(for name: String) -> (Int, Int, Int, String) {
            let isDistil = name.hasPrefix("distil-") ? 1 : 0
            let lower = name.lowercased()
            var sizeRank = sizeOrder.count + 1
            for (i, sz) in sizeOrder.enumerated() where lower.contains(sz) {
                sizeRank = i
                break
            }
            let isEnglish = name.contains(".en") ? 1 : 0
            return (isDistil, sizeRank, isEnglish, name)
        }
        return names.sorted { a, b in
            let ba = bucket(for: a)
            let bb = bucket(for: b)
            if ba.0 != bb.0 { return ba.0 < bb.0 }
            if ba.1 != bb.1 { return ba.1 < bb.1 }
            if ba.2 != bb.2 { return ba.2 < bb.2 }
            return ba.3 < bb.3
        }
    }
}
