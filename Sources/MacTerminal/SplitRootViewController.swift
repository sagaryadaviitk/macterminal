import AppKit
import MacTerminalCore

final class SplitRootViewController: NSViewController, SplitWorkspaceControllerDelegate {
    let workspace: SplitWorkspaceController

    private var profile: TerminalProfile
    private var paneControllers: [UUID: TerminalPaneViewController] = [:]
    private var contentController: NSViewController?
    private let saveLayout: (SplitNode) -> Void
    private let titleChanged: () -> Void

    init(
        workspace: SplitWorkspaceController,
        profile: TerminalProfile,
        saveLayout: @escaping (SplitNode) -> Void,
        titleChanged: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.profile = profile.normalized()
        self.saveLayout = saveLayout
        self.titleChanged = titleChanged
        super.init(nibName: nil, bundle: nil)
        self.workspace.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.black.cgColor
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rebuildLayout()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        paneControllers[workspace.activePaneID]?.focusTerminal()
    }

    func splitRight() {
        _ = workspace.splitActive(axis: .leftRight)
    }

    func splitDown() {
        _ = workspace.splitActive(axis: .topBottom)
    }

    func closeActivePane() {
        guard shouldClose(pane: workspace.activePane) else {
            return
        }
        _ = workspace.closeActivePane()
    }

    func focusNextPane() {
        workspace.focusNextPane()
        paneControllers[workspace.activePaneID]?.focusTerminal()
    }

    func focusPreviousPane() {
        workspace.focusPreviousPane()
        paneControllers[workspace.activePaneID]?.focusTerminal()
    }

    func terminateAllSessions() {
        for controller in paneControllers.values {
            controller.terminate()
        }
    }

    var tabTitle: String {
        let title = workspace.activePane.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Terminal" : title
    }

    var hasRunningProcesses: Bool {
        workspace.panes.values.contains { $0.processState == .running || $0.processState == .starting }
    }

    func apply(profile: TerminalProfile) {
        self.profile = profile.normalized()
        for controller in paneControllers.values {
            controller.apply(profile: self.profile)
        }
    }

    func copySelection() {
        paneControllers[workspace.activePaneID]?.copySelection()
    }

    func pasteClipboard() {
        paneControllers[workspace.activePaneID]?.pasteClipboard()
    }

    func zoomFont(by delta: CGFloat) {
        for controller in paneControllers.values {
            controller.zoomFont(by: delta)
        }
    }

    func shouldCloseAll() -> Bool {
        guard hasRunningProcesses else {
            return true
        }

        guard AppPreferencesStore.shared.preferences.confirmBeforeClosingRunningPanes else {
            return true
        }

        return confirmCloseRunningProcesses(
            message: "Close running terminal sessions?",
            informativeText: "Processes in this tab will be terminated.",
            closeButtonTitle: "Close"
        )
    }

    func workspaceDidChangeLayout(_ workspace: SplitWorkspaceController) {
        saveLayout(workspace.root)
        rebuildLayout()
        paneControllers[workspace.activePaneID]?.focusTerminal()
        titleChanged()
    }

    func workspace(_ workspace: SplitWorkspaceController, didUpdate pane: TerminalPane) {
        paneControllers[pane.id]?.update(with: pane)
        titleChanged()
    }

    func workspace(_ workspace: SplitWorkspaceController, didRemovePane paneID: UUID) {
        paneControllers[paneID]?.terminate()
        paneControllers[paneID] = nil
    }

    private func rebuildLayout() {
        if let contentController {
            contentController.view.removeFromSuperview()
            detachControllerTree(contentController)
        }

        let controller = makeController(for: workspace.root)
        contentController = controller
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        for pane in workspace.panes.values {
            paneControllers[pane.id]?.update(with: pane)
        }
    }

    private func makeController(for node: SplitNode) -> NSViewController {
        switch node {
        case let .pane(paneID):
            if let controller = paneControllers[paneID] {
                return controller
            }
            guard let pane = workspace.panes[paneID] else {
                preconditionFailure("Missing pane model for \(paneID)")
            }
            let controller = TerminalPaneViewController(
                pane: pane,
                workspace: workspace,
                profile: profile,
                onRequestClose: { [weak self] in
                    self?.closeActivePane()
                }
            )
            paneControllers[paneID] = controller
            return controller

        case let .split(axis, ratio, first, second):
            let controller = SplitContainerViewController(axis: axis, ratio: ratio)
            controller.addSplitViewItem(NSSplitViewItem(viewController: makeController(for: first)))
            controller.addSplitViewItem(NSSplitViewItem(viewController: makeController(for: second)))
            return controller
        }
    }

    private func detachControllerTree(_ controller: NSViewController) {
        for child in controller.children {
            detachControllerTree(child)
        }
        controller.removeFromParent()
    }

    private func shouldClose(pane: TerminalPane) -> Bool {
        guard pane.processState == .running || pane.processState == .starting else {
            return true
        }

        guard AppPreferencesStore.shared.preferences.confirmBeforeClosingRunningPanes else {
            return true
        }

        return confirmCloseRunningProcesses(
            message: "Close running pane?",
            informativeText: "The shell or foreground process in this pane will be terminated.",
            closeButtonTitle: "Close Pane"
        )
    }

    private func confirmCloseRunningProcesses(
        message: String,
        informativeText: String,
        closeButtonTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.addButton(withTitle: closeButtonTitle)
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"

        let shouldClose = alert.runModal() == .alertFirstButtonReturn
        if shouldClose, alert.suppressionButton?.state == .on {
            var preferences = AppPreferencesStore.shared.preferences
            preferences.confirmBeforeClosingRunningPanes = false
            AppPreferencesStore.shared.preferences = preferences
        }

        return shouldClose
    }
}
