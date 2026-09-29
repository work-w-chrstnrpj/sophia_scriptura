# Shared

Stable assets and contracts reused by the iPad app (`application/`) and the
content-ingestion script (`service/`).

## Contents

- `usfm-books.json` — the 66-book Protestant canon with 3-letter USFM codes. These codes
  are a starting point for passage identifiers; canon scope and versification mappings
  still need explicit decisions.
- `prompt-presets.seed.json` — built-in AI Companion presets and the shared orthodox
  guardrail instruction. Future code will seed presets from this file; the current scaffold does not do so.
  The shared foundation, Biblical Studies and Christian Living wording is owner-approved
  (wording approved in revision 1; retained in seed revision 2); Apologetics and Tough Questions wording in revision 2 is also owner-approved. See TDD §12.

## Verse Reference Contract

Every meaning-level artifact (note quote, conversation link, saved verse, link
attachment) anchors to a canonical reference so links are shared across all translations:

- Single verse: `BOOK.CHAPTER.VERSE` (e.g. `EPH.2.8`).
- Range: `BOOK.CHAPTER.VSTART-VEND` (e.g. `EPH.2.8-9`).
- `BOOK` is the USFM code from `usfm-books.json`; `CHAPTER` and `VERSE` are integers.

Ink annotations are the exception: they are spatial and version-specific, so they are
proposed to include version, chapter, layer, and layout revision in their identity.
See TDD §7 and §10; raw strings alone do not define range overlap or cross-edition mapping.

## Boundaries

Keep this folder small and stable. Do not place feature-specific behavior here unless
both the app and the ingestion script genuinely use it.

## Companion context composition

`sharedGuardrail` is the shared foundation. Each preset's `systemInstruction` contains
exactly one `{{sharedGuardrail}}` marker. Future integration must substitute that marker
with the foundation and send the fully composed instruction in the selected provider's
supported instruction role on every request. Do not send the marker as text or omit the
foundation on follow-up turns. Snapshot resolved context/version for conversation provenance.

`reviewStatus` records wording approval only; it does not certify behavior. The seed has
no runtime consumer yet. Draft presets are not approved for use merely because the shared
foundation is approved. Existing `options` are metadata; toggling them requires explicit
prompt composition behavior in a future implementation, not just changing a JSON boolean.

Before release, evaluate follow-up context retention, unavailable retrieval, uncertain
citations, contested interpretations, original-language claims and pastoral responses.
These evaluations have not run; JSON/placeholder checks only verify the asset structure.

Seed revision 2 refines Apologetics and Tough Questions from the owner's new samples;
both are now `owner-approved`. Approval changes status only; instruction wording is unchanged. Conversational history is not a seed-prompt feature:
REQ-024 and TDD §12.1 specify the proposed local store/context-builder/adapter separation.
Setting a prompt alone does not implement memory or guarantee previous turns are included.
