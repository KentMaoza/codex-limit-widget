# Current Codex Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the native macOS app and WidgetKit extension reflect the current Codex configuration, named rate limits, and flexible-credit balance.

**Architecture:** Extend the existing decoded usage response and sanitized `LimitSnapshot`; read two root-level values from `~/.codex/config.toml`; keep compact widget families focused while allowing detailed surfaces to render all returned windows. Preserve the current app-owned auth flow and widget-container mirror.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Foundation, SwiftPM verifier, XCTest, Xcode macOS build.

## Global Constraints

- Keep the refresh interval at exactly 60 seconds.
- Never write the bearer token into `LimitSnapshot` or the widget container.
- Keep new snapshot fields optional for version 0.1 compatibility.
- Do not add a TOML dependency; parse only the two required root string values.
- Do not refactor unrelated UI or auth code.

---

### Task 1: Decode the current Codex payload and configuration

**Files:**
- Create: `Sources/CodexLimitCore/CodexSettings.swift`
- Modify: `Sources/CodexLimitCore/LimitModels.swift`
- Modify: `Sources/CodexLimitCore/LimitSnapshotBuilder.swift`
- Modify: `Sources/CodexLimitCore/CodexLimitService.swift`
- Test: `Sources/CodexLimitCoreChecks/main.swift`
- Test: `Tests/CodexLimitCoreTests/CodexLimitCoreTests.swift`

**Interfaces:**
- Consumes: snake-case JSON decoded with `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`; `~/.codex/config.toml`.
- Produces: `CodexSettings.parse(_:)`, `CodexSettings.load(codexHome:)`, `CodexUsageResponse.additionalRateLimits`, `CodexUsageResponse.credits`, and optional snapshot fields `creditBalance`, `activeModel`, and `reasoningEffort`.

- [x] Add a current-response fixture with `prolite`, `additional_rate_limits`, and `credits.balance`.
- [x] Run `swift run --scratch-path /tmp/codex-limit-widget-checks CodexLimitCoreChecks` and observe the expected missing-schema failures.
- [x] Implement the minimal response, settings, and snapshot fields; append uniquely identified named windows after the base windows.
- [x] Run the checker after each red/green cycle and observe `CodexLimitCoreChecks passed`.
- [ ] Add an old-snapshot decoding assertion using JSON without the new optional keys.

### Task 2: Adapt the app and widget hierarchy

**Files:**
- Modify: `Sources/CodexLimitApp/ContentView.swift` in the header, grid, status message, and card-title sections.
- Modify: `Sources/CodexLimitApp/MenuBarStatusView.swift` in the header and window-list sections.
- Modify: `Sources/LimitWidget/LimitWidget.swift` separately for `small`, `medium`, and `large`.
- Modify: `Sources/CodexLimitApp/CodexLimitWidgetApp.swift` where save-error reconstruction preserves new fields.

**Interfaces:**
- Consumes: `LimitSnapshot.creditBalance`, `configurationLine`, base `fiveHourWindow`/`weeklyWindow`, and the ordered `windows` array.
- Produces: compact credit/config labels and detailed named-window rendering.

- [ ] Add computed snapshot display helpers that prefer credit balance and fall back to banked resets.
- [ ] Update the main header to say `usage monitor`, display the credit balance when present, and show `configurationLine`.
- [ ] Keep the main grid and menu popover rendering all windows, including named windows.
- [ ] Update small WidgetKit UI to show base meters plus credit/reset balance only.
- [ ] Update medium WidgetKit UI to show base meters plus `configurationLine` and balance.
- [ ] Keep large WidgetKit UI rendering every returned window, with configuration and balance in the header.
- [ ] Change WidgetKit gallery copy to mention usage, credits, and current configuration.
- [ ] Run the core checker and `swift test --scratch-path /tmp/codex-limit-widget-test`.

### Task 3: Add a stable project run entrypoint

**Files:**
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

**Interfaces:**
- Consumes: Xcode project scheme `Codex Limit Widget`.
- Produces: one kill/build/launch command and the Codex app `Run` action.

- [ ] Implement `script/build_and_run.sh` with `run`, `--debug`, `--logs`, `--telemetry`, and `--verify` modes, building into `/tmp/codex-limit-widget-derived`.
- [ ] Make the script executable.
- [ ] Point `.codex/environments/environment.toml` `Run` action to `./script/build_and_run.sh`.
- [ ] Run `./script/build_and_run.sh --verify` and require a successful process check.

### Task 4: Package and verify live data

**Files:**
- Refresh: `dist/Codex Limit Widget.app`
- Refresh: `dist/Codex Limit Widget.zip`
- Refresh: `/Applications/Codex Limit Widget.app`

**Interfaces:**
- Consumes: the successful Xcode Debug app product.
- Produces: installed and distributable app/widget bundles matching the source.

- [ ] Run the full core checker, Swift tests, Swift build, and Xcode build with fresh output.
- [ ] Use `ditto` to replace the app bundles in `/Applications` and `dist`, then rebuild `dist/Codex Limit Widget.zip`.
- [ ] Launch `/Applications/Codex Limit Widget.app` and verify the process is running.
- [ ] Read the mirrored `limit-snapshot.json` and assert current `activeModel`, `reasoningEffort`, `creditBalance`, and four usage windows without printing auth data.
- [ ] Inspect the final diff and confirm every changed line traces to the approved current-Codex update or build/run workflow.
