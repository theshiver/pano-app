# ADR 0009 — Isolated zero-dependency updater for PanoDirect

**Status:** accepted · 2026-11-27

## Context

`PanoDirect` (distributed via notarized DMG and Homebrew Cask) lives outside the Mac App Store, so users do not receive automatic App Store updates. At the same time, Pano's core privacy guarantee requires that:

1. Clipboard history and user data never leave the Mac.
2. The Mac App Store build (`Pano`) retains zero network code and zero network entitlements.
3. No third-party updater dependency or separate `appcast.xml` signing infrastructure is added unless strictly needed.

## Decision

Add a zero-dependency updater strictly behind `#if DIRECT_DISTRIBUTION` in `Pano/UpdateService.swift`:

- Periodic (24-hour, ETag-cached) and manual checks query `https://api.github.com/repos/theshiver/pano-app/releases/latest` using an ephemeral `URLSession` with no cookies or persistent cache.
- Update state (`UpdateModel`) and UI surfaces (menu bar item, panel `StatusBar` pill, and `Settings > About`) are injected only when `DIRECT_DISTRIBUTION` is enabled (`update == nil` in the Mac App Store target).
- In-place installation downloads the `.dmg` asset from GitHub Releases, mounts it read-only, verifies `codesign --verify --deep --strict`, Developer ID `Authority`, `TeamIdentifier`, `CFBundleIdentifier`, and semantic version, and atomically replaces the app bundle in `/Applications` or `~/Applications` before relaunching (falling back to opening the verified `.dmg` from `~/Downloads` when non-writable or translocated).

## Consequences

- The Mac App Store binary (`Pano`) compiles zero networking or process-spawning code and keeps identical entitlements.
- `PanoDirect` remains free of third-party updater dependencies (such as Sparkle) and requires no separate appcast or EdDSA key rotation.
- Privacy documentation distinguishes between clipboard data (strictly offline, never transmitted) and optional update checks against GitHub Releases in `PanoDirect`.
