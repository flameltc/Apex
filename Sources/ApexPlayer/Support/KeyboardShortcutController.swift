import AppKit
import Foundation

@MainActor
final class KeyboardShortcutController {
    private var monitor: Any?

    func start(onSpace: @escaping () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.shouldHandle(event: event) else { return event }
            onSpace()
            return nil
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func shouldHandle(event: NSEvent) -> Bool {
        guard event.keyCode == 49 else { return false }
        guard NSApp.isActive, NSApp.keyWindow?.isKeyWindow == true else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty else { return false }

        guard !isTextInputFocused() else { return false }
        return true
    }

    private func isTextInputFocused() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }

        if let textView = responder as? NSTextView {
            if textView.hasMarkedText() {
                return true
            }
            return textView.isEditable || textView.isFieldEditor
        }
        if responder is NSTextField {
            return true
        }
        return false
    }
}
