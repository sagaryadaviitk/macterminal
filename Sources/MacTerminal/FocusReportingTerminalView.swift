import AppKit
import SwiftTerm

final class FocusReportingTerminalView: LocalProcessTerminalView {
    var onFocus: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }
}

final class TerminalWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, let contentView {
            let point = contentView.superview?.convert(event.locationInWindow, from: nil)
                ?? event.locationInWindow
            var hitView = contentView.hitTest(point)
            while let view = hitView {
                if let terminal = view as? FocusReportingTerminalView {
                    // Focus before SwiftTerm handles selection. Do not consume or
                    // replace its event: mouse reporting and selection still work.
                    if makeFirstResponder(terminal) {
                        terminal.onFocus?()
                    }
                    break
                }
                hitView = view.superview
            }
        }
        super.sendEvent(event)
    }
}
