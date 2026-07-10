# Codex Limit Widget

<img src="Resources/AppLogo.png" width="96" alt="Codex Limit Widget logo">

Codex Limit Widget is a small macOS menu bar app with a WidgetKit widget for tracking Codex usage limits.

It reads your existing Codex Desktop login from `~/.codex/auth.json`, checks the read-only usage endpoints, then writes a sanitized local snapshot for the widget. The widget does not store your bearer token.

## Install

The easiest path is the prebuilt zip from GitHub Releases.

1. Download `Codex-Limit-Widget.zip` from the latest release.
2. Unzip it.
3. Move `Codex Limit Widget.app` into `/Applications`.
4. Open the app once.
5. Keep Codex Desktop installed and logged in on the same Mac.

This preview build is not notarized. If macOS blocks it, Control-click the app, choose Open, then choose Open again in the confirmation dialog.

## Add the widget

1. Open the macOS widget gallery.
2. Search for `Codex Limit Widget`.
3. Choose the size you want and add it to the desktop or Notification Center.
4. Open the app once if the widget says it has not checked yet.

The app refreshes every minute. WidgetKit may update the visible widget a little slower when macOS throttles background refreshes.

## What it shows

- 5-hour usage remaining
- Weekly usage remaining
- Named model-specific usage limits when Codex returns them
- Flexible-credit balance, with banked resets as a legacy fallback
- Active model and reasoning effort from `~/.codex/config.toml`
- Next reset timing
- Last checked time
- Local auth, API, and snapshot errors when a check fails

## Build from source

Requirements:

- macOS 14 or newer
- Xcode with macOS development tools
- Swift toolchain
- Codex Desktop already logged in

Run the checks:

```sh
swift test --scratch-path /tmp/codex-limit-widget-test
swift run --scratch-path /tmp/codex-limit-widget-checks CodexLimitCoreChecks
swift build --scratch-path /tmp/codex-limit-widget-build
```

Build the app and widget:

```sh
xcodebuild -project "Codex Limit Widget.xcodeproj" -scheme "Codex Limit Widget" -configuration Debug -derivedDataPath /tmp/codex-limit-widget-derived build
```

Or use the project run entrypoint, which builds and launches the app:

```sh
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

The Debug build is intended for local use on your own Mac. Release distribution still needs an Apple signing team, provisioning profiles, and notarization.

## Troubleshooting

If the widget does not show current values, open `Codex Limit Widget.app` once and wait for the first check. The app owns the Codex auth read and writes the snapshot the widget displays.

If the widget still shows old data, remove it from the desktop or Notification Center and add it again from the widget gallery.

If the app reports an auth error, open Codex Desktop and make sure you are signed in.
