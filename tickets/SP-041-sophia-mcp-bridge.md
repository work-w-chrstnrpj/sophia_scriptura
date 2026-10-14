# SP-041 — Sophia MCP bridge for external AI clients

Status: draft; detailed planning complete; implementation not selected.
Type: feature + architecture/security integration. Priority: medium.
Created: 2026-10-13, owner requested planning.
Milestone: proposed post-v1.1.0 study automation; target release unassigned.
Owners: System Architect and Backend/Integration; Frontend, Security, DevOps, SQA and Documentation support. Role names do not authorize delegation.
Requirements: owner request to connect Sophia to ChatGPT, Cursor and Claude; ticket-local MCP-AC criteria below. No new global requirement IDs are asserted.
Dependencies: SP-013/015/020/029 and SP-026–028 access policy. SP-042/043 are optional later tool integrations, not prerequisites for read-only bridging.

## Usable outcome

From an explicitly paired AI client, search eligible Sophia notes/collections and retrieve selected text with source references. Later approved phases propose changes that the owner reviews and commits inside Sophia. Sophia remains the authoritative offline app: external clients never read its sandbox files directly or write JSON generations.

Example: “Find my notes about forgiveness” returns bounded matches. “Create a Page containing this outline in Romans Study” stages a native preview; nothing is saved until the owner accepts it in Sophia. These are target examples, not implemented tools.

## Current implementation evidence

- `application/SophiaScriptura/SophiaScriptura/Features/Notes/NotesSession.swift`: guarded editing/opening, metadata updates, autosave and selected editor context.
- `Features/Collections/CollectionsStore.swift` under that same app source root: ancestor access, filing and folder commands; `allowsNoteOpening` distinguishes an explicit folder route from library visibility.
- `Core/Sophy/SophyEligibility.swift`: bulk retrieval excludes protected notes/folders even when unlocked, archived/trashed items, unknown ancestry and notes with excluded memberships.
- `Features/Sophy/SophyActionExecutor.swift`: existing reviewed action execution. Reuse eligible domain commands, not Sophy's LLM response format as a trusted external API.
- `Core/Scripture/TranslationSourceContracts.swift`: edition-specific operation/AI disclosure boundaries.
- No MCP server, authenticated device bridge, cross-device sync or always-on backend is implemented. Existing local JSON repositories are not integration APIs.

Read [TDD](../docs/tdd/tdd.md), [item protection](../docs/security/item-protection.md), [backward compatibility](../docs/guidelines/backward-compatibility.md), [Companion design](../docs/design/companion-screen-specification.md) and [SP-029](SP-029-v040-sophy-lady-wisdom.md) before implementation.

## Recommended scope and decisions

1. Start with one iPad, one owner and one Mac helper. Pairing/bridge is off by default. The iPad app must be foreground, unlocked and explicitly connected; unavailable means unavailable, never a silently stale copy of the library.
2. Recommend an optional TypeScript helper using a pinned official MCP SDK; validate runtime/SDK/client versions in G0. This is a new optional local integration component, not a replacement backend or a requirement to run Sophia normally.
3. Cursor/local Claude surfaces use a local MCP transport if supported by the chosen surface. ChatGPT and Claude remote connectors require an appropriate reachable/authenticated remote transport. “Claude Desktop” alone is not a transport specification: distinguish local extensions/Claude Code from cloud custom connectors.
4. Use one app-owned command/query contract behind MCP. Protocol handling and AI-client authentication live on the Mac; permission decisions, entity lookup and commits live on the iPad.
5. Ship read-only first. Native reviewed writes are a separate checkpoint. No unattended writes, deletion, bulk rewrite, protection changes, backup/restore, API-key operations, arbitrary URLs, shell commands or filesystem tools.
6. Preserve existing bulk Sophy eligibility: protected records and their protected ancestry are excluded, even if manually unlocked. MCP never requests biometrics/passwords or implicitly grants access. A future selected protected-content exception requires its own reviewed design.
7. A host's approval dialog is supplementary; it never substitutes for Sophia's write preview or its access checks. Disclosed content cannot be retracted from an external AI conversation after receipt; make that clear at connection setup.

### Proposed topology

```text
Cursor / Claude local client → local MCP helper on Mac
ChatGPT / Claude remote client → authenticated MCP transport → same helper
                                                    ↓
                            paired encrypted app channel (Mac ↔ iPad)
                                                    ↓
                        Sophia query/approval coordinator → existing stores
```

Recommendation: app-initiated TLS/WebSocket connection to the paired Mac, certificate pinning plus a rotating device-bound pairing secret, implemented only after G0 proves foreground networking on the owner setup. Local-network permission and optional Bonjour discovery must have clear descriptions and a manual address fallback. Do not disable TLS validation, enable broad ATS exceptions or assume cable installation implies an application data channel. Authentication of the AI client and pairing of the iPad are separate trust boundaries.

Remote access is opt-in. Evaluate authenticated private tunneling first where the target client supports it; otherwise use an authenticated HTTPS endpoint with minimal exposure. No automatic public tunnel, hosting purchase or account setup during implementation. Cloud copies of the study library are excluded. Remote connectivity and account entitlement are unverified until tested for the owner's exact client/account.

## Proposed capability contract

Tool names below are proposals; freeze a versioned schema in G1 before coding the adapters.

| Phase | Tool/capability | Scope and result |
| --- | --- | --- |
| Read | `sophia.connection_status` | Connection state/capabilities only; no study data or credential details |
| Read | `sophia.search_study` | Eligible Notes/Collections; bounded query, opaque paging, title/type/source ID, short excerpt |
| Read | `sophia.get_note` | Requested eligible note's typed text, kind, status, revision and canonical citation references; no images/ink/audio by default |
| Read | `sophia.list_collection` | One eligible folder, paginated eligible children/material references; no hidden-item counts |
| Read | `sophia.activity_summary` | Owner-enabled aggregate period/mode totals; no journal body, quiz answers or private record descriptions |
| Reviewed write | `sophia.propose_change` | Allowlisted create Page, create folder, file existing note, update supported note status; returns pending request ID |
| Reviewed write | `sophia.change_status` | Pending/approved/saved/rejected/expired/conflict/failed; success only after durable app save |
| Deferred | OCR/enhancement tools | Only after SP-042/043 acceptance and explicit selected-content handles; never remote gesture simulation |

For read-only launch, default to explicitly chosen folder scope (or chosen standalone notes). No whole-library access by default. Typed note bodies can contain Scripture quotations: do not assume every stored body is cleared for external disclosure. Route annotated citation spans through rights checks; if provenance cannot be safely separated, return metadata/reference only and explain the limitation without exposing restricted content. Arbitrary personal typed text is user-disclosed, not a license authorization for entire imported editions.

### Request, approval and persistence rules

- Envelope: contract version, authenticated client identity, request UUID, operation, typed arguments, expected entity revision and expiry. The app establishes identity; a client-provided display name is not proof of identity.
- Return consistent typed errors: `not_connected`, `not_available`, `invalid_request`, `unsupported`, `access_denied`, `conflict`, `expired`, `cancelled`, `save_failed`. Unknown IDs and inaccessible IDs use indistinguishable external responses.
- Proposals name the exact destination and before/after content. Owner may edit or reject them; edited arguments become a new reviewed digest. No approve-all batch in the initial implementation.
- Recheck scope, membership, entity revision, destination access, app foreground and pairing at acceptance and immediately before disclosure/commit. Consent is bound to request digest/client/generation, not a reusable boolean.
- Serialize writes through existing stores and flush before acknowledging saved. Use durable idempotency receipts containing operation digest and result IDs, never full private payloads. A lost response must not duplicate a note. Same request ID with different arguments is rejected.
- Cancel pending proposals when the app backgrounds, pair is revoked, source is locked/deleted/moved outside scope, connection is replaced or expiry passes. Do not auto-replay writes after reconnect.
- Default proposed budgets: 20 results/page, 100 maximum requested results, query ≤500 characters, request ≤64 KiB, response ≤256 KiB, one active write, four concurrent reads, read timeout 15 seconds and proposal expiry two minutes. Validate these in G0; changes require documented rationale. Oversized bodies paginate explicitly, never silently truncate with a completeness claim.
- Mac helper keeps no persistent content cache. Diagnostics contain request ID, tool name, outcome and duration only, not titles, bodies, OCR, prompts, secrets or provider replies. Disable SDK payload logging.
- Pair secrets in device/Mac Keychain, revoke per client, rotate after compromise, show connected client and last operation in Settings. Audit metadata must not outlive configured retention indefinitely; recommend a 30-day local capped receipt history.

## Ownership and proposed files

Existing sessions/stores retain persistence and access ownership. Proposed new boundaries, not existing files:

- `Core/Bridge/`: versioned request/result values, limits, capabilities and idempotency contract.
- `Features/Bridge/`: Settings pairing/scope controls, pending review UI and foreground coordinator.
- `Infrastructure/Bridge/`: paired channel, device-bound credentials and checked receipt persistence.
- `integrations/sophia-mcp/`: optional Mac helper, transport adapters, setup documentation and contract tests. This directory does not yet exist.

Do not add bridge transport into `NotesSession`, `RootTabView` or Sophy prompt parsing. Map approved operations to their existing command APIs. Any missing durable command acknowledgement must be added narrowly with regression coverage before write tools are enabled.

## Execution checkpoints

- **G0 feasibility/security spike:** test one mock read over paired encrypted channel and one selected local MCP client; document iPad suspension/disconnect behavior, actual client transports/entitlements, pinned SDK version and threat model. No study data or public exposure needed. Stop if scope/auth/foreground gating cannot be enforced.
- **G1 read contract:** freeze schema, scope semantics, rights handling, error equivalence and limits; implement mocked contract/authorization tests before live data.
- **G2 read-only integration:** one local client with actual eligible test records; explicit Settings enable/disable; native no-connection UX. Complete MCP-01–08.
- **G3 reviewed writes:** separate owner selection/checkpoint; native editable preview, concurrency/version checks and durable idempotency. Complete MCP-09–12 before advertising write tools.
- **G4 remote compatibility:** separately owner-selected endpoint/tunnel configuration. Validate ChatGPT and Claude remote connector independently; report unsupported/blocked surfaces rather than claiming universal compatibility.
- **G5 optional workflow skill:** after tools exist, add a reusable client skill describing search/select/propose/review workflows and restricted tool use. A skill cannot add network reachability or grant access. Sync AI adapters only if canonical AI assets change.

## Acceptance and verification matrix

All evidence starts **Not Run**. Synthetic data first; no real credential/content logs.

| ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| MCP-01 | Bridge disabled means no listener/disclosure; normal offline app remains usable | App/helper tests and device check |
| MCP-02 | Pair/revoke/re-pair works; wrong secret, certificate or client identity fails closed | Transport adversarial tests + two-device/manual check |
| MCP-03 | Search/get/list obey explicit scope and deny protected/archived/unknown-ancestry records without existence leaks | Contract tests across nested/multiple memberships |
| MCP-04 | Relock/move/scope change during a read cancels disclosure; reconnect cannot return cached private data | Race tests |
| MCP-05 | Returned text/citations obey edition policy and completeness limits | Rights fixtures, request capture with synthetic text |
| MCP-06 | Backgrounded/offline/suspended iPad returns typed unavailable; no silent stale reads | Physical iPad background/reconnect matrix |
| MCP-07 | Payload/query/page/concurrency limits and malformed/prompt-injection content cannot invoke extra operations | Fuzz/contract tests |
| MCP-08 | Chosen local client's actual discovery/read workflow works; credentials/logs contain no payloads | MCP Inspector + client smoke transcript redacted |
| MCP-09 | External proposed writes remain pending until native approval; rejection/expiry produces no mutation | UI/integration checks |
| MCP-10 | Stale revisions, changed destination, lock and cancelled approval prevent save | Race tests + nested-folder UI |
| MCP-11 | Duplicate/retried requests produce exactly one durable result across reconnect/crash; save failure is not success | Fault-injected repository tests |
| MCP-12 | App restart, backup/restore and bridge disable revoke pending grants without damaging notes | Recovery/device tests |
| MCP-13 | ChatGPT and Claude remote surfaces each authenticate and search independently, or are explicitly blocked with account/transport reason | Owner-account smoke checks; no inferred passes |

## Documentation, risks and stop conditions

Update TDD, bridge protocol/security contract, project map, Settings design, deployment/client setup, backup policy if receipts persist, manual test cases and tracker. Local read-only delivery may be marked implemented while remote/write checkpoints remain open; the complete ticket is not done until all selected checkpoints have evidence and exclusions are agreed.

Stop on permission bypass, private content in logs, raw repository writes, insecure transport, client incompatibility requiring unapproved hosting, or absence of durable idempotency for writes. Do not use app access locks as a claim of encrypted storage. Revalidate official client docs at execution time; account support and MCP protocol versions can change.

References checked 2026-10-13: [MCP architecture](https://modelcontextprotocol.io/docs/learn/architecture), [Cursor MCP](https://prod.cursor.com/help/customization/mcp), [OpenAI custom MCP setup](https://developers.openai.com/plugins/build/app-quickstart), [OpenAI private tunnels](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels), [Claude remote MCP](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp).

Evidence/status: planning only; no server, pairing, tools, client setup or application changes executed.
