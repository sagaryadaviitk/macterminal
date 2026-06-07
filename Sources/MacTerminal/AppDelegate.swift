import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [MainWindowController] = []
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = makeMainMenu()
        newWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func newWindow(_ sender: Any?) {
        let controller = MainWindowController()
        windows.append(controller)
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func splitRight(_ sender: Any?) {
        activeWindowController?.splitRight(sender)
    }

    @objc func splitDown(_ sender: Any?) {
        activeWindowController?.splitDown(sender)
    }

    @objc func closeActivePane(_ sender: Any?) {
        activeWindowController?.closeActivePane(sender)
    }

    @objc func focusNextPane(_ sender: Any?) {
        activeWindowController?.focusNextPane(sender)
    }

    @objc func focusPreviousPane(_ sender: Any?) {
        activeWindowController?.focusPreviousPane(sender)
    }

    @objc func newTab(_ sender: Any?) {
        activeWindowController?.newTab(sender)
    }

    @objc func closeTab(_ sender: Any?) {
        activeWindowController?.closeTab(sender)
    }

    @objc func selectNextTab(_ sender: Any?) {
        activeWindowController?.selectNextTab(sender)
    }

    @objc func selectPreviousTab(_ sender: Any?) {
        activeWindowController?.selectPreviousTab(sender)
    }

    @objc func copySelection(_ sender: Any?) {
        activeWindowController?.copySelection(sender)
    }

    @objc func pasteClipboard(_ sender: Any?) {
        activeWindowController?.pasteClipboard(sender)
    }

    @objc func zoomFontIn(_ sender: Any?) {
        activeWindowController?.zoomFontIn(sender)
    }

    @objc func zoomFontOut(_ sender: Any?) {
        activeWindowController?.zoomFontOut(sender)
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(sender)
    }

    private var activeWindowController: MainWindowController? {
        NSApp.keyWindow?.windowController as? MainWindowController
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = makeAppMenu()
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = makeFileMenu()
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = makeEditMenu()
        mainMenu.addItem(editMenuItem)

        let terminalMenuItem = NSMenuItem()
        terminalMenuItem.submenu = makeTerminalMenu()
        mainMenu.addItem(terminalMenuItem)

        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = makeWindowMenu()
        mainMenu.addItem(windowMenuItem)

        return mainMenu
    }

    private func makeAppMenu() -> NSMenu {
        let menu = NSMenu(title: "MacTerminal")
        menu.addItem(withTitle: "About MacTerminal", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacTerminal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func makeFileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n")
        newWindowItem.target = self
        menu.addItem(newWindowItem)

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

        let closeTabItem = NSMenuItem(title: "Close Tab", action: #selector(closeTab(_:)), keyEquivalent: "W")
        closeTabItem.keyEquivalentModifierMask = [.command, .shift]
        closeTabItem.target = self
        menu.addItem(closeTabItem)

        let closePaneItem = NSMenuItem(title: "Close Pane", action: #selector(closeActivePane(_:)), keyEquivalent: "w")
        closePaneItem.target = self
        menu.addItem(closePaneItem)
        return menu
    }

    private func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelection(_:)), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(pasteClipboard(_:)), keyEquivalent: "v")
        pasteItem.target = self
        menu.addItem(pasteItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private func makeTerminalMenu() -> NSMenu {
        let menu = NSMenu(title: "Terminal")

        let splitRightItem = NSMenuItem(title: "Split Right", action: #selector(splitRight(_:)), keyEquivalent: "d")
        splitRightItem.target = self
        menu.addItem(splitRightItem)

        let splitDownItem = NSMenuItem(title: "Split Down", action: #selector(splitDown(_:)), keyEquivalent: "D")
        splitDownItem.keyEquivalentModifierMask = [.command, .shift]
        splitDownItem.target = self
        menu.addItem(splitDownItem)

        menu.addItem(.separator())

        let previousItem = NSMenuItem(title: "Focus Previous Pane", action: #selector(focusPreviousPane(_:)), keyEquivalent: "[")
        previousItem.target = self
        menu.addItem(previousItem)

        let nextItem = NSMenuItem(title: "Focus Next Pane", action: #selector(focusNextPane(_:)), keyEquivalent: "]")
        nextItem.target = self
        menu.addItem(nextItem)

        menu.addItem(.separator())

        let zoomInItem = NSMenuItem(title: "Increase Font Size", action: #selector(zoomFontIn(_:)), keyEquivalent: "+")
        zoomInItem.target = self
        menu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Decrease Font Size", action: #selector(zoomFontOut(_:)), keyEquivalent: "-")
        zoomOutItem.target = self
        menu.addItem(zoomOutItem)

        return menu
    }

    private func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let previousTabItem = NSMenuItem(title: "Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "{")
        previousTabItem.keyEquivalentModifierMask = [.command, .shift]
        previousTabItem.target = self
        menu.addItem(previousTabItem)
        let nextTabItem = NSMenuItem(title: "Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "}")
        nextTabItem.keyEquivalentModifierMask = [.command, .shift]
        nextTabItem.target = self
        menu.addItem(nextTabItem)
        return menu
    }
}
