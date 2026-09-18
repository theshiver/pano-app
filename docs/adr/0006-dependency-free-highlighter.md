# ADR 0006 — A dependency-free syntax highlighter

**Status:** accepted · 2026-09-18

## Context

The preview highlights copied code (weeks 5–6). A highlighter needs a tokeniser and
language detection. The options were a hand-rolled regex highlighter, or a library —
most capably Highlightr, which wraps highlight.js (~185 languages, auto-detect) via
JavaScriptCore.

CLAUDE.md forbids a third-party dependency beyond GRDB without an ADR, and the product
promise is "local only, minimal dependencies".

## Decision

Hand-rolled, dependency-free. `CodeHighlighter` in `PanoTransforms` tokenises with
regexes into keyword / string / comment / number, with per-language specs, and guesses
the language from structural signals. Languages: swift, javascript, python, json, shell,
html, css, java, sql.

## Rationale

- The preview is glance-quality, not an editor. Approximate colouring is enough.
- Zero dependency keeps the binary small, avoids bundling a JS engine + highlight.js,
  and keeps the "minimal dependencies" promise intact.
- Full control, no supply-chain surface.

## Consequences

- Fewer languages and lower accuracy than highlight.js. Adding a language is a small
  `Spec` plus detection signals.
- Detection is heuristic and conservative; ambiguous snippets render plain.
- If broad language coverage becomes a real user need, revisit with Highlightr behind a
  new ADR — JavaScriptCore is a system framework, so it would not break the local-only
  promise, but it is a meaningful dependency and binary-size cost.

## Note

Code detection runs before the rich-text check in `ClipClassifier`: IDEs put RTF/HTML on
the pasteboard next to the plain code, which otherwise hides every snippet as rich text.
