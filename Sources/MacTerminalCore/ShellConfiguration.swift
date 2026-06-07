import Foundation

public struct ShellConfiguration: Equatable, Sendable {
    public let shellPath: String
    public let currentDirectory: String
    public let environment: [String]
    public let execName: String
    public let scrollbackLines: Int

    public init(
        shellPath: String = ShellConfiguration.defaultShellPath(),
        currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        useLoginShell: Bool = true,
        term: String = "xterm-256color",
        scrollbackLines: Int = 10_000,
        environmentOverrides: [String: String] = [:]
    ) {
        self.shellPath = shellPath
        self.currentDirectory = currentDirectory
        self.scrollbackLines = scrollbackLines

        var environmentMap = baseEnvironment
        for (key, value) in environmentOverrides {
            environmentMap[key] = value
        }
        environmentMap["TERM"] = term
        environmentMap["TERM_PROGRAM"] = "MacTerminal"
        environmentMap["PWD"] = currentDirectory
        self.environment = environmentMap
            .map { "\($0.key)=\($0.value)" }
            .sorted()

        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        self.execName = useLoginShell ? "-\(shellName)" : shellName
    }

    public init(
        profile: TerminalProfile,
        currentDirectory: String? = nil,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let normalizedProfile = profile.normalized(environment: baseEnvironment)
        self.init(
            shellPath: normalizedProfile.shellPath,
            currentDirectory: currentDirectory ?? normalizedProfile.startupDirectory,
            baseEnvironment: baseEnvironment,
            useLoginShell: normalizedProfile.useLoginShell,
            term: normalizedProfile.term,
            scrollbackLines: normalizedProfile.scrollbackLines,
            environmentOverrides: normalizedProfile.environmentOverrides
        )
    }

    public static func defaultShellPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let fileManager = FileManager.default
        if let shell = environment["SHELL"], fileManager.isExecutableFile(atPath: shell) {
            return shell
        }
        return "/bin/zsh"
    }
}
