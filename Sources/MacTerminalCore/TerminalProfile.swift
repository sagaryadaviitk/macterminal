import Foundation

public enum TerminalCursorStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case blinkBlock
    case steadyBlock
    case blinkUnderline
    case steadyUnderline
    case blinkBar
    case steadyBar
}

public struct TerminalTheme: Codable, Equatable, Sendable {
    public var foregroundHex: String
    public var backgroundHex: String
    public var caretHex: String
    public var activeTitlebarHex: String
    public var inactiveTitlebarHex: String

    public init(
        foregroundHex: String,
        backgroundHex: String,
        caretHex: String,
        activeTitlebarHex: String,
        inactiveTitlebarHex: String
    ) {
        self.foregroundHex = foregroundHex
        self.backgroundHex = backgroundHex
        self.caretHex = caretHex
        self.activeTitlebarHex = activeTitlebarHex
        self.inactiveTitlebarHex = inactiveTitlebarHex
    }

    public static let dark = TerminalTheme(
        foregroundHex: "#DBDBD6",
        backgroundHex: "#111417",
        caretHex: "#30D158",
        activeTitlebarHex: "#293342",
        inactiveTitlebarHex: "#1C1F24"
    )
}

public struct TerminalProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var shellPath: String
    public var startupDirectory: String
    public var useLoginShell: Bool
    public var term: String
    public var fontFamily: String
    public var fontSize: Double
    public var scrollbackLines: Int
    public var cursorStyle: TerminalCursorStyle
    public var theme: TerminalTheme
    public var environmentOverrides: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        shellPath: String,
        startupDirectory: String,
        useLoginShell: Bool,
        term: String,
        fontFamily: String,
        fontSize: Double,
        scrollbackLines: Int,
        cursorStyle: TerminalCursorStyle,
        theme: TerminalTheme,
        environmentOverrides: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.shellPath = shellPath
        self.startupDirectory = startupDirectory
        self.useLoginShell = useLoginShell
        self.term = term
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.scrollbackLines = scrollbackLines
        self.cursorStyle = cursorStyle
        self.theme = theme
        self.environmentOverrides = environmentOverrides
    }

    public static func `default`(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> TerminalProfile {
        TerminalProfile(
            name: "Default",
            shellPath: ShellConfiguration.defaultShellPath(environment: environment),
            startupDirectory: homeDirectory,
            useLoginShell: true,
            term: "xterm-256color",
            fontFamily: "Menlo",
            fontSize: 13,
            scrollbackLines: 10_000,
            cursorStyle: .steadyBlock,
            theme: .dark
        )
    }

    public func normalized(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> TerminalProfile {
        let fallback = TerminalProfile.default(environment: environment, homeDirectory: homeDirectory)
        var copy = self

        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.name.isEmpty {
            copy.name = fallback.name
        }

        if copy.shellPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.shellPath = fallback.shellPath
        }

        if copy.startupDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.startupDirectory = homeDirectory
        }

        copy.term = copy.term.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.term.isEmpty {
            copy.term = fallback.term
        }

        copy.fontFamily = copy.fontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.fontFamily.isEmpty {
            copy.fontFamily = fallback.fontFamily
        }

        copy.fontSize = min(max(copy.fontSize, 8), 36)
        copy.scrollbackLines = min(max(copy.scrollbackLines, 1_000), 200_000)

        if !Self.isHexColor(copy.theme.foregroundHex) {
            copy.theme.foregroundHex = fallback.theme.foregroundHex
        }
        if !Self.isHexColor(copy.theme.backgroundHex) {
            copy.theme.backgroundHex = fallback.theme.backgroundHex
        }
        if !Self.isHexColor(copy.theme.caretHex) {
            copy.theme.caretHex = fallback.theme.caretHex
        }
        if !Self.isHexColor(copy.theme.activeTitlebarHex) {
            copy.theme.activeTitlebarHex = fallback.theme.activeTitlebarHex
        }
        if !Self.isHexColor(copy.theme.inactiveTitlebarHex) {
            copy.theme.inactiveTitlebarHex = fallback.theme.inactiveTitlebarHex
        }

        return copy
    }

    public static func isHexColor(_ value: String) -> Bool {
        let pattern = #"^#[0-9a-fA-F]{6}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var profiles: [TerminalProfile]
    public var activeProfileID: UUID
    public var confirmBeforeClosingRunningPanes: Bool

    public init(
        profiles: [TerminalProfile],
        activeProfileID: UUID,
        confirmBeforeClosingRunningPanes: Bool = true
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.confirmBeforeClosingRunningPanes = confirmBeforeClosingRunningPanes
    }

    private enum CodingKeys: String, CodingKey {
        case profiles
        case activeProfileID
        case confirmBeforeClosingRunningPanes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profiles = try container.decode([TerminalProfile].self, forKey: .profiles)
        self.activeProfileID = try container.decode(UUID.self, forKey: .activeProfileID)
        self.confirmBeforeClosingRunningPanes = try container.decodeIfPresent(
            Bool.self,
            forKey: .confirmBeforeClosingRunningPanes
        ) ?? true
    }

    public static func `default`(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> AppPreferences {
        let profile = TerminalProfile.default(environment: environment, homeDirectory: homeDirectory)
        return AppPreferences(profiles: [profile], activeProfileID: profile.id)
    }

    public var activeProfile: TerminalProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles[0]
    }

    public func normalized(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> AppPreferences {
        var normalizedProfiles = profiles
            .map { $0.normalized(environment: environment, homeDirectory: homeDirectory) }
        if normalizedProfiles.isEmpty {
            normalizedProfiles = [TerminalProfile.default(environment: environment, homeDirectory: homeDirectory)]
        }

        let activeID = normalizedProfiles.contains { $0.id == activeProfileID }
            ? activeProfileID
            : normalizedProfiles[0].id
        return AppPreferences(
            profiles: normalizedProfiles,
            activeProfileID: activeID,
            confirmBeforeClosingRunningPanes: confirmBeforeClosingRunningPanes
        )
    }
}
