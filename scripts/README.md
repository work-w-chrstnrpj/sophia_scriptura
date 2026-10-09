# Project scripts

This folder is intended for project automation scripts.

Use scripts for repeatable development, verification, setup, maintenance, data processing, release, or operational tasks.

## Available Scripts

| Script | Purpose |
| --- | --- |
| `install-ipad.sh` | Build signed Debug Sophia, verify the signature and bundle identity, install in place on the selected iPad, and launch. See the [deployment guide](../docs/deployment/deployment.md#scripted-installation). |
| `sync-ai-adapters.ps1` | Preferred target-aware sync for Claude, Codex, Cursor, Copilot, OpenCode, Aider, Cline, Kilo, Windsurf, Antigravity, and OpenHands adapters from canonical `.agents/` sources. |
| `generate-ai-adapters.ps1` | Compatibility wrapper that runs `sync-ai-adapters.ps1 -Target all`. |
| `validate-ai-template.ps1` | Validate canonical role metadata, skill frontmatter, generated adapter formatting, and absence of removed granular skills. Exits nonzero on failure. |

## Validation

Run validation after canonical changes or adapter regeneration:

```powershell
pwsh scripts/validate-ai-template.ps1
```

The validation script checks:

1. Canonical role metadata is parseable (`- **Name:**`, `- **Role:**`, `- **Description:**` at line starts).
2. Role files have adequate line count (not compressed).
3. Role files use `## Reusable Skills` and `## Embedded Capability Playbooks` (no deprecated `## Allowed Skills`).
4. Exactly 13 curated standalone skills are present with no extras or missing folders.
5. Every `.agents/skills/*/SKILL.md` has valid multiline YAML frontmatter with `name:` and `description:`.
6. Removed granular skill folders are not present.
7. Overlay files (`mentor.md`, `coach.md`, `README.md`) are readable Markdown.
8. Generated adapter files in `.claude/`, `.cursor/`, `.github/`, `.opencode/`, `.windsurf/` use multiline frontmatter (no `--- name:` on one line).
9. Generated agent/rule files contain source-of-truth notices pointing back to `.agents/`.
10. OpenCode overlay files (coach, mentor) deny edit permission.
11. `AGENTS.md` has adequate line count and heading structure.
12. Script files have adequate line count (not compressed).

## Adapter Sync

After canonical changes pass validation, regenerate adapters:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync-ai-adapters.ps1 -Target all
```

Then validate again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-ai-template.ps1
```

## Suggested Sections To Fill

- Script purpose.
- Required inputs.
- Expected outputs.
- Safe usage examples.
- Failure modes.
- Whether the script can change production, secrets, data, or tracked files.

Do not add destructive scripts without clear safeguards and documentation.
