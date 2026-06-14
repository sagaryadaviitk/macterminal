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

Install or update the app in `~/Applications`:

```sh
./scripts/install_app.sh
```

The install script builds `MacTerminal.app`, copies it to `~/Applications`, refreshes Launch Services, and imports Spotlight metadata when `mdimport` is available.

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
