import AppKit
import SwiftTerm

final class FocusReportingTerminalView: LocalProcessTerminalView {
    var onFocus: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }
}

final class TerminalWindow: NSWindow {
    private weak var selectionTerminal: FocusReportingTerminalView?
    private var selectionMouseDown: NSEvent?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            selectionTerminal = nil
            selectionMouseDown = nil
        }
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
                    if event.clickCount == 1 && !event.modifierFlags.contains(.shift) {
                        selectionTerminal = terminal
                        selectionMouseDown = event
                    }
                    break
                }
                hitView = view.superview
            }
        }
        if event.type == .leftMouseDragged,
           let terminal = selectionTerminal, let mouseDown = selectionMouseDown {
            selectionMouseDown = nil
            // SwiftTerm starts selection at its first drag event rather than at
            // mouse-down. Seed that anchor before forwarding the real movement,
            // even when macOS coalesces the entire drag into one event.
            if !terminal.allowMouseReporting || terminal.getTerminal().mouseMode == .off {
                terminal.mouseDragged(with: mouseDown)
            }
        }
        if event.type == .leftMouseUp {
            selectionTerminal = nil
            selectionMouseDown = nil
        }
        super.sendEvent(event)
    }
}
