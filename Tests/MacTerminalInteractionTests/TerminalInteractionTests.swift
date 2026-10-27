import AppKit
import XCTest
@testable import SwiftTerm
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
    func testSingleMovementDragStartsAtMouseDown() async throws {
        _ = NSApplication.shared
        let window = TerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let terminal = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        try terminal.setUseMetal(false)
        window.contentView = terminal
        terminal.feed(text: "SELECT_THIS_TEXT_12345")
        let rowHeight = terminal.bounds.height / CGFloat(terminal.getTerminal().rows)
        let y = terminal.bounds.height - rowHeight / 2
        func mouse(_ type: NSEvent.EventType, x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(
                with: type, location: NSPoint(x: x, y: y), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 1, clickCount: 1, pressure: 1
            )!
        }
        let down = mouse(.leftMouseDown, x: 1)
        let drag = mouse(.leftMouseDragged, x: 160)
        // Exercise the window hook and SwiftTerm together without relying on
        // AppKit dispatch to a foreground application in the headless runner.
        window.sendEvent(down)
        terminal.mouseDown(with: down)
        window.sendEvent(drag)
        terminal.mouseDragged(with: drag)
        terminal.mouseUp(with: mouse(.leftMouseUp, x: 160))
        let selection = terminal.selectedRange()
        XCTAssertEqual(selection.location, 0)
        XCTAssertGreaterThan(selection.length, 1)
    }

    @MainActor
    func testSelectionForegroundOverridesOnlySelectedText() async throws {
        _ = NSApplication.shared
        let terminal = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        try terminal.setUseMetal(false)
        terminal.feed(text: "\u{1B}[32mSUCCESS\u{1B}[0m")
        let engine = terminal.getTerminal()
        let line = try XCTUnwrap(engine.getLine(row: 0))
        func foreground() throws -> NSColor {
            let rendered = terminal.buildAttributedString(row: 0, line: line, cols: engine.cols)
            let segment = try XCTUnwrap(rendered.segments.first)
            return try XCTUnwrap(segment.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        }
        let original = try foreground()
        let selected = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        terminal.selectedTextForegroundColor = selected
        terminal.selectAll()
        XCTAssertEqual(try foreground(), selected)
        terminal.selectNone()
        XCTAssertEqual(try foreground(), original)
        terminal.selectedTextForegroundColor = nil
        terminal.selectAll()
        XCTAssertEqual(try foreground(), original)
    }

}
