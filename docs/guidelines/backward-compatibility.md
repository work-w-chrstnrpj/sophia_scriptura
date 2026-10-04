# Backward compatibility

Sophia Scriptura is a personal sideload app with local study data on one iPad. **Future changes, fixes, and features must consider backward compatibility before implementation.**

## Expectations

1. **On-disk formats** — Prefer additive schema changes (new optional JSON fields, new Codable keys with defaults). When renaming semantics, migrate on read and keep writing legacy mirrors when older builds might still open the same files.
2. **Notes** — `deletedAt` remains a legacy export mirror of `trashedAt ?? archivedAt`. New fields: `archivedAt`, `trashedAt`. Older builds treat archived notes as hidden via `deletedAt`.
3. **Collections and Companion** — New optional `trashedAt` (and conversation trash timestamps) must decode as `nil` for existing stores.
4. **Behavior** — Destructive flows should not silently drop user data. Use Trash (30-day retention) before permanent deletion unless the user explicitly chooses permanent delete or a documented bulk wipe (Settings → Delete data).
5. **Verification** — When changing persistence, add or update unit tests for round-trip decode of v1/v2 payloads and migration paths.

## Design checklist

Before merging app changes that touch persistence or study artifacts:

- [ ] Can an older build still read files written by the new build (or fail safely without corruption)?
- [ ] Does load perform migration instead of requiring a one-time manual reset?
- [ ] Are new UI labels aligned with data semantics (Archive vs Trash)?
- [ ] Is permanent deletion explicit and separate from Trash?

Canonical product intent remains in [docs/tdd/tdd.md](../tdd/tdd.md) and data contracts under [docs/data/](../data/).
