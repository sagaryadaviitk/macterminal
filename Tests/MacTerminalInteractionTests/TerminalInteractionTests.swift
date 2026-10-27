import AppKit
import XCTest
@testable import MacTerminal

final class TerminalInteractionTests: XCTestCase {
    @MainActor
    func testTerminalNeverContributesToWindowDragging() async {
        _ = NSApplication.shared
        let view = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        XCTAssertFalse(view.mouseDownCanMoveWindow)
    }

    @MainActor
    func testClickingInactiveTerminalFocusesAndReportsTheNewPane() async {
        _ = NSApplication.shared
        let window = TerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let first = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
        let second = FocusReportingTerminalView(frame: NSRect(x: 320, y: 0, width: 320, height: 400))
        window.contentView?.addSubview(first)
        window.contentView?.addSubview(second)
        var focusedPane = 0
        first.onFocus = { focusedPane = 1 }
        second.onFocus = { focusedPane = 2 }
        XCTAssertTrue(window.makeFirstResponder(first))
        // Programmatic focus does not represent a click into a different pane.
        let click = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 350, y: 100),
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        )!
        window.sendEvent(click)
        XCTAssertEqual(focusedPane, 2)
        XCTAssertTrue(window.firstResponder === second)
    }

    @MainActor
    func testSingleMovementDragStartsAtMouseDown() async {
        _ = NSApplication.shared
        let window = TerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let terminal = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        terminal.setUseMetal(false)
        window.contentView = terminal
        terminal.feed(text: "SELECT_THIS_TEXT_12345")
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let rowHeight = terminal.bounds.height / CGFloat(terminal.getTerminal().rows)
        let y = terminal.bounds.height - rowHeight / 2
        func mouse(_ type: NSEvent.EventType, x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(
                with: type, location: NSPoint(x: x, y: y), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 1, clickCount: 1, pressure: 1
            )!
        }
        window.sendEvent(mouse(.leftMouseDown, x: 1))
        window.sendEvent(mouse(.leftMouseDragged, x: 160))
        window.sendEvent(mouse(.leftMouseUp, x: 160))
        let selection = terminal.selectedRange()
        XCTAssertEqual(selection.location, 0)
        XCTAssertGreaterThan(selection.length, 1)
    }

}
