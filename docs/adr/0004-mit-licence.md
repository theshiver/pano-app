# ADR 0004 — MIT licence

**Status:** accepted · 2026-09-16

## Context

The app ships on the Mac App Store. GPL-licensed apps conflict with the App Store
terms — VLC was pulled in 2011 for exactly this, and it is why Clipaste, a
GPL-3.0 clipboard manager, is not on the store at all. So GPL was never a real
option.

That left MIT, Apache-2.0 and MPL-2.0. MPL-2.0 was proposed first, because its
file-level copyleft makes it harder for someone to absorb the code into a closed
product.

## Decision

MIT.

## Rationale

The most familiar and most contribution-friendly licence, with no friction on the
App Store. Given that attracting contributors is one of the project's stated
goals, familiarity beats the marginal protection MPL would add.

## Consequences

- Anyone may take the code into a closed product. Accepted.
- The name "Pano", the wordmark and the icon are held back from the licence, which
  is what actually makes a clone unattractive in practice.
- Every contribution arrives under MIT; no CLA.
