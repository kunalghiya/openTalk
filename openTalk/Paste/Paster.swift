import AppKit
import ApplicationServices

struct PasteboardSnapshot {
    private let entries: [(NSPasteboard.PasteboardType, Data)]

    static func capture(_ pb: NSPasteboard) -> PasteboardSnapshot {
        let types = pb.types ?? []
        var entries: [(NSPasteboard.PasteboardType, Data)] = []
        for t in types {
            if let d = pb.data(forType: t) { entries.append((t, d)) }
        }
        return PasteboardSnapshot(entries: entries)
    }

    func restore(into pb: NSPasteboard) {
        pb.clearContents()
        for (type, data) in entries {
            pb.setData(data, forType: type)
        }
    }
}

@MainActor
final class Paster {
    private let restoreDelayMs: () -> Int

    init(restoreDelayMs: @escaping () -> Int) {
        self.restoreDelayMs = restoreDelayMs
    }

    /// True iff the running process is allowed to post synthetic key events.
    static func accessibilityTrusted(prompt: Bool = false) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Paste `text` at the current cursor location, then restore the prior clipboard.
    /// No-op (with a log) if Accessibility isn't granted — without it, synthesizing
    /// ⌘V silently fails and we'd otherwise have already clobbered the clipboard.
    func paste(_ text: String) {
        guard !text.isEmpty else { return }
        guard Self.accessibilityTrusted() else {
            NSLog("openTalk: paste skipped — Accessibility not granted; transcript: \(text)")
            return
        }

        let pb = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)
        let changeCountAtPaste = pb.changeCount

        synthesizeCmdV()

        let delay = max(100, restoreDelayMs())
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
            // Don't clobber a clipboard the user (or another tool, e.g. Raycast,
            // Maccy) wrote between our paste and the restore deadline.
            guard pb.changeCount == changeCountAtPaste else { return }
            snapshot.restore(into: pb)
        }
    }

    private func synthesizeCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // ANSI 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        let tap = CGEventTapLocation.cghidEventTap
        down?.post(tap: tap)
        up?.post(tap: tap)
    }
}
