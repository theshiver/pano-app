# ADR 0007 — Highlightr for syntax highlighting

**Status:** accepted · 2026-09-18 · supersedes the rendering half of ADR 0006

## Context

ADR 0006 shipped a hand-rolled, dependency-free highlighter. In daily use it was too
inconsistent (missed languages, mis-tokenised, mistook Java generics for HTML). Can
decided the glance-quality trade-off was not good enough and approved a dependency.

## Decision

Add **Highlightr** (https://github.com/raspu/Highlightr, 2.3.0) — highlight.js running
in JavaScriptCore — as a dependency of `PanoUI`. It renders an `NSAttributedString` for
~185 languages with mature theming.

- `PanoUI/CodeText` wraps Highlightr: one shared engine (JS-backed, main-actor), a
  curated set of themes in Settings, and the theme's own background applied behind the
  code so dark themes stay readable on a light system and vice versa.
- `PanoTransforms/CodeHighlighter` keeps only `detectLanguage` (dependency-free), which
  drives the row's language label and hints Highlightr; the old span tokeniser is gone.
- `ClipClassifier.isCode` (is-this-code-at-all) stays ours, and runs before the rich-text
  check because IDEs put RTF/HTML on the pasteboard next to code.

## Consequences

- First third-party dependency beyond GRDB. It is confined to `PanoUI`.
- JavaScriptCore is a system framework, so the local-only, no-network promise holds — but
  the bundle carries highlight.js and its themes (binary-size cost, accepted).
- `Package.resolved` in the Xcode workspace is committed so CI resolves the pinned version.
- Highlightr must be used on the main actor (JSC is not thread-safe); rendering happens in
  the preview, which is already main-actor.
