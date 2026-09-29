# Application — Sophia Scriptura (iPadOS)

The native SwiftUI iPad app. This is the primary user-facing runtime.

- Xcode project: `application/SophiaScriptura/` (created in Phase 1 on the owner's Mac).
- Platform: iPadOS 17+, Swift 5.9+, Xcode 16+.
- Distribution: personal sideload from Xcode (free Apple Developer account, 7-day
  signing validity). Not an App Store product.

Current status: M2 offline WEBP reader under acceptance in the six-tab app with the native SP-006 experiment under Notes and an
SP-007 Collections prototype. Collections uses sample data and resets on relaunch;
it is not yet suitable for storing personal study material.
Simulator build and unit tests passed; UI and device verification are in progress. The
[TDD](../docs/tdd/tdd.md) and [development plan](../docs/development-plan/development-plan.md)
identify proposed choices and supersede the old phase references in source comments.
Owner reports iPad A16 with iPadOS 26.6.2. Minimum deployment target remains to be reviewed.

## Structure (target)

- `SophiaScripturaApp.swift` — current `@main` app entry; reader dependencies are composed in RootTabView.
- `RootTabView.swift` — the accessible bottom navigation container.
- `Features/` — one folder per tab: `Scripture`, `Collections`, `Notes`, `Companion`,
  `Activity`, `Settings`.
- `Core/` — cross-feature modules: `ScriptureRenderer`, `AnnotationEngine`,
  `VerseAnchorHub`, `LLMAdapter`, `AudioEngine`, `ContentStore`, `UserStore`,
  `KeychainStore`.
- `Models/` — SwiftData models (see `docs/tdd/tdd.md` §7).
- `Resources/` — verified WEBP SQLite database and provenance manifest; assets.

## Entry Points and Routing

Navigation is a custom bottom container with six state-preserving destinations. A future Companion panel over Scripture is proposed, not implemented.

## Calls to Services and Integrations

Proposed online integrations call selected providers directly from the device.
YouVersion, Crossway, and API.Bible are candidates pending content/access verification;
no provider integration is currently implemented. Keychain access is proposed; no provider credentials are currently used by the experiment. See
`docs/tdd/tdd.md` §8 and ticket SP-002.

## Tests

App-specific unit and UI test targets exist for SP-006; cross-cutting test plans
and manual cases live in `tests/` and `docs/testing/`.

Open **Notes → Open canvas experiment**. See the [iPad walkthrough](../docs/testing/sp006-ipad-guide.md) and [signing guide](../docs/deployment/deployment.md).

Reader ownership, checks and remaining gaps: [SP-009 evidence](../docs/testing/sp009-reader-evidence.md).
