# Current Codex Usage Design

## Goal

Update Codex Limit Widget for the Codex configuration and usage payload currently present on this Mac without changing its authentication, one-minute refresh, or sandbox-mirror architecture.

## Current inputs

- `~/.codex/config.toml` supplies the active root-level `model` and `model_reasoning_effort` values.
- `/backend-api/wham/usage` supplies the plan, base 5-hour and weekly windows, named `additional_rate_limits`, flexible-credit balance, and legacy banked-reset count.
- `/backend-api/wham/rate-limit-reset-credits` remains the preferred source for the legacy reset count.

The app reads auth and configuration. The widget receives only the sanitized snapshot; it never receives bearer-token data.

## Presentation

- Small widget: base 5-hour and weekly capacity plus flexible-credit balance.
- Medium widget: small-widget data plus the active model and reasoning effort.
- Large widget, menu bar popover, and main app: include named model-specific rate-limit windows.
- When flexible-credit data is absent, retain the existing banked-reset display as a compatibility fallback.
- Keep WidgetKit's one-minute requested refresh cadence and acknowledge that macOS can throttle visible updates.

## Compatibility and errors

New snapshot fields are optional so snapshots saved by version 0.1 remain readable. Missing or malformed `config.toml` settings do not fail usage refresh; the model line is simply omitted. Existing auth, HTTP, and snapshot errors remain visible.

## Verification

- A current-schema fixture must cover `prolite`, named limits, string credit balance, and current settings.
- The Swift tests must pass.
- The Xcode app/widget scheme must build.
- The built app must launch and write a live mirrored snapshot containing current base limits, named limits, credit balance, model, and reasoning effort.
