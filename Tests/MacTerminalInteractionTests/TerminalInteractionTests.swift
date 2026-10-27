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
}
