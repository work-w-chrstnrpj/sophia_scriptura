import Foundation

// Architecture boundary markers for Sophia Scriptura's core modules.
//
// These protocols document the inward-facing interfaces described in
// `docs/tdd/tdd.md` sections 6–13. They are intentionally empty in the Phase 1 skeleton;
// each is implemented in its corresponding milestone. Keeping them here makes the module
// boundaries visible in code and gives later phases a stable place to grow.

/// Turns cached chapter data into a renderable layout with tappable verse anchors. (Phase 2)
protocol ScriptureRendering {}

/// Manages the PencilKit annotation layer per (version, chapter, layer). (Phase 3)
protocol AnnotationEngineProviding {}

/// Resolves a verse reference to every attached artifact and creates anchored artifacts. (Phase 4)
protocol VerseAnchorResolving {}

/// Normalizes chat requests/responses across BYOK providers. (Phase 5)
protocol LLMAdapting {}

/// Streams ESV narrated audio and falls back to on-device text-to-speech. (Phase 7)
protocol AudioEngineProviding {}

/// Reads-or-caches chapters from the offline SQLite scripture store. (Phase 2)
protocol ContentStoring {}

/// Secure read/write of provider API keys via the Keychain. (Phase 5)
protocol KeychainStoring {}
