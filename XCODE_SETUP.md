# Xcode setup

Full Xcode is required to package this as a macOS app with a WidgetKit extension.

## Existing project

The Xcode project already exists at:

```text
Codex Limit Widget.xcodeproj
```

Do not recreate the targets unless the project file is broken. The project contains:

- `Codex Limit Widget`: macOS app target.
- `LimitWidget`: WidgetKit extension target.
- `CodexLimitCore`: shared Swift framework target.

The app target registers this URL scheme:

```text
codex-limit-widget
```

The widget uses `codex-limit-widget://open`, so clicking it opens the app.

## Signing modes

Debug uses local signing so the app can run on this Mac without an Apple Development identity.

- The app target is locally signed and does not attach App Group entitlements in Debug.
- The widget target uses `Config/DebugWidgetExtension.entitlements`, which keeps the widget sandboxed but does not attach the App Group entitlement.
- The app mirrors `limit-snapshot.json` into the widget container so the local Debug widget can read current data.

Release is the distribution path.

- The app target uses `Config/CodexLimitWidgetApp.entitlements`.
- The widget target uses `Config/LimitWidgetExtension.entitlements`.
- Both release targets need a valid Apple signing team and provisioning profiles for `group.com.hamlet.codex-limit-widget`.

## Verify

Before Xcode packaging:

```sh
cd "/Users/hamlet/Documents/Codex Limit Widget"
swift test --scratch-path /tmp/codex-limit-widget-test
swift build --scratch-path /tmp/codex-limit-widget-build
```

After Xcode packaging:

```sh
xcodebuild -project "Codex Limit Widget.xcodeproj" -scheme "Codex Limit Widget" -configuration Debug -derivedDataPath /tmp/codex-limit-widget-derived build
```

Then run the app once so it can write the widget snapshot. The app refreshes every 1 minute through `CodexLimitRefreshPolicy.refreshIntervalSeconds == 60`. The widget timeline also requests refresh after 1 minute, but macOS may throttle WidgetKit reload timing.

## Release build

Release currently requires manual signing setup. Configure `DEVELOPMENT_TEAM`, signing identities, and provisioning profiles before running:

```sh
xcodebuild -project "Codex Limit Widget.xcodeproj" -scheme "Codex Limit Widget" -configuration Release build
```
