# Release history

This is the version index in the Sophia documentation wiki. Each published release gets
one immutable Git tag and a notes page here. Add future releases newest first; preserve
older entries and document corrections explicitly rather than moving published tags.

Owner-authorized exception (2026-10-04): `v0.1.0` was republished to include additional
uncommitted work. Its original release commit was `ae8b9de`; see the updated release
notes. A second owner-authorized replacement supersedes `6fd524e` with the current
Trash/archive, About/legal and workflow changes. Future versions retain the immutable-tag
policy unless explicitly authorized.

| Version | Date | Summary | Notes |
| --- | --- | --- | --- |
| [v1.6.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.6.0) | 2026-10-30 | Daily Plan playback/Activity, direct Day selection, optional Catch up, managed folder naming and Prayer menu polish | [Release notes](v1.6.0.md) |
| [v1.5.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.5.0) | 2026-10-25 | Inline Plan autosave, managed folders, paired recovery and shared Scripture editing | [Release notes](v1.5.0.md) |
| [v1.4.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.4.0) | 2026-10-20 | Collection Plans, checked reflections, stable authoring, Items wording and reader position restoration | [Release notes](v1.4.0.md) |
| [v1.3.2](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.3.2) | 2026-10-18 | Quiz Me ready-bank lifecycle/refill reliability, matching summary actions and expanded app documentation | [Release notes](v1.3.2.md) |
| [v1.3.1](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.3.1) | 2026-10-16 | Link editing, study-material subfolder drops and compact Points to Ponder cards | [Release notes](v1.3.1.md) |
| [v1.3.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.3.0) | 2026-10-15 | Points to Ponder, study conversions, record duplication and Journal types | [Release notes](v1.3.0.md) |
| [v1.2.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.2.0) | 2026-10-14 | Collection Smart Order/actions, Sophy commands and Qwen adapters | [Release notes](v1.2.0.md) |
| [v1.1.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.1.0) | 2026-10-13 | Folder moves, shared note cards/statuses and repeated quiz rounds | [Release notes](v1.1.0.md) |
| [v1.0.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v1.0.0) | 2026-10-13 | Multi-source Scripture, Hello AO downloads and narration | [Release notes](v1.0.0.md) |
| [v0.4.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.4.0) | 2026-10-10 | Sophy, Hugging Face BYOK, music/Activity system controls and configurable PiP | [Release notes](v0.4.0.md) |
| [v0.3.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.3.0) | 2026-10-09 | Compound ink/stroke editing, Notes/Collections access locks, Journal fields and optional Activity workflows | [Release notes](v0.3.0.md) |
| [v0.2.2](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.2.2) | 2026-10-07 | Collections material fixes and Canvas selection/performance improvements | [Release notes](v0.2.2.md) |
| [v0.2.1](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.2.1) | 2026-10-05 | Notes bulk-delete confirmation and captured selection | [Release notes](v0.2.1.md) |
| [v0.2.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.2.0) | 2026-10-05 | Notes formatting/media, fixed Page/Journal scale, Canvas controls, annotation refinements | [Release notes](v0.2.0.md) |
| [v0.1.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.1.0) | 2026-10-04 | First tagged personal-use release: Scripture, study hubs, Notes, Collections, Companion and Activity | [Release notes](v0.1.0.md) |

SP-048 changes are included in v1.3.2; they are not part of the v1.3.1 snapshot.
This index uses the repository release notes and local Git history; it is not a live
GitHub publication-status check.

These are personal iPad source releases, not App Store distributions. See
[deployment](../deployment/deployment.md) for signing and installation and
[test evidence](../testing/test-specification.md) for verification boundaries.

## Acceptance follow-ups

v0.3.0 delivers SP-025–028 source and automated verification under the owner-selected app access policy. Physical Pencil, performance, biometric and accessibility acceptance remain open in their tickets.

## Publishing another version

The repository uses two branches: `main` holds the release baseline and `development`
starts from `main` for future work. On 2026-10-04 the current app was fast-forwarded
into `main`, `development` was created from it, and superseded branches were removed.
Their history is recoverable from the local, ignored Git bundle
`build/branches-before-main-development-20261004.bundle`.

1. Review the intended changes and exclude credentials, private data and generated builds.
2. Run relevant checks against the release snapshot and record failures and unverified areas.
3. Add `vX.Y.Z.md` with highlights, compatibility, installation, checks and limitations;
   insert its row above. Align the Xcode marketing version when changing app versions.
4. Commit and push to **`main`**. The [Release workflow](../../.github/workflows/release.yml)
   runs unit tests, then creates tag `vX.Y.Z` and the GitHub Release from
   `docs/releases/vX.Y.Z.md` when that tag does not exist yet. You can still publish
   manually with `gh release create` if CI is unavailable.
5. Verify the remote tag/release points to the intended commit. Do not attach personally
   provisioned builds or user data. Never overwrite an existing published tag.
