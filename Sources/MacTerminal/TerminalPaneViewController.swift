import AppKit
import MacTerminalCore

final class TerminalPaneViewController: NSViewController {
    private enum Metrics {
        static let titleBarHeight: CGFloat = 20
        static let terminalHorizontalInset: CGFloat = 8
        static let terminalTopInset: CGFloat = 4
        static let terminalBottomInset: CGFloat = 8
    }

    let paneID: UUID

    private unowned let workspace: SplitWorkspaceController
    private var pane: TerminalPane
    private var profile: TerminalProfile
    private let onRequestClose: () -> Void
    private var sessionController: TerminalSessionController?
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let titleBar = PaneTitleBarView()
    private let closeButton = NSButton()
    private let terminalContainerView = NSView()
    private var titleBarHeightConstraint: NSLayoutConstraint?

    init(
        pane: TerminalPane,
        workspace: SplitWorkspaceController,
        profile: TerminalProfile,
        onRequestClose: @escaping () -> Void
    ) {
        self.paneID = pane.id
        self.pane = pane
        self.workspace = workspace
        self.profile = profile.normalized()
        self.onRequestClose = onRequestClose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rootView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view = rootView
        applyBackgroundColor()

        let sessionController = TerminalSessionController(
            pane: pane,
            profile: profile,
            onTitleChange: { [weak self] paneID, title in
                self?.workspace.updatePaneTitle(paneID, title: title)
            },
            onDirectoryChange: { [weak self] paneID, directory in
                self?.workspace.updatePaneDirectory(paneID, cwd: directory)
            },
            onProcessStateChange: { [weak self] paneID, state in
                self?.workspace.updatePaneProcessState(paneID, processState: state)
            }
        )
        self.sessionController = sessionController

        configureTitleBar()
        configureTerminalContainer()
        let terminalView = sessionController.terminalView

        rootView.addSubview(titleBar)
        rootView.addSubview(terminalContainerView)
        terminalContainerView.addSubview(terminalView)
        let titleBarHeightConstraint = titleBar.heightAnchor.constraint(equalToConstant: Metrics.titleBarHeight)
        self.titleBarHeightConstraint = titleBarHeightConstraint
        NSLayoutConstraint.activate([
            titleBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            titleBar.topAnchor.constraint(equalTo: rootView.topAnchor),
            titleBarHeightConstraint,

            terminalContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            terminalContainerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            terminalContainerView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            terminalContainerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            terminalView.leadingAnchor.constraint(equalTo: terminalContainerView.leadingAnchor, constant: Metrics.terminalHorizontalInset),
            terminalView.trailingAnchor.constraint(equalTo: terminalContainerView.trailingAnchor, constant: -Metrics.terminalHorizontalInset),
            terminalView.topAnchor.constraint(equalTo: terminalContainerView.topAnchor, constant: Metrics.terminalTopInset),
            terminalView.bottomAnchor.constraint(equalTo: terminalContainerView.bottomAnchor, constant: -Metrics.terminalBottomInset)
        ])

        update(with: pane)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        guard let sessionController else {
            return
        }

        let terminalView = sessionController.terminalView
        guard terminalView.bounds.width > 80, terminalView.bounds.height > 80 else {
            return
        }

        terminalView.setFrameSize(terminalView.bounds.size)
        sessionController.startIfNeeded()

        if pane.isActive {
            DispatchQueue.main.async { [weak self] in
                self?.focusTerminal()
            }
        }
    }

    func update(with pane: TerminalPane) {
        self.pane = pane
        titleLabel.stringValue = pane.title
        statusLabel.stringValue = statusText(for: pane)
        updateTitleBarVisibility()
        updateActiveAppearance()
    }

    func apply(profile: TerminalProfile) {
        self.profile = profile.normalized()
        sessionController?.apply(profile: self.profile)
        applyBackgroundColor()
        updateActiveAppearance()
    }

    func copySelection() {
        sessionController?.copySelection()
    }

    func pasteClipboard() {
        sessionController?.pasteClipboard()
    }

    func zoomFont(by delta: CGFloat) {
        sessionController?.zoomFont(by: delta)
    }

    func focusTerminal() {
        guard isViewLoaded else {
            return
        }
        view.window?.makeFirstResponder(sessionController?.terminalView)
    }

    func terminate() {
        sessionController?.terminate()
    }

    private func configureTitleBar() {
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        titleBar.wantsLayer = true
        titleBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleBar.onMouseDown = { [weak self] in
            self?.focusPane()
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Pane")
        closeButton.imagePosition = .imageOnly
        closeButton.refusesFirstResponder = true
        closeButton.target = self
        closeButton.action = #selector(closePane)
        closeButton.toolTip = "Close Pane"

        titleBar.addSubview(titleLabel)
        titleBar.addSubview(statusLabel)
        titleBar.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -6),

            closeButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -2),
            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: Metrics.titleBarHeight)
        ])
    }

    private func configureTerminalContainer() {
        terminalContainerView.translatesAutoresizingMaskIntoConstraints = false
        terminalContainerView.wantsLayer = true
        terminalContainerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        terminalContainerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        applyBackgroundColor()
    }

    private func applyBackgroundColor() {
        let background = NSColor(hex: profile.theme.backgroundHex) ?? NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        view.layer?.backgroundColor = background.cgColor
        terminalContainerView.layer?.backgroundColor = background.cgColor
    }

    private func updateActiveAppearance() {
        let background: NSColor = pane.isActive
            ? NSColor(hex: profile.theme.activeTitlebarHex) ?? NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.26, alpha: 1)
            : NSColor(hex: profile.theme.inactiveTitlebarHex) ?? NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
        titleBar.layer?.backgroundColor = background.cgColor
        titleLabel.textColor = pane.isActive ? .white : .secondaryLabelColor
    }

    private func updateTitleBarVisibility() {
        let shouldShowTitleBar = workspace.panes.count > 1
        titleBar.isHidden = !shouldShowTitleBar
        titleBarHeightConstraint?.constant = shouldShowTitleBar ? Metrics.titleBarHeight : 0
        view.needsLayout = true
    }

    private func statusText(for pane: TerminalPane) -> String {
        switch pane.processState {
        case .starting:
            return "starting"
        case .running:
            return compactPath(pane.cwd)
        case .exited:
            return "exited"
        }
    }

    private func compactPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    @objc private func closePane() {
        workspace.setActivePane(paneID)
        onRequestClose()
    }

    @objc private func focusPane() {
        workspace.setActivePane(paneID)
        focusTerminal()
    }
}

private final class PaneTitleBarView: NSView {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }
}
