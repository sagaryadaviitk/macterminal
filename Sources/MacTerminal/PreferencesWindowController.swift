import AppKit
import MacTerminalCore

final class PreferencesWindowController: NSWindowController {
    private let store: AppPreferencesStore
    private var preferences: AppPreferences
    private var profile: TerminalProfile

    private let shellPathField = NSTextField()
    private let startupDirectoryField = NSTextField()
    private let loginShellCheckbox = NSButton(checkboxWithTitle: "Login shell", target: nil, action: nil)
    private let confirmCloseRunningPanesCheckbox = NSButton(
        checkboxWithTitle: "Confirm before closing running panes",
        target: nil,
        action: nil
    )
    private let fontFamilyField = NSTextField()
    private let fontSizeField = NSTextField()
    private let foregroundField = NSTextField()
    private let backgroundField = NSTextField()
    private let caretField = NSTextField()
    private let termField = NSTextField()
    private let scrollbackField = NSTextField()
    private let environmentTextView = NSTextView()
    private let cursorPopup = NSPopUpButton()

    init(store: AppPreferencesStore = .shared) {
        self.store = store
        self.preferences = store.preferences
        self.profile = preferences.activeProfile

        let contentViewController = NSViewController()
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 430))
        window.center()

        super.init(window: window)
        buildContent(in: contentViewController)
        loadProfileIntoControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        preferences = store.preferences
        profile = preferences.activeProfile
        loadProfileIntoControls()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    private func buildContent(in viewController: NSViewController) {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(makeTab(title: "General", views: [
            row("Shell", shellPathField),
            row("Startup Directory", startupDirectoryField),
            checkboxRow(loginShellCheckbox),
            checkboxRow(confirmCloseRunningPanesCheckbox)
        ]))
        tabView.addTabViewItem(makeTab(title: "Appearance", views: [
            row("Font Family", fontFamilyField),
            row("Font Size", fontSizeField),
            row("Foreground", foregroundField),
            row("Background", backgroundField),
            row("Caret", caretField),
            row("Cursor", cursorPopup)
        ]))
        tabView.addTabViewItem(makeTab(title: "Terminal", views: [
            row("TERM", termField),
            row("Scrollback Lines", scrollbackField),
            textViewRow("Environment", environmentTextView)
        ]))

        cursorPopup.removeAllItems()
        cursorPopup.addItems(withTitles: TerminalCursorStyle.allCases.map(\.rawValue))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        let spacer = NSView()
        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetPreferences))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        buttons.addArrangedSubview(spacer)
        buttons.addArrangedSubview(resetButton)
        buttons.addArrangedSubview(saveButton)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        root.addArrangedSubview(tabView)
        root.addArrangedSubview(buttons)

        viewController.view = NSView()
        viewController.view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            root.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            root.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            tabView.heightAnchor.constraint(equalToConstant: 330)
        ])
    }

    private func makeTab(title: String, views: [NSView]) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 14, bottom: 14, right: 14)
        for view in views {
            stack.addArrangedSubview(view)
        }

        item.view = stack
        return item
    }

    private func row(_ title: String, _ control: NSControl) -> NSView {
        control.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        control.widthAnchor.constraint(equalToConstant: 300).isActive = true
        return row
    }

    private func textViewRow(_ title: String, _ textView: NSTextView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true

        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.widthAnchor.constraint(equalToConstant: 300).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 90).isActive = true

        let row = NSStackView(views: [label, scrollView])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        return row
    }

    private func checkboxRow(_ checkbox: NSButton) -> NSView {
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 140).isActive = true
        let row = NSStackView(views: [spacer, checkbox])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func loadProfileIntoControls() {
        shellPathField.stringValue = profile.shellPath
        startupDirectoryField.stringValue = profile.startupDirectory
        loginShellCheckbox.state = profile.useLoginShell ? .on : .off
        confirmCloseRunningPanesCheckbox.state = preferences.confirmBeforeClosingRunningPanes ? .on : .off
        fontFamilyField.stringValue = profile.fontFamily
        fontSizeField.stringValue = String(format: "%.0f", profile.fontSize)
        foregroundField.stringValue = profile.theme.foregroundHex
        backgroundField.stringValue = profile.theme.backgroundHex
        caretField.stringValue = profile.theme.caretHex
        termField.stringValue = profile.term
        scrollbackField.stringValue = "\(profile.scrollbackLines)"
        environmentTextView.string = profile.environmentOverrides
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
        cursorPopup.selectItem(withTitle: profile.cursorStyle.rawValue)
    }

    @objc private func savePreferences() {
        var updated = profile
        updated.shellPath = shellPathField.stringValue
        updated.startupDirectory = startupDirectoryField.stringValue
        updated.useLoginShell = loginShellCheckbox.state == .on
        updated.fontFamily = fontFamilyField.stringValue
        updated.fontSize = Double(fontSizeField.stringValue) ?? updated.fontSize
        updated.theme.foregroundHex = foregroundField.stringValue
        updated.theme.backgroundHex = backgroundField.stringValue
        updated.theme.caretHex = caretField.stringValue
        updated.term = termField.stringValue
        updated.scrollbackLines = Int(scrollbackField.stringValue) ?? updated.scrollbackLines
        updated.environmentOverrides = parseEnvironmentOverrides(environmentTextView.string)
        if let title = cursorPopup.selectedItem?.title,
           let cursorStyle = TerminalCursorStyle(rawValue: title) {
            updated.cursorStyle = cursorStyle
        }
        profile = updated.normalized()

        var updatedPreferences = store.preferences
        if let index = updatedPreferences.profiles.firstIndex(where: { $0.id == profile.id }) {
            updatedPreferences.profiles[index] = profile
        } else {
            updatedPreferences.profiles.append(profile)
        }
        updatedPreferences.activeProfileID = profile.id
        updatedPreferences.confirmBeforeClosingRunningPanes = confirmCloseRunningPanesCheckbox.state == .on
        preferences = updatedPreferences.normalized()
        store.preferences = preferences
    }

    @objc private func resetPreferences() {
        preferences = AppPreferences.default()
        profile = preferences.activeProfile
        loadProfileIntoControls()
        store.preferences = preferences
    }

    private func parseEnvironmentOverrides(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in text.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=") else {
                continue
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                continue
            }
            result[key] = value
        }
        return result
    }
}
