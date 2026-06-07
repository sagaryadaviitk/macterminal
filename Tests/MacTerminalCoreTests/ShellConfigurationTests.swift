import Foundation
import XCTest
@testable import MacTerminalCore

final class ShellConfigurationTests: XCTestCase {
    func testShellConfigurationBuildsTerminalEnvironment() {
        let configuration = ShellConfiguration(
            shellPath: "/bin/zsh",
            currentDirectory: "/tmp/project",
            baseEnvironment: [
                "HOME": "/Users/example",
                "PATH": "/usr/bin:/bin",
                "USER": "example"
            ]
        )

        XCTAssertEqual(configuration.execName, "-zsh")
        XCTAssertTrue(configuration.environment.contains("TERM=xterm-256color"))
        XCTAssertTrue(configuration.environment.contains("TERM_PROGRAM=MacTerminal"))
        XCTAssertTrue(configuration.environment.contains("PWD=/tmp/project"))
        XCTAssertTrue(configuration.environment.contains("PATH=/usr/bin:/bin"))
        XCTAssertEqual(configuration.execName, "-zsh")
        XCTAssertEqual(configuration.scrollbackLines, 10_000)
    }

    func testDefaultShellFallsBackToZshWhenEnvironmentShellIsMissing() {
        let shellPath = ShellConfiguration.defaultShellPath(environment: [:])

        XCTAssertEqual(shellPath, "/bin/zsh")
    }

    func testLocalShellCanRunSimpleCommand() throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "echo ok"]
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(output, "ok\n")
    }

    func testShellConfigurationUsesProfileEnvironmentOverrides() {
        var profile = TerminalProfile.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )
        profile.term = "xterm-macterminal"
        profile.useLoginShell = false
        profile.scrollbackLines = 50_000
        profile.environmentOverrides = [
            "EDITOR": "vim",
            "TERM_PROGRAM": "Ignored"
        ]

        let configuration = ShellConfiguration(
            profile: profile,
            currentDirectory: "/tmp/work",
            baseEnvironment: ["PATH": "/bin", "SHELL": "/bin/zsh"]
        )

        XCTAssertEqual(configuration.shellPath, "/bin/zsh")
        XCTAssertEqual(configuration.currentDirectory, "/tmp/work")
        XCTAssertEqual(configuration.execName, "zsh")
        XCTAssertEqual(configuration.scrollbackLines, 50_000)
        XCTAssertTrue(configuration.environment.contains("TERM=xterm-macterminal"))
        XCTAssertTrue(configuration.environment.contains("TERM_PROGRAM=MacTerminal"))
        XCTAssertTrue(configuration.environment.contains("EDITOR=vim"))
        XCTAssertTrue(configuration.environment.contains("PWD=/tmp/work"))
    }
}
