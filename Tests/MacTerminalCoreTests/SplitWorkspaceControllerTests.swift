import Foundation
import XCTest
@testable import MacTerminalCore

final class SplitWorkspaceControllerTests: XCTestCase {
    func testSplitActivePaneCreatesRightSidePaneAndFocusesIt() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let originalPaneID = workspace.activePaneID

        let newPaneID = workspace.splitActive(axis: .leftRight)

        XCTAssertEqual(workspace.orderedPaneIDs, [originalPaneID, newPaneID])
        XCTAssertEqual(workspace.activePaneID, newPaneID)
        XCTAssertEqual(workspace.panes[originalPaneID]?.isActive, false)
        XCTAssertEqual(workspace.panes[newPaneID]?.isActive, true)
        XCTAssertEqual(workspace.panes[newPaneID]?.cwd, "/tmp")
    }

    func testWorkspaceUsesProfileForInitialPane() {
        var profile = TerminalProfile.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )
        profile.shellPath = "/bin/bash"
        profile.startupDirectory = "/tmp/project"

        let workspace = SplitWorkspaceController(profile: profile)

        XCTAssertEqual(workspace.activePane.shellPath, "/bin/bash")
        XCTAssertEqual(workspace.activePane.cwd, "/tmp/project")
    }

    func testSplitDownKeepsTreeOrderAndUsesTopBottomAxis() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let originalPaneID = workspace.activePaneID
        let newPaneID = workspace.splitActive(axis: .topBottom)

        XCTAssertEqual(
            workspace.root,
            .split(axis: .topBottom, ratio: 0.5, first: .pane(originalPaneID), second: .pane(newPaneID))
        )
    }

    func testCloseActivePaneCollapsesParentAndFocusesNeighbor() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let originalPaneID = workspace.activePaneID
        let newPaneID = workspace.splitActive(axis: .leftRight)

        let removedPaneID = workspace.closeActivePane()

        XCTAssertEqual(removedPaneID, newPaneID)
        XCTAssertEqual(workspace.root, .pane(originalPaneID))
        XCTAssertEqual(workspace.activePaneID, originalPaneID)
        XCTAssertNil(workspace.panes[newPaneID])
    }

    func testClosingFinalPaneIsRejected() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")

        let removedPaneID = workspace.closeActivePane()

        XCTAssertNil(removedPaneID)
        XCTAssertEqual(workspace.orderedPaneIDs.count, 1)
    }

    func testFocusCyclesForwardAndBackward() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let first = workspace.activePaneID
        let second = workspace.splitActive(axis: .leftRight)
        let third = workspace.splitActive(axis: .topBottom)

        workspace.focusNextPane()
        XCTAssertEqual(workspace.activePaneID, first)

        workspace.focusPreviousPane()
        XCTAssertEqual(workspace.activePaneID, third)

        workspace.setActivePane(second)
        workspace.focusNextPane()
        XCTAssertEqual(workspace.activePaneID, third)
    }

    func testPersistedLayoutIsRemappedToFreshPaneIDs() throws {
        let persisted = SplitNode.split(
            axis: .leftRight,
            ratio: 1.2,
            first: .pane(UUID()),
            second: .pane(UUID())
        )

        let workspace = SplitWorkspaceController.workspace(fromPersistedRoot: persisted)

        XCTAssertEqual(workspace.orderedPaneIDs.count, 2)
        XCTAssertEqual(workspace.panes.count, 2)

        if case let .split(_, ratio, _, _) = workspace.root {
            XCTAssertEqual(ratio, 0.85)
        } else {
            XCTFail("Expected split root")
        }
    }
}
