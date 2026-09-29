# SP-010 — Licensed offline translations

Status: implementation and physical download complete; offline/accessibility acceptance pending. Milestone: M2. Owner selected NIV11, NLT and NKJV and supplied
provider approval in the task conversation. The subsequent owner-supplied license update
permits unlimited personal bulk Copy/Share and text extraction. This is the recorded
source of authorization; no independent correspondence verification is claimed.

Visible outcome: choose WEB/NIV/NLT/NKJV in Sophia, manually download and sync full licensed
editions, read offline from encrypted local storage, and lock licensed text after 30 days
without completed validation/sync. WEB remains independent and permanently offline.

Boundaries:
- Core/Scripture: edition identity, lease and library contracts.
- Infrastructure/Scripture: authenticated API adapter, typed JSON parser, staged sync.
- Infrastructure/Persistence: Core Data with AES-GCM-encrypted content/metadata payloads.
- Infrastructure/Security: device-only Keychain credentials and encryption/time state.
- Features/Scripture: version management, progress, lock UX and edition-aware restoration.
- App composition: inject the library, with no provider secrets in source/resources.
- Tests/docs: schema/parser, encryption, expiry, rollback, interrupted sync, copy authorization,
  edition switching, renderer regressions, signed build and device evidence.

No AI/TTS feature, publisher-content redistribution, store migration, or App Store release.
Personal Copy/Share has no numerical limit under the updated permission. The content
store stays in protected app storage; no database-export feature is added.

Implementation sequence: domain/API parser → encrypted store and transactional sync →
reader/version UI → focused tests → signed iPad deployment and approved downloads.
The owner need not approve these routine steps again. Old license guidance in SP-002 is
superseded only for this specific account/application by the supplied approval.

Evidence: focused SP-010 XCTest suite passed 7/7 in `build/sp010/licensed-r6.xcresult`;
combined reader/SP-010 unit regression passed 19/19 in `build/sp010/m2-unit-r1.xcresult`.
On 2026-09-28, the paired iPad launched the installed signed build and used the transient
DEBUG launch environment to place the existing credential into the device-only Keychain
and start the authorized sync. Device-local diagnostics reported `complete` with 1,189 of
1,189 chapters for NIV11, NLT and NKJV. Sophia was then terminated and relaunched normally
without the transient environment. No credential or licensed text was written to source,
documentation, test results or diagnostics. Airplane-mode reading, expiry/renewal,
VoiceOver and final visual acceptance remain unverified. The separately attempted UI
runner produced no valid result bundle after a simulator debugger-launch warning; it is
an unresolved verification gap, not a passing result.

2026-09-29 correction: the owner reported unwanted provider usage from automatic sync.
Removed both automatic paths: near-expiry sync from app resume and the DEBUG launch
environment's sync-all behavior. Launch/resume now performs local status and access checks
only; provider calls require an explicit Sync button. Sophia displays the provider's NIV11
edition as NIV while preserving its stable provider ID and existing encrypted download.
Focused `LicensedTranslationTests` passed 8/8 in
`build/sp010/manual-sync-r2.xcresult`, including a near-expiry resume case that verifies
zero sync calls and an edition-switch assertion for the NIV display label. The owner
reported airplane-mode reading works. Expiry/renewal testing is intentionally deferred;
VoiceOver remains the only current accessibility acceptance item, with visual acceptance
deferred to a future redesign conversation.

Combined reader/provider unit regression passed 20/20 in
`build/sp010/manual-sync-reader-r1.xcresult`. The signed update passed local code-sign
verification and installed over the existing iPad app while retaining its data-container
identity. iPadOS then denied CoreDevice launch because the Personal Team profile requires
device trust; the owner must complete that one-time system trust action before launch can
be observed on the physical device.

### Development-period cache exception — 2026-09-29

The owner supplied written API.Bible authorization naming Sophia Scriptura and NIV11, NLT
and NKJV, permitting encrypted local copies to remain available beyond 30 days during
development, testing, debugging and rebuilds. Sophia now applies this exception only to
Debug builds through `OfflineContentPolicy.developmentException`; Release and Archive keep
the standard lease. Revocation, rollback protection, encryption, attribution and secure
storage remain enforced. The Versions screen identifies the development authorization so
it is not mistaken for unrestricted production rights.

### Cached access recovery — 2026-09-29

Debug builds honor the owner-supplied development authorization for existing encrypted
NIV11, NLT and NKJV copies even when an earlier denied sync set the legacy shared
access-block flag. Failed API requests still fail; they do not invalidate these separately
authorized development copies. The flag is retained and enforced by the standard policy
in Release/Archive. Missing or invalid encrypted content and clock rollback still block
access. Opening cached translations does not start a sync or download.

Verification: `build/sp010/access-recovery-r1.xcresult` passed 9/9 licensed-translation
tests on iPad (A16), Simulator 26.5. The signed Debug build installed over the existing
app and launched on the physical iPad. Fresh `SP010-access.json` diagnostics from that
build reported cached=true and available=true for all three approved editions. No sync
or redownload was performed. This proves cache authorization availability; it does not
claim a complete manual reading or accessibility walkthrough.
