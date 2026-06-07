import Foundation
import XCTest
@testable import MacTerminalCore

final class TerminalProfileTests: XCTestCase {
    func testDefaultPreferencesContainOneActiveProfile() {
        let preferences = AppPreferences.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )

        XCTAssertEqual(preferences.profiles.count, 1)
        XCTAssertEqual(preferences.activeProfile.name, "Default")
        XCTAssertEqual(preferences.activeProfile.shellPath, "/bin/zsh")
        XCTAssertEqual(preferences.activeProfile.startupDirectory, "/Users/example")
        XCTAssertTrue(preferences.confirmBeforeClosingRunningPanes)
    }

    func testProfileNormalizationClampsRiskyValuesAndRepairsInvalidColors() {
        var profile = TerminalProfile.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )
        profile.name = " "
        profile.fontSize = 200
        profile.scrollbackLines = 10
        profile.theme.foregroundHex = "red"
        profile.theme.backgroundHex = "#010203"

        let normalized = profile.normalized(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )

        XCTAssertEqual(normalized.name, "Default")
        XCTAssertEqual(normalized.fontSize, 36)
        XCTAssertEqual(normalized.scrollbackLines, 1_000)
        XCTAssertEqual(normalized.theme.foregroundHex, TerminalTheme.dark.foregroundHex)
        XCTAssertEqual(normalized.theme.backgroundHex, "#010203")
    }

    func testPreferencesNormalizationRepairsMissingActiveProfile() {
        let profile = TerminalProfile.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )
        let preferences = AppPreferences(profiles: [profile], activeProfileID: UUID())
            .normalized(environment: ["SHELL": "/bin/zsh"], homeDirectory: "/Users/example")

        XCTAssertEqual(preferences.activeProfileID, profile.id)
    }

    func testEmptyPreferencesNormalizeToDefaultProfile() {
        let preferences = AppPreferences(profiles: [], activeProfileID: UUID())
            .normalized(environment: ["SHELL": "/bin/zsh"], homeDirectory: "/Users/example")

        XCTAssertEqual(preferences.profiles.count, 1)
        XCTAssertEqual(preferences.activeProfile.startupDirectory, "/Users/example")
        XCTAssertTrue(preferences.confirmBeforeClosingRunningPanes)
    }

    func testHexColorValidationAcceptsOnlySixDigitHexValues() {
        XCTAssertTrue(TerminalProfile.isHexColor("#AABBCC"))
        XCTAssertTrue(TerminalProfile.isHexColor("#aabbcc"))
        XCTAssertFalse(TerminalProfile.isHexColor("AABBCC"))
        XCTAssertFalse(TerminalProfile.isHexColor("#ABC"))
        XCTAssertFalse(TerminalProfile.isHexColor("#GGGGGG"))
    }

    func testPreferencesDecodeLegacyDataWithCloseConfirmationEnabled() throws {
        let profile = TerminalProfile.default(
            environment: ["SHELL": "/bin/zsh"],
            homeDirectory: "/Users/example"
        )
        let legacyJSON = """
        {
          "profiles": [
            {
              "id": "\(profile.id.uuidString)",
              "name": "Default",
              "shellPath": "/bin/zsh",
              "startupDirectory": "/Users/example",
              "useLoginShell": true,
              "term": "xterm-256color",
              "fontFamily": "Menlo",
              "fontSize": 13,
              "scrollbackLines": 10000,
              "cursorStyle": "steadyBlock",
              "theme": {
                "foregroundHex": "#DBDBD6",
                "backgroundHex": "#111417",
                "caretHex": "#30D158",
                "activeTitlebarHex": "#293342",
                "inactiveTitlebarHex": "#1C1F24"
              },
              "environmentOverrides": {}
            }
          ],
          "activeProfileID": "\(profile.id.uuidString)"
        }
        """

        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(legacyJSON.utf8))

        XCTAssertTrue(decoded.confirmBeforeClosingRunningPanes)
    }
}
