# MacTerminal

MacTerminal is a native macOS terminal app with local shell panes, tabs, horizontal and vertical splits, profile-backed preferences, and pane focus controls.

## What It Does

- Runs real local shell sessions inside a packaged macOS app.
- Supports tabs, right splits, down splits, pane closing, and pane focus cycling.
- Stores terminal profiles for shell path, startup directory, fonts, colors, cursor style, `TERM`, scrollback, and environment overrides.
- Packages as `MacTerminal.app` for Finder, Dock, and Spotlight launch.

## Use It Yourself

Build and open a local app bundle:

```sh
./scripts/run_app.sh
```

Or package it manually:

```sh
./scripts/package_app.sh
open .build/debug/MacTerminal.app
```

Common shortcuts:

- `Cmd+T`: new tab
- `Cmd+D`: split right
- `Shift+Cmd+D`: split down
- `Cmd+W`: close active pane
- `Shift+Cmd+W`: close tab
- `Cmd+[` / `Cmd+]`: focus previous or next pane
- `Cmd+,`: preferences

## Find It In Spotlight

Install or update the app:

```sh
./scripts/install_app.sh
```

Quit MacTerminal before reinstalling. The installer builds an optimized release
by default, verifies the app's executable and signature, and preserves the old
bundle under `~/Library/Application Support/MacTerminal/Install Backups`.
It updates an existing `/Applications/MacTerminal.app`; otherwise it installs in
`~/Applications`. Set `MAC_TERMINAL_INSTALL_DIR` to choose another absolute directory.
Launch Services and Spotlight metadata are refreshed after installation.

Reinstallation replaces only the app bundle. It does not reset terminal profiles,
`~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh`, Oh My Zsh, custom themes, or plugins.
The default Zsh login session continues to load the current user's shell setup.
When installing on another laptop, that laptop's own shell configuration is used;
personal dotfiles and plugins are not bundled in this repository.

To select an installed SDK explicitly, for example on a Command Line Tools-only
machine with the macOS 26.5 SDK:

```sh
MAC_TERMINAL_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ./scripts/install_app.sh
```

The SDK override also applies to `package_app.sh` and `run_app.sh`. When the Metal
compiler is unavailable, packaging selects SwiftPM's native build backend and
uses MacTerminal's existing CPU renderer. Set `MAC_TERMINAL_BUILD_SYSTEM` to
select a build backend explicitly. Dependency resource bundles are included in
the packaged app.

Running the
XCTest suite requires a toolchain that includes XCTest, such as full Xcode.

After install, press `Cmd+Space` and search for `MacTerminal`. If it does not appear immediately, open it once from `~/Applications` and search again.

## Develop Locally

Requirements:

- macOS 14 or newer
- Xcode 26.3 / Swift 6.2
- Xcode Command Line Tools available on `PATH`

Build:

```sh
swift build
```

Run tests:

```sh
swift test
```

Build with Xcode:

```sh
xcodebuild -scheme MacTerminal -destination 'platform=macOS' build
```

## Contribute

Fork the repo, create a focused branch, and open a pull request with the behavior change and the tests you ran. Keep local app bundles, build products, shell history, and machine-specific paths out of commits.

## Production Notes

The packaging scripts create an ad-hoc signed app for local use. Public distribution should use Developer ID signing and notarization.
