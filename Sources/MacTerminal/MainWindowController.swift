import AppKit
import MacTerminalCore

final class MainWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private enum LayoutDefaults {
        static let splitLayout = "MacTerminal.SplitLayout"
        static let tabLayouts = "MacTerminal.TabLayouts"
    }

    private enum Metrics {
        static let contentCornerRadius: CGFloat = 16
        static let contentBorderWidth: CGFloat = 1
    }

    private enum Chrome {
        static let fallbackWindowBackground = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
        static let fallbackContentBackground = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        static let contentBorder = NSColor(calibratedWhite: 1, alpha: 0.14)
    }

    private let tabViewController: NSTabViewController = {
        let controller = NSTabViewController()
        controller.tabStyle = .unspecified
        return controller
    }()
    private var rootViewControllers: [SplitRootViewController] = []
    private var profile = AppPreferencesStore.shared.activeProfile

    init() {
        let window = NSWindow(contentViewController: tabViewController)
        window.title = "MacTerminal"
        window.minSize = NSSize(width: 720, height: 420)
        window.setContentSize(NSSize(width: 1080, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .expanded
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = Self.windowBackgroundColor(for: profile)
        window.setFrameAutosaveName("MacTerminalMainWindow")
        window.center()

        super.init(window: window)
        window.delegate = self
        configureContentClipping()
        configureToolbar()
        restoreTabs()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange(_:)),
            name: .macTerminalPreferencesDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func splitRight(_ sender: Any?) {
        activeRootViewController?.splitRight()
    }

    @objc func splitDown(_ sender: Any?) {
        activeRootViewController?.splitDown()
    }

    @objc func closeActivePane(_ sender: Any?) {
        activeRootViewController?.closeActivePane()
    }

    @objc func focusNextPane(_ sender: Any?) {
        activeRootViewController?.focusNextPane()
    }

    @objc func focusPreviousPane(_ sender: Any?) {
        activeRootViewController?.focusPreviousPane()
    }

    @objc func newTab(_ sender: Any?) {
        addTab(fromPersistedRoot: nil, select: true)
        saveAllTabLayouts()
    }

    @objc func closeTab(_ sender: Any?) {
        guard let root = activeRootViewController,
              let item = selectedTabViewItem else {
            return
        }

        guard root.shouldCloseAll() else {
            return
        }

        root.terminateAllSessions()
        if let index = rootViewControllers.firstIndex(where: { $0 === root }) {
            rootViewControllers.remove(at: index)
        }
        tabViewController.removeTabViewItem(item)

        if rootViewControllers.isEmpty {
            addTab(fromPersistedRoot: nil, select: true)
        }
        saveAllTabLayouts()
    }

    @objc func selectNextTab(_ sender: Any?) {
        selectTab(offset: 1)
    }

    @objc func selectPreviousTab(_ sender: Any?) {
        selectTab(offset: -1)
    }

    @objc func copySelection(_ sender: Any?) {
        activeRootViewController?.copySelection()
    }

    @objc func pasteClipboard(_ sender: Any?) {
        activeRootViewController?.pasteClipboard()
    }

    @objc func zoomFontIn(_ sender: Any?) {
        activeRootViewController?.zoomFont(by: 1)
    }

    @objc func zoomFontOut(_ sender: Any?) {
        activeRootViewController?.zoomFont(by: -1)
    }

    func windowWillClose(_ notification: Notification) {
        for controller in rootViewControllers {
            controller.terminateAllSessions()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        for controller in rootViewControllers where !controller.shouldCloseAll() {
            return false
        }
        return true
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.newWindow, .newTab, .splitRight, .splitDown, .closePane, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.newWindow, .newTab, .flexibleSpace, .splitRight, .splitDown, .closePane]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier {
        case .newWindow:
            item.label = "New Window"
            item.paletteLabel = "New Window"
            item.toolTip = "New Window"
            item.image = NSImage(systemSymbolName: "plus.rectangle.on.rectangle", accessibilityDescription: "New Window")
            item.target = NSApp.delegate
            item.action = #selector(AppDelegate.newWindow(_:))
        case .newTab:
            item.label = "New Tab"
            item.paletteLabel = "New Tab"
            item.toolTip = "New Tab"
            item.image = NSImage(systemSymbolName: "plus.rectangle", accessibilityDescription: "New Tab")
            item.target = self
            item.action = #selector(newTab(_:))
        case .splitRight:
            item.label = "Split Right"
            item.paletteLabel = "Split Right"
            item.toolTip = "Split Right"
            item.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Split Right")
            item.target = self
            item.action = #selector(splitRight(_:))
        case .splitDown:
            item.label = "Split Down"
            item.paletteLabel = "Split Down"
            item.toolTip = "Split Down"
            item.image = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: "Split Down")
            item.target = self
            item.action = #selector(splitDown(_:))
        case .closePane:
            item.label = "Close Pane"
            item.paletteLabel = "Close Pane"
            item.toolTip = "Close Pane"
            item.image = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: "Close Pane")
            item.target = self
            item.action = #selector(closeActivePane(_:))
        default:
            return nil
        }

        return item
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "MacTerminalToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.showsBaselineSeparator = true
        window?.toolbar = toolbar
    }

    private func configureContentClipping() {
        guard let contentView = window?.contentView else {
            return
        }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Self.contentBackgroundColor(for: profile).cgColor
        contentView.layer?.cornerRadius = Metrics.contentCornerRadius
        contentView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer?.borderColor = Chrome.contentBorder.cgColor
        contentView.layer?.borderWidth = Metrics.contentBorderWidth
        contentView.layer?.masksToBounds = true
    }

    private func applyWindowChrome() {
        window?.backgroundColor = Self.windowBackgroundColor(for: profile)
        window?.contentView?.layer?.backgroundColor = Self.contentBackgroundColor(for: profile).cgColor
    }

    private var activeRootViewController: SplitRootViewController? {
        selectedTabViewItem?.viewController as? SplitRootViewController
    }

    private var selectedTabViewItem: NSTabViewItem? {
        let index = tabViewController.selectedTabViewItemIndex
        guard index >= 0, index < tabViewController.tabViewItems.count else {
            return nil
        }
        return tabViewController.tabViewItems[index]
    }

    private func restoreTabs() {
        let roots = Array(Self.loadPersistedTabLayouts().prefix(8))
        if roots.isEmpty {
            addTab(fromPersistedRoot: Self.loadPersistedLayout(), select: true)
        } else {
            for (index, root) in roots.enumerated() {
                addTab(fromPersistedRoot: root, select: index == 0)
            }
        }
        updateTabTitles()
    }

    private func addTab(fromPersistedRoot root: SplitNode?, select: Bool) {
        let workspace = SplitWorkspaceController.workspace(fromPersistedRoot: root, profile: profile)
        let rootController = SplitRootViewController(
            workspace: workspace,
            profile: profile,
            saveLayout: { [weak self] _ in
                self?.saveAllTabLayouts()
            },
            titleChanged: { [weak self] in
                self?.updateTabTitles()
            }
        )
        rootViewControllers.append(rootController)

        let item = NSTabViewItem(viewController: rootController)
        item.label = rootController.tabTitle
        tabViewController.addTabViewItem(item)
        if select {
            tabViewController.selectedTabViewItemIndex = tabViewController.tabViewItems.count - 1
        }
    }

    private func selectTab(offset: Int) {
        let count = tabViewController.tabViewItems.count
        guard count > 1 else {
            return
        }
        let current = tabViewController.selectedTabViewItemIndex
        tabViewController.selectedTabViewItemIndex = (current + offset + count) % count
    }

    private func updateTabTitles() {
        for item in tabViewController.tabViewItems {
            if let root = item.viewController as? SplitRootViewController {
                item.label = root.tabTitle
            }
        }
        window?.title = activeRootViewController?.tabTitle ?? "MacTerminal"
    }

    private func saveAllTabLayouts() {
        let roots = rootViewControllers.map(\.workspace.root)
        Self.savePersistedTabLayouts(roots)
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        profile = AppPreferencesStore.shared.activeProfile
        applyWindowChrome()
        for controller in rootViewControllers {
            controller.apply(profile: profile)
        }
    }

    private static func windowBackgroundColor(for profile: TerminalProfile) -> NSColor {
        NSColor(hex: profile.theme.inactiveTitlebarHex) ?? Chrome.fallbackWindowBackground
    }

    private static func contentBackgroundColor(for profile: TerminalProfile) -> NSColor {
        NSColor(hex: profile.theme.backgroundHex) ?? Chrome.fallbackContentBackground
    }

    private static func loadPersistedLayout() -> SplitNode? {
        guard let data = UserDefaults.standard.data(forKey: LayoutDefaults.splitLayout) else {
            return nil
        }
        return try? JSONDecoder().decode(SplitNode.self, from: data)
    }

    private static func loadPersistedTabLayouts() -> [SplitNode] {
        guard let data = UserDefaults.standard.data(forKey: LayoutDefaults.tabLayouts) else {
            return []
        }
        return (try? JSONDecoder().decode([SplitNode].self, from: data)) ?? []
    }

    private static func savePersistedTabLayouts(_ roots: [SplitNode]) {
        guard let data = try? JSONEncoder().encode(Array(roots.prefix(8))) else {
            return
        }
        UserDefaults.standard.set(data, forKey: LayoutDefaults.tabLayouts)
    }
}

private extension NSToolbarItem.Identifier {
    static let newWindow = NSToolbarItem.Identifier("MacTerminal.NewWindow")
    static let newTab = NSToolbarItem.Identifier("MacTerminal.NewTab")
    static let splitRight = NSToolbarItem.Identifier("MacTerminal.SplitRight")
    static let splitDown = NSToolbarItem.Identifier("MacTerminal.SplitDown")
    static let closePane = NSToolbarItem.Identifier("MacTerminal.ClosePane")
}
