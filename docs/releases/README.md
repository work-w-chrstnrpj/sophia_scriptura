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
| [v0.1.0](https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/tag/v0.1.0) | 2026-10-04 | First tagged personal-use release: Scripture, study hubs, Notes, Collections, Companion and Activity | [Release notes](v0.1.0.md) |

These are personal iPad source releases, not App Store distributions. See
[deployment](../deployment/deployment.md) for signing and installation and
[test evidence](../testing/test-specification.md) for verification boundaries.

## Publishing another version

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
