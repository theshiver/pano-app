# ADR 0001 — macOS only, local only

**Status:** accepted · 2026-09-16

## Context

The project started as a universal clipboard manager for macOS and iOS with
iCloud sync. Research showed the iOS half was the hardest part of the build and
the weakest part of every competitor, because Apple does not allow background
pasteboard reads on iOS.

Then the actual motivation surfaced: this is a personal daily tool and an
open-source contribution, not a business. The author uses a clipboard manager on
the Mac, has one Mac, and does not want this data on a network under any
circumstances.

## Decision

macOS only. Local only. No sync, no cloud, no account, no telemetry, and no
network entitlement in the app at all.

## Consequences

Good:
- The hardest engineering in the original plan disappears: `CKSyncEngine`,
  conflict resolution, offline queues, quota management, the keyboard extension,
  the Picture-in-Picture capture trick.
- The scope drops from roughly 16 weeks to 8.
- The privacy claim becomes unconditional and verifiable rather than a promise,
  because the entitlement is simply absent.
- SwiftData's only real attraction was its CloudKit integration, so the storage
  decision resolves cleanly (see ADR 0002).

Bad:
- Users who want their clipboard on a phone are not served. That is accepted.
- A future reversal would be expensive: the schema is single-device, with no
  record identity or change-tracking columns. If sync is ever wanted, it is a new
  major version, not a feature.

## Rejected alternative

Fetching the page title and favicon for a copied URL, which would make the list
much more readable. Rejected because it requires a network request and would
puncture the central claim.
