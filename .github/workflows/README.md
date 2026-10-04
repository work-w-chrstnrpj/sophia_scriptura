# GitHub Actions

## `release.yml`

**Trigger:** push to **`main`** (for example after a PR merge), or manual **Run workflow**.

**Purpose:** Personal source releases — not App Store builds. See [docs/releases/README.md](../../docs/releases/README.md).

### What it does

1. **Verify (macOS):** Simulator build and `SophiaScripturaTests` only (`CODE_SIGNING_ALLOWED=NO`).
2. **Publish (Ubuntu):** Reads `MARKETING_VERSION` from `SophiaScriptura.xcodeproj`, then:
   - If tag `vX.Y.Z` **already exists** → skips (no error). Bump the marketing version to release again.
   - If tag is new → requires `docs/releases/vX.Y.Z.md`, then creates the GitHub Release on the merge commit.

### Before merging to main

1. Bump **Version** and **Build** on the SophiaScriptura target (or `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.pbxproj`).
2. Add `docs/releases/vX.Y.Z.md` and update the table in `docs/releases/README.md`.
3. Merge. Do **not** force-move or delete published tags.

### Secrets

Uses the default `GITHUB_TOKEN` (`contents: write`). No App Store or signing secrets.

### Changing the merge branch

Edit `on.push.branches` in `release.yml` if your integration branch is not `main`.

### Failure response

- **Verify failed:** Fix tests or the simulator build before merging.
- **Missing release notes:** Add `docs/releases/vX.Y.Z.md` matching the Xcode marketing version.
- **Skipped publish:** Expected when main moved without a version bump; tag already points at the last release.
