import Foundation

public protocol SplitWorkspaceControllerDelegate: AnyObject {
    func workspaceDidChangeLayout(_ workspace: SplitWorkspaceController)
    func workspace(_ workspace: SplitWorkspaceController, didUpdate pane: TerminalPane)
    func workspace(_ workspace: SplitWorkspaceController, didRemovePane paneID: UUID)
}

public final class SplitWorkspaceController {
    public private(set) var root: SplitNode
    public private(set) var panes: [UUID: TerminalPane]
    public private(set) var activePaneID: UUID

    public weak var delegate: SplitWorkspaceControllerDelegate?

    public init(
        root: SplitNode? = nil,
        panes: [UUID: TerminalPane]? = nil,
        activePaneID: UUID? = nil,
        shellPath: String = ShellConfiguration.defaultShellPath(),
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        profile: TerminalProfile? = nil
    ) {
        let resolvedProfile = profile?.normalized(homeDirectory: homeDirectory)
        if let root, let panes, let activePaneID, panes[activePaneID] != nil {
            self.root = root.clampingRatios()
            self.panes = panes
            self.activePaneID = activePaneID
        } else {
            let initialShellPath = resolvedProfile?.shellPath ?? shellPath
            let initialDirectory = resolvedProfile?.startupDirectory ?? homeDirectory
            let pane = TerminalPane(
                title: URL(fileURLWithPath: initialShellPath).lastPathComponent,
                cwd: initialDirectory,
                shellPath: initialShellPath,
                processState: .starting,
                isActive: true
            )
            self.root = .pane(pane.id)
            self.panes = [pane.id: pane]
            self.activePaneID = pane.id
        }

        markOnlyActivePane()
    }

    public var orderedPaneIDs: [UUID] {
        root.paneIDs.filter { panes[$0] != nil }
    }

    public var activePane: TerminalPane {
        panes[activePaneID]!
    }

    @discardableResult
    public func splitActive(axis: SplitAxis) -> UUID {
        let sourcePane = activePane
        var newPane = TerminalPane(
            title: URL(fileURLWithPath: sourcePane.shellPath).lastPathComponent,
            cwd: sourcePane.cwd,
            shellPath: sourcePane.shellPath,
            processState: .starting,
            isActive: false
        )
        newPane.isActive = true

        panes[newPane.id] = newPane
        root = root.replacingPane(
            sourcePane.id,
            with: .split(axis: axis, ratio: 0.5, first: .pane(sourcePane.id), second: .pane(newPane.id))
        )
        setActivePane(newPane.id, notifyLayout: false)
        delegate?.workspaceDidChangeLayout(self)
        return newPane.id
    }

    @discardableResult
    public func closeActivePane() -> UUID? {
        guard panes.count > 1 else {
            return nil
        }

        let paneToRemove = activePaneID
        let candidates = orderedPaneIDs.filter { $0 != paneToRemove }
        let currentIndex = orderedPaneIDs.firstIndex(of: paneToRemove) ?? 0
        let replacementIndex = min(currentIndex, max(candidates.count - 1, 0))
        let nextActive = candidates[replacementIndex]

        guard let collapsedRoot = root.removingPane(paneToRemove) else {
            return nil
        }

        panes[paneToRemove] = nil
        root = collapsedRoot
        activePaneID = nextActive
        markOnlyActivePane()
        delegate?.workspace(self, didRemovePane: paneToRemove)
        delegate?.workspaceDidChangeLayout(self)
        return paneToRemove
    }

    public func focusNextPane() {
        focus(offset: 1)
    }

    public func focusPreviousPane() {
        focus(offset: -1)
    }

    public func setActivePane(_ paneID: UUID) {
        setActivePane(paneID, notifyLayout: false)
    }

    public func updatePaneTitle(_ paneID: UUID, title: String) {
        guard var pane = panes[paneID] else {
            return
        }
        pane.title = title.isEmpty ? URL(fileURLWithPath: pane.shellPath).lastPathComponent : title
        panes[paneID] = pane
        delegate?.workspace(self, didUpdate: pane)
    }

    public func updatePaneDirectory(_ paneID: UUID, cwd: String) {
        guard var pane = panes[paneID] else {
            return
        }
        pane.cwd = cwd
        panes[paneID] = pane
        delegate?.workspace(self, didUpdate: pane)
    }

    public func updatePaneProcessState(_ paneID: UUID, processState: ProcessState) {
        guard var pane = panes[paneID] else {
            return
        }
        pane.processState = processState
        panes[paneID] = pane
        delegate?.workspace(self, didUpdate: pane)
    }

    public static func workspace(
        fromPersistedRoot persistedRoot: SplitNode?,
        profile: TerminalProfile = .default()
    ) -> SplitWorkspaceController {
        guard let persistedRoot else {
            return SplitWorkspaceController(profile: profile)
        }

        let normalizedProfile = profile.normalized()
        let shellPath = normalizedProfile.shellPath
        let homeDirectory = normalizedProfile.startupDirectory
        var panes: [UUID: TerminalPane] = [:]
        let remappedRoot = remapPaneIDs(in: persistedRoot) {
            let pane = TerminalPane(
                title: URL(fileURLWithPath: shellPath).lastPathComponent,
                cwd: homeDirectory,
                shellPath: shellPath,
                processState: .starting,
                isActive: false
            )
            panes[pane.id] = pane
            return pane.id
        }
        let clampedRoot = remappedRoot.clampingRatios()
        let activeID = clampedRoot.paneIDs.first ?? UUID()
        if var active = panes[activeID] {
            active.isActive = true
            panes[activeID] = active
        }
        return SplitWorkspaceController(root: clampedRoot, panes: panes, activePaneID: activeID)
    }

    private static func remapPaneIDs(in node: SplitNode, makePaneID: () -> UUID) -> SplitNode {
        switch node {
        case .pane:
            return .pane(makePaneID())
        case let .split(axis, ratio, first, second):
            return .split(
                axis: axis,
                ratio: ratio,
                first: remapPaneIDs(in: first, makePaneID: makePaneID),
                second: remapPaneIDs(in: second, makePaneID: makePaneID)
            )
        }
    }

    private func focus(offset: Int) {
        let ids = orderedPaneIDs
        guard ids.count > 1, let currentIndex = ids.firstIndex(of: activePaneID) else {
            return
        }
        let nextIndex = (currentIndex + offset + ids.count) % ids.count
        setActivePane(ids[nextIndex])
    }

    private func setActivePane(_ paneID: UUID, notifyLayout: Bool) {
        guard panes[paneID] != nil, activePaneID != paneID else {
            return
        }
        let previousActiveID = activePaneID
        activePaneID = paneID
        markOnlyActivePane()

        if let previous = panes[previousActiveID] {
            delegate?.workspace(self, didUpdate: previous)
        }
        if let current = panes[paneID] {
            delegate?.workspace(self, didUpdate: current)
        }
        if notifyLayout {
            delegate?.workspaceDidChangeLayout(self)
        }
    }

    private func markOnlyActivePane() {
        for id in panes.keys {
            panes[id]?.isActive = id == activePaneID
        }
    }
}

private extension SplitNode {
    func removingPane(_ target: UUID) -> SplitNode? {
        switch self {
        case let .pane(id):
            return id == target ? nil : self
        case let .split(_, _, first, second):
            let firstResult = first.removingPane(target)
            let secondResult = second.removingPane(target)

            switch (firstResult, secondResult) {
            case let (.some(firstNode), .some(secondNode)):
                if case let .split(axis, ratio, _, _) = self {
                    return .split(axis: axis, ratio: ratio, first: firstNode, second: secondNode)
                }
                return nil
            case let (.some(node), .none), let (.none, .some(node)):
                return node
            case (.none, .none):
                return nil
            }
        }
    }
}
