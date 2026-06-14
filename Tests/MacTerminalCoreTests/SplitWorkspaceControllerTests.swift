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

    func testRepeatedRightSplitsBalancePaneWidths() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let firstPaneID = workspace.activePaneID
        let secondPaneID = workspace.splitActive(axis: .leftRight)
        let thirdPaneID = workspace.splitActive(axis: .leftRight)
        let fourthPaneID = workspace.splitActive(axis: .leftRight)

        XCTAssertEqual(workspace.orderedPaneIDs, [firstPaneID, secondPaneID, thirdPaneID, fourthPaneID])

        guard case let .split(rootAxis, rootRatio, rootFirst, rootSecond) = workspace.root else {
            return XCTFail("Expected root split")
        }
        XCTAssertEqual(rootAxis, .leftRight)
        XCTAssertEqual(rootFirst, .pane(firstPaneID))
        XCTAssertEqual(rootRatio, 0.25, accuracy: 0.0001)

        guard case let .split(secondAxis, secondRatio, secondFirst, secondSecond) = rootSecond else {
            return XCTFail("Expected second split")
        }
        XCTAssertEqual(secondAxis, .leftRight)
        XCTAssertEqual(secondFirst, .pane(secondPaneID))
        XCTAssertEqual(secondRatio, 1.0 / 3.0, accuracy: 0.0001)

        guard case let .split(thirdAxis, thirdRatio, thirdFirst, thirdSecond) = secondSecond else {
            return XCTFail("Expected third split")
        }
        XCTAssertEqual(thirdAxis, .leftRight)
        XCTAssertEqual(thirdFirst, .pane(thirdPaneID))
        XCTAssertEqual(thirdSecond, .pane(fourthPaneID))
        XCTAssertEqual(thirdRatio, 0.5, accuracy: 0.0001)
    }

    func testOrthogonalSplitsBalanceWithinTheirOwnAxis() {
        let workspace = SplitWorkspaceController(shellPath: "/bin/zsh", homeDirectory: "/tmp")
        let firstPaneID = workspace.activePaneID
        let secondPaneID = workspace.splitActive(axis: .leftRight)
        let thirdPaneID = workspace.splitActive(axis: .topBottom)

        XCTAssertEqual(workspace.orderedPaneIDs, [firstPaneID, secondPaneID, thirdPaneID])

        guard case let .split(rootAxis, rootRatio, rootFirst, rootSecond) = workspace.root else {
            return XCTFail("Expected root split")
        }
        XCTAssertEqual(rootAxis, .leftRight)
        XCTAssertEqual(rootFirst, .pane(firstPaneID))
        XCTAssertEqual(rootRatio, 0.5, accuracy: 0.0001)

        guard case let .split(childAxis, childRatio, childFirst, childSecond) = rootSecond else {
            return XCTFail("Expected vertical child split")
        }
        XCTAssertEqual(childAxis, .topBottom)
        XCTAssertEqual(childFirst, .pane(secondPaneID))
        XCTAssertEqual(childSecond, .pane(thirdPaneID))
        XCTAssertEqual(childRatio, 0.5, accuracy: 0.0001)
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
            XCTAssertEqual(ratio, 0.5)
        } else {
            XCTFail("Expected split root")
        }
    }
}
