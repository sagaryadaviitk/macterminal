import AppKit
import MacTerminalCore
import SwiftTerm

final class TerminalSessionController: NSObject, LocalProcessTerminalViewDelegate {
    let paneID: UUID
    let terminalView: FocusReportingTerminalView

    private let shellConfiguration: ShellConfiguration
    private var profile: TerminalProfile
    private var hasStarted = false
    private let onTitleChange: (UUID, String) -> Void
    private let onDirectoryChange: (UUID, String) -> Void
    private let onProcessStateChange: (UUID, ProcessState) -> Void

    init(
        pane: TerminalPane,
        profile: TerminalProfile,
        onTitleChange: @escaping (UUID, String) -> Void,
        onDirectoryChange: @escaping (UUID, String) -> Void,
        onProcessStateChange: @escaping (UUID, ProcessState) -> Void
    ) {
        self.paneID = pane.id
        var launchProfile = profile.normalized()
        launchProfile.shellPath = pane.shellPath
        self.profile = launchProfile
        self.shellConfiguration = ShellConfiguration(profile: launchProfile, currentDirectory: pane.cwd)
        self.terminalView = FocusReportingTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 560))
        self.onTitleChange = onTitleChange
        self.onDirectoryChange = onDirectoryChange
        self.onProcessStateChange = onProcessStateChange
        super.init()

        configureTerminalView()
    }

    func startIfNeeded() {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        terminalView.startProcess(
            executable: shellConfiguration.shellPath,
            args: [],
            environment: shellConfiguration.environment,
            execName: shellConfiguration.execName,
            currentDirectory: shellConfiguration.currentDirectory
        )
        onProcessStateChange(paneID, .running)
    }

    func terminate() {
        terminalView.terminate()
    }

    func apply(profile: TerminalProfile) {
        self.profile = profile.normalized()
        applyAppearance()
    }

    func copySelection() {
        terminalView.copy(self)
    }

    func pasteClipboard() {
        terminalView.paste(self)
    }

    func zoomFont(by delta: CGFloat) {
        let nextSize = min(max(terminalView.font.pointSize + delta, 8), 36)
        let currentName = terminalView.font.fontName
        terminalView.font = NSFont(name: currentName, size: nextSize)
            ?? NSFont.monospacedSystemFont(ofSize: nextSize, weight: .regular)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onTitleChange(paneID, title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, !directory.isEmpty else {
            return
        }

        if let url = URL(string: directory), url.isFileURL {
            onDirectoryChange(paneID, url.path)
        } else {
            onDirectoryChange(paneID, directory)
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onProcessStateChange(paneID, .exited)
        terminalView.feed(text: "\r\n[Process completed]\r\n")
    }

    private func configureTerminalView() {
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.processDelegate = self
        terminalView.wantsLayer = true
        terminalView.autoresizingMask = []
        terminalView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        terminalView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        terminalView.metalBufferingMode = .perFrameAggregated

        do {
            try terminalView.setUseMetal(false)
        } catch {
            NSLog("MacTerminal: unable to disable Metal renderer: \(error)")
        }

        terminalView.menu = makeContextMenu()
        applyAppearance()
    }

    private func applyAppearance() {
        let foreground = NSColor(hex: profile.theme.foregroundHex) ?? NSColor(calibratedRed: 0.86, green: 0.86, blue: 0.84, alpha: 1)
        let background = NSColor(hex: profile.theme.backgroundHex) ?? NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        let caret = NSColor(hex: profile.theme.caretHex) ?? .systemGreen
        let font = NSFont(name: profile.fontFamily, size: CGFloat(profile.fontSize))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(profile.fontSize), weight: .regular)

        terminalView.font = font
        terminalView.nativeForegroundColor = foreground
        terminalView.nativeBackgroundColor = background
        terminalView.layer?.backgroundColor = background.cgColor
        terminalView.caretColor = caret
        terminalView.changeScrollback(profile.scrollbackLines)
        terminalView.getTerminal().setCursorStyle(swiftTermCursorStyle(profile.cursorStyle))
        terminalView.needsDisplay = true
    }

    @objc private func copyFromContextMenu(_ sender: Any?) {
        copySelection()
    }

    @objc private func pasteFromContextMenu(_ sender: Any?) {
        pasteClipboard()
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyFromContextMenu(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(pasteFromContextMenu(_:)), keyEquivalent: "")
        pasteItem.target = self
        menu.addItem(pasteItem)
        return menu
    }

    private func swiftTermCursorStyle(_ cursorStyle: TerminalCursorStyle) -> CursorStyle {
        switch cursorStyle {
        case .blinkBlock:
            return .blinkBlock
        case .steadyBlock:
            return .steadyBlock
        case .blinkUnderline:
            return .blinkUnderline
        case .steadyUnderline:
            return .steadyUnderline
        case .blinkBar:
            return .blinkBar
        case .steadyBar:
            return .steadyBar
        }
    }
}
