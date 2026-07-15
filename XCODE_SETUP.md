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
- The project-level Debug configuration defines the Swift `DEBUG` condition.
- The app mirrors `limit-snapshot.json` into the widget container so the local Debug widget can read current data.

Release is the distribution path.

- The app target uses `Config/CodexLimitWidgetApp.entitlements`.
- The widget target uses `Config/LimitWidgetExtension.entitlements`.
- Both release targets need a valid Apple signing team and provisioning profiles for `group.com.hamlet.codex-limit-widget`.

## Verify

Before Xcode packaging:

```sh
# Run from the project root.
swift test --scratch-path /tmp/codex-limit-widget-test
swift build --scratch-path /tmp/codex-limit-widget-build
```

After Xcode packaging:

```sh
xcodebuild -project "Codex Limit Widget.xcodeproj" -scheme "Codex Limit Widget" -configuration Debug -derivedDataPath /tmp/codex-limit-widget-derived build
./script/build_and_run.sh smoke
```

Then run the app once so it can write the widget snapshot. The app refreshes every 1 minute through `CodexLimitRefreshPolicy.refreshIntervalSeconds == 60`. The widget timeline also requests refresh after 1 minute, but macOS may throttle WidgetKit reload timing.

## Release build

Verify the unsigned universal Release compile without changing signing configuration:

```sh
xcodebuild \
  -project "Codex Limit Widget.xcodeproj" \
  -scheme "Codex Limit Widget" \
  -configuration Release \
  -derivedDataPath /tmp/codex-limit-widget-release \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

lipo -info "/tmp/codex-limit-widget-release/Build/Products/Release/Codex Limit Widget.app/Contents/MacOS/Codex Limit Widget"
```

Create and round-trip verify the host-architecture local preview with:

```sh
./script/package_local_preview.sh
```

The resulting `dist/` zip is ad-hoc signed, not Developer ID signed or notarized, and is for local use only. A distributable Release still requires manual signing setup, valid provisioning profiles, Developer ID signing, and notarization.
