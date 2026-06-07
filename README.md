# MacTerminal

MacTerminal is a native macOS terminal app with real local shell panes, tabs, horizontal and vertical splits, profile-backed preferences, pane focus cycling, and a local `.app` packaging script.

## Requirements

- macOS 14 or newer
- Xcode 26.3 / Swift 6.2

## Build

```sh
swift build
```

Regenerate the app icon after changing `scripts/generate_app_icon.swift`:

```sh
swift scripts/generate_app_icon.swift
iconutil -c icns Resources/MacTerminal.iconset -o Resources/MacTerminal.icns
```

Or with Xcode's package scheme:

```sh
xcodebuild -scheme MacTerminal -destination 'platform=macOS' build
```

## Run As An App

```sh
./scripts/package_app.sh
open .build/debug/MacTerminal.app
```

You can also run:

```sh
./scripts/run_app.sh
```

Install into `~/Applications` for Spotlight:

```sh
./scripts/install_app.sh
```

## Shortcuts

- `Cmd+T`: new tab.
- `Cmd+D`: split active pane right.
- `Shift+Cmd+D`: split active pane down.
- `Cmd+W`: close active pane. The final pane is kept open.
- `Shift+Cmd+W`: close tab.
- `Cmd+[` / `Cmd+]`: focus previous or next pane.
- `Shift+Cmd+{` / `Shift+Cmd+}`: previous or next tab.
- `Cmd+Plus` / `Cmd+Minus`: change font size for the current tab.
- `Cmd+,`: preferences.

## Preferences

Preferences are stored under the app bundle ID `com.sagaryadav.macterminal`.
The active profile controls shell path, startup directory, login-shell behavior,
font family/size, terminal colors, cursor style, `TERM`, scrollback, and
environment overrides.

## Test

```sh
swift test
```
