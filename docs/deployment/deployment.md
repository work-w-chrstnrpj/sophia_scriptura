# Personal iPad deployment

## Scripted installation

Connect and unlock the iPad, then run in Terminal:

```bash
cd "/Users/chrixcrusher/Documents/Projects/Sophia App"
./scripts/install-ipad.sh
```

The [installer](../../scripts/install-ipad.sh) defaults to `iPad ni Paj`. It builds
the current checkout as signed Debug using the project's existing team, verifies
the signature and `com.personal.SophiaScriptura` identity, installs over the existing
app, and launches it with a string-only environment so inherited test variables are
not passed through. Current `devicectl` rejects an empty JSON object. It does not uninstall, reset data, change versions/signing settings, or
invoke translation sync. New release version bumps remain a separate step; a weekly
re-sign of the same source does not require changing the version.

First-time setup still requires the owner to sign in through Xcode, select the
existing Personal Team, pair/trust the iPad, enable Developer Mode, and trust the
developer profile if prompted. Signing may contact Apple and prompt for Keychain
access. The script cannot automate those account and device confirmations.

```bash
./scripts/install-ipad.sh --dry-run             # Preview only; no build/device calls
./scripts/install-ipad.sh --list-devices        # Show known devices
./scripts/install-ipad.sh --device "iPad ni Paj" # Or use its identifier
./scripts/install-ipad.sh --no-launch           # Install, then open manually
```

Xcode defaults to `/Applications/Xcode.app/Contents/Developer`; override with
`DEVELOPER_DIR` if needed. Logs are under `build/ipad-install/logs/`, and incremental
build outputs are under `build/ipad-install/DerivedData/`. Run one installer at a time.
The build uses `-allowProvisioningUpdates` to let Xcode maintain automatic signing.
Use the same command when Personal Team signing expires. Keep the same team and
bundle identifier, and do not delete the installed app to fix signing/trust errors.

If building or signature/identity validation fails, installation is skipped. If
launch fails after installation, the script reports that distinction: unlock the
iPad, complete any developer-profile trust prompt, and open Sophia manually.

Verification (2026-10-06): `bash -n`, dry-run and 15 mocked checks passed, covering
argument handling, quoted device names, install/launch success, failure stops,
wrong bundle rejection and exclusion of inherited launch variables. Local harness
and results: `build/ipad-installer-checks/{check.py,results.txt}`. At that date, an actual signed
build/install through this script was unverified. No app runtime code or product
milestone status changed.

### Current-worktree delivery — 2026-10-09

Owner requested building the app on the iPad after the Activity workflow follow-up.
The installer dry run and live device listing identified the paired physical iPad A16
`iPad ni Paj`. `./scripts/install-ipad.sh --device 00008120-0014354C112B601E` completed
the signed Debug build, strict signature verification, bundle-identity check,
in-place installation and normal CoreDevice launch successfully. Bundle identity is
`com.personal.SophiaScriptura`; existing version/build metadata remains **0.2.2 (19)**.
The delivered source includes the current compound ink, protection/review fixes,
Journal changes and optional Activity workflows. No uninstall, data reset or explicit
translation sync was performed. Logs: `build/ipad-install/logs/20261009-005046-36336/`.
Installation and launch establish delivery; physical feature acceptance remains open.

Same-day owner polish was also built, strictly signature-verified, installed in place and
launched successfully: remove the Scripture Contemplation section's Today line and rename
the activity type to Contemplating. Logs: `build/ipad-install/logs/20261009-005511-36992/`.
The 19 focused Activity tests passed before this deployment. No uninstall or data reset
was performed.

## Notes bulk-delete confirmation — 2026-10-05

Signed Debug **0.2.0 (17)** passed strict signature verification, installed in place
on `iPad ni Paj`, and launched normally without test-store variables. No uninstall
or personal-data reset was performed. Logs: `build/notes-bulk-delete/device-build.log`,
`signature.log`, `install.log`, and `launch.log`. The focused UI regression passed on
simulator and iPad; see the [test specification](../testing/test-specification.md).
The owner still needs to retry the originally failing Select notes → Delete interaction.

## v0.2.0 Scripture annotation fix — 2026-10-05

Signed Debug build **0.2.0 (6)** fixes Scripture Draw mode: the minimized palette no longer
blocks Pencil input, Notes releases the shared PencilKit picker when leaving the Notes tab,
and expanding the palette clears a stuck in-stroke state so the tool picker can appear.
Installed in place on `iPad ni Paj`. Log: `build/v020-device-annotation`.

## v0.2.0 Notes ink revert — 2026-10-05

Signed Debug build **0.2.0 (5)** restores the v0.1.0 PencilKit scroll sync (document-space
`ink.drawing`) and freezes that sync while the Pencil is down to reduce mid-stroke stretch.
Installed in place on `iPad ni Paj`. Log: `build/v020-device-revert`.

## v0.2.0 Notes ink viewport fix — 2026-10-05

Signed Debug build **0.2.0 (4)** replaces the paper/ink affine mapping with explicit scroll
zoom and offset transforms, merges viewport strokes back into the full document drawing,
keeps the Pencil layer visible on Canvas, and persists ink even when `didBeginUsingTool`
was skipped. Installed in place on `iPad ni Paj`. Log: `build/v020-device-fix2`.

## v0.2.0 Notes ink commit fix — 2026-10-05

Signed Debug build **0.2.0 (3)** fixes ink disappearing after a stroke by mapping the live
Pencil canvas back into document coordinates at stroke begin/end and avoiding stale note
reloads that cleared in-memory ink. Installed in place on `iPad ni Paj` and launched as
`com.personal.SophiaScriptura`. Logs: `build/v020-device-fix.log`.

## v0.2.0 Notes writing — 2026-10-05

Signed Debug build **0.2.0 (2)** passed strict signature verification, installed in place
on `iPad ni Paj`, and launched as `com.personal.SophiaScriptura`. The existing app was not
uninstalled. Logs: `build/v020-device.log`, `build/v020-device/install.log`, and
`build/v020-device/launch.log`. The app is
`build/v020-device/Build/Products/Debug-iphoneos/SophiaScriptura.app`.

`NotesTests` passed **29 tests, 0 failures** on the iPad (A16) simulator. Result:
`build/v020-notes.xcresult`. Page and Journal stay at 100% scale; horizontal movement is
available only while the Scripture pane is open. Confirm live Pencil feel, the insert row,
and the renamed appearance presets on the device.

## SP-023 response/source follow-up — 2026-10-04

Signed Debug build, strict signature verification, in-place installation and launch on
`iPad ni Paj` all passed. Existing data was preserved. Logs:
`build/companion-source-repair-device-20261004/{build,signature,install,launch}.log`.
The app was built using `build/chapter-hub-ask-device-20261004` as its derived-data directory.
`build/companion-source-repair-r3-20261004.xcresult` records 56 passing focused tests.

Chapter now sits in the annotation/actions row with its label and icon. Sources provides
publisher passage links, model links and labeled lookup when a direct URL is absent;
generated references are not marked as retrieved evidence. New manual Scripture Ask/chapter
chats correct the ALLaM fallback using an available curated Groq model. Existing chats keep
their model selection; choose a model in Model before retrying an old poor answer, or start
a new Ask. No historic replies are rewritten. Real-provider accuracy/quality remains an
owner acceptance check, not established by the fixture suite or installation.

## SP-023 Chapter Hub and contextual Ask — 2026-10-04

The signed Debug build passed strict signature verification, installed in place on
`iPad ni Paj`, and launched successfully as `com.personal.SophiaScriptura`. No uninstall,
data reset or translation sync was performed. Logs are retained under
`build/chapter-hub-ask-device-20261004/{build,signature,install,launch}.log`.
The final focused simulator suite passed **60 tests, 0 failures, 0 skipped** in
`build/chapter-hub-ask-final-20261004.xcresult`.

Start a new selection Ask or Verse Hub conversation and send a short question; authorized
full verse context and selected wording now accompany the provider-facing question.
Use the separate button beside the chapter title to open Chapter Hub and Ask about this
chapter with reference-only context. Existing OLA prompting remains intact; old responses
are not rewritten. Physical layout/routing and real-provider factual answer quality remain
owner checks in [SP-023](../../tickets/SP-023-chapter-hub-and-contextual-ask.md).

## Ask blank question composer — 2026-10-04

The signed Debug update passed strict signature verification, installed in place on
`iPad ni Paj` and launched successfully as `com.personal.SophiaScriptura`. No uninstall
or data reset was performed. Logs are retained under
`build/ask-blank-composer-device-20261004/`. The focused Companion suite passed 40 tests
in `build/ask-blank-composer-20261004.xcresult`, including OLA regression coverage.

Start a new Ask from Scripture: the question composer is blank and the verse remains
attached. Type your own question, then Send. Existing messages/drafts are not rewritten;
OLA keeps its current behavior. Actual provider answer quality remains an owner check.

## OLA selection-aware analysis — 2026-10-04

The signed Debug update passed strict signature verification, installed in place on
`iPad ni Paj` and launched as `com.personal.SophiaScriptura`. No uninstall or data reset
was performed. Evidence is retained in `build/ola-selection-device-20261004/`
(`build.log`, `signature.log`, `install.log`, `launch.log`).

Start a new Original Language Analysis request to test the `OLA:` title, selected
word/phrase, translation and complete verse attachment. Existing conversations retain
their original titles/prompts. The focused Companion/reader suite passed 52 tests in
`build/ola-selection-20261004.xcresult`. No real provider request was made for verification;
independent lexical and cross-reference checking remains an owner acceptance requirement.

## Companion native Markdown correction — 2026-10-03

This update supersedes the earlier response-rendering recovery below. The signed Debug
build passed strict signature verification, installed in place on `iPad ni Paj`, and
launched successfully as `com.personal.SophiaScriptura`. No uninstall or data reset was
performed. Logs are retained in `build/companion-native-markdown-device/`.

`build/companion-native-markdown-final.xcresult` records 35 passing Companion and adapter
checks. Exported light/dark previews were visually inspected in wide and narrow panels.
Streaming and saved Markdown are preserved verbatim; Foundation supplies the full parser.
Provider requests require standard Markdown with actual newlines. Retry an affected
response or Edit and resend its prompt: old replies already saved with broken formatting
are not automatically rewritten. Physical/live-provider acceptance remains an owner check.

## Companion response rendering — 2026-10-03

The signed Debug update passed strict signature verification and installed in place on
`iPad ni Paj`, preserving the existing installation without uninstall or data reset.
CoreDevice launch was denied because the device was locked. Unlock and open Sophia to
review response headings/lists/paragraphs and content-sized prompt bubbles. Evidence is
under `build/companion-rendering-device/`; the final Companion simulator suite passed
33 checks in `build/companion-rendering-layout-final.xcresult`. Visual/device acceptance
remains pending.

## SP-020 Activity installation — 2026-10-03

The signed Debug build passed strict local code-sign validation and was installed in
place on the paired physical iPad A16 (`iPad ni Paj`) as
`com.personal.SophiaScriptura`. CoreDevice launched the app successfully. No uninstall
or data reset was performed. Build, install and launch logs are in `build/sp020/device/`;
`build/sp020-activity-install-r2.xcresult` records 6 passing focused Activity tests on
the iPad simulator. The [physical Activity walkthrough](../testing/sp020-ipad-guide.md)
remains for the owner; installation and launch do not prove timer, layout, Files or
background behavior on the device.

Current product slice: M4/SP-013 Notes alongside the M2 reader and M3 annotations,
with SP-006 retained as a DEBUG Notes experiment; current verification uses Xcode 27.0. No server or App Store
deployment.

## App version numbers

Settings shows **Version** from the app bundle. Before each sideload release, bump both values on the **SophiaScriptura** target:

| Setting | Xcode UI | `project.pbxproj` key | Shown in app as |
| --- | --- | --- | --- |
| Marketing version | General → Identity → **Version** | `MARKETING_VERSION` | `CFBundleShortVersionString` (current: `0.2.0`) |
| Build number | General → Identity → **Build** | `CURRENT_PROJECT_VERSION` | `CFBundleVersion` (current: `2`) |

Canonical file: `application/SophiaScriptura/SophiaScriptura.xcodeproj/project.pbxproj` (Debug and Release both list the same keys). Runtime reader: `AppShell/AppVersion.swift`. In-app **Settings → About** shows version, developer, GPL v3, and third-party notices. Bundled license files live under `SophiaScriptura/Resources/Legal/`; the repository root `LICENSE` matches the app’s GPL v3 terms.

1. Open `application/SophiaScriptura/SophiaScriptura.xcodeproj` in Xcode.
2. Press Command-1, select the blue project icon, then **TARGETS → SophiaScriptura**.
3. In **Signing & Capabilities**, enable **Automatically manage signing** and select
   the owner's **Personal Team**. If missing, add the Apple Account in Xcode Settings
   → Accounts. The owner performs sign-in; never put credentials in this repository.
4. Connect and unlock the iPad, accept its Trust prompt if shown, and select it as the
   run destination beside the SophiaScriptura scheme. Enable Developer Mode if Xcode
   requests it; follow the on-device restart/confirmation instructions.
5. Press Command-R. Resolve any signing error shown by Xcode before proceeding. If the
   bundle identifier is unavailable, choose a unique personal identifier in this target.
6. If launch reports that the developer profile is not trusted, open iPad Settings →
   General → VPN & Device Management → Developer App, select your own profile and trust
   it. Then open SophiaScriptura.
7. On iPad, open Notes → Open canvas experiment and follow the
   [walkthrough](../testing/sp006-ipad-guide.md).

Personal Team signing is temporary; use Xcode to rebuild/redeploy when it expires.
Reinstall over the existing app rather than deleting it to preserve local data. This
experiment has no production backup; use synthetic content only.

## SP-019 Quiz Me cache update — 2026-10-02

The signed Debug build passed strict local signature
verification, installed in place on the paired physical iPad A16 (`iPad ni Paj`), and
launched as `com.personal.SophiaScriptura` on 2026-10-02. No uninstall or data reset was
performed. Installation and launch verify delivery; real-provider generation speed,
question quality, and refill behavior require owner observation in Quiz Me.

### Two-quiz refill follow-up — 2026-10-03

The signed Debug build for `com.personal.SophiaScriptura` passed strict local
`codesign --verify --deep --strict`, installed in place on the paired physical
`iPad ni Paj` (iPad A16), and launched through CoreDevice. No uninstall, data
reset or translation sync was performed. The focused simulator suite is recorded
in `build/sp019-two-quiz-cache-final-r3.xcresult` (26 passed). Installation and
launch do not establish real-provider refill speed, question quality or physical
quiz interaction acceptance.

## SP-015 Notes and Collections minimal-header refinement — 2026-10-02

The current Notes and Collections minimal-header build passed strict signature validation,
installed in place on the paired iPad A16, and launched normally as
`com.personal.SophiaScriptura`. No uninstall or data reset was performed. Build, signature,
install and launch evidence is retained under `build/sp015/library-toolbar-device/`.
Installation proves deployment only; review the preset-font titles and expandable search
across portrait/landscape, light/dark appearance, Dynamic Type, and VoiceOver on the device.

## Scripture, Collections and Notes UI fixes — 2026-10-02

The owner-requested UI-fix build passed a signed generic iOS build and strict signature
verification, installed in place on the paired physical iPad A16 named `iPad ni Paj`, and
launched normally as `com.personal.SophiaScriptura`. No uninstall, data reset or translation
sync was performed. Evidence is under `build/ui-bugfix-device/`: `build.log`,
`signature.log`, `install.log` and `launch.log`. Installation verifies deployment; the
long-book truncation, collection title/context actions and note tints still require the
owner's visual and touch review on the iPad.

For terminal verification, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
per command: this Mac currently defaults to Command Line Tools. Simulator builds use
`CODE_SIGNING_ALLOWED=NO`; this does not produce an installable physical-device app.
See the [test commands](../testing/test-specification.md).

References: [Apple device run guide](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html),
[Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device),
[Apple developer account capabilities](https://developer.apple.com/help/account/basics/about-your-developer-account).

2026-09-15: physical build and install succeeded on the owner’s iPad A16 (iPadOS
26.6.2); Developer Mode is enabled. First launch was denied by iPadOS with a
signature/entitlements/profile-trust message. The owner subsequently reported opening and testing the canvas; the earlier launch blocker no longer prevents that reported test.

## M2 reader build

The signed SP-009 build uses the existing Personal Team and bundle identifier. A missing
profile was resolved with Xcode’s `-allowProvisioningUpdates`; no credentials were changed
or copied into the repository. The final generic iOS build succeeded. Follow the
[reader walkthrough](../testing/sp009-reader-evidence.md#physical-walkthrough) for physical
airplane-mode, selection and accessibility acceptance. Build/install success alone does
not prove those cases.

The signed M2 app was installed over the existing app on the paired iPad A16. Launch via
CoreDevice was blocked by the device lock. Unlock and open Sophia to perform physical checks.
No existing app data was deleted.

2026-09-22 passage-picker revision: signed build and installation succeeded
(`build/sp009/picker-device-build.log`, `picker-install.log`). Launch was denied because
the iPad is locked (`picker-launch.log`). Unlock and open Sophia; no deletion/reinstall
is required. See the reader evidence page for the new navigation walkthrough.

## SP-010 licensed translations on the iPad

After installing the signed build, open Scripture → Version → Versions. Enter the owner’s
API.Bible key in the secure field and choose **Download / sync all three**. Keep Sophia in
the foreground with network connectivity until all 1,189 chapters per edition finish.
The key and content-encryption key are device-only, so a Mac-side cache cannot be copied
to this iPad. A successful sync displays each edition's expiry; Release/Archive builds
lock it after 30 days without a renewed authenticated sync. Debug development builds use
the written API.Bible exception for NIV11, NLT and NKJV and retain encrypted local copies
across application rebuilds. Reinstall over the existing app to preserve the encrypted
store and Keychain entries.

2026-09-23: the signed SP-010 update installed over the existing app on the paired iPad
without deleting local data. CoreDevice launch was denied because the iPad was locked.
Unlock it, open Sophia, then use the Versions instructions above to begin the downloads.

2026-09-28: CoreDevice launched the installed build on the unlocked paired iPad. A
transient DEBUG process environment supplied the existing credential to Sophia, which
stored it in the device-only Keychain and ran the normal in-app sync. Device diagnostics
confirmed NIV11, NLT and NKJV each completed all 1,189 chapters. The app was then
terminated and relaunched normally without the transient environment. No secret or
licensed payload was added to the repository or diagnostic files. Airplane-mode reading
and expiry/renewal behavior still require physical observation.

2026-09-29 manual-sync correction: the next signed build removes all launch/resume sync
behavior. Version status is refreshed locally, and API.Bible is contacted only after the
owner presses a per-edition Sync button or **Sync all three now**. The Versions screen
states that syncing is manual. Sophia displays NIV11 as NIV; the provider ID and encrypted
content remain unchanged, so installation does not require another Bible download.

The correction build was signed, verified and installed over the existing app; the
data-container identity was retained. CoreDevice launch was denied by iPadOS because the
Personal Team developer profile was not explicitly trusted after installation. Developer
Mode remains enabled and the device remains paired. On the iPad, open Settings → General
→ VPN & Device Management, trust the owner's developer profile, then open Sophia. This
trust step does not require another translation sync or download.

## OldPaper UI refinement — 2026-09-29

The signed SP-009 UI update built successfully, installed over the existing app and
launched on the connected iPad A16. Evidence: `build/oldpaper/device-build.log`,
`install.log`, and `launch.log`. Settings → Appearance presets offers all seven selected
styles. No app deletion or licensed-content store migration was performed. Launch success
is not physical visual, VoiceOver, or airplane-mode acceptance.

## SP-008 validation build — 2026-09-29

M2 is closed under revised owner acceptance. SP-008 is the first M3 validation ticket;
the Debug build exposes Settings → Experiments → SP-008 Pencil validation. Follow the
[physical Pencil walkthrough](../testing/sp008-ipad-guide.md). Install over the existing
app; no licensed translation download is required. Experiment saves contain disposable
ink only and do not establish production annotation durability.

## SP-011 tab-shell update — 2026-09-29

The signed update built, passed local code-sign verification, installed over the existing
app and launched on the paired physical iPad. No app deletion or translation sync was
performed. Evidence: `build/sp011/device-final-build.log`, `device-final-install.log`,
`device-launch.log`. Review five-second dock hiding, scroll/manual reveal and tab slide/glow
on the device; Reduce Motion should fade content and selection. See
[SP-011](../../tickets/SP-011-tab-shell-motion.md) for automated evidence and pending review.

SP-011 footer fix: the physical UI test installed the signed fix over the existing app
and passed Settings final-row visibility/opening in portrait and landscape
(`build/sp011/footer/ipad-r6.xcresult`). Afterward, local signature verification passed
and Sophia relaunched normally with the test environment cleared
(`build/sp011/footer/normal-launch.log`). No app deletion or translation sync occurred.

## SP-013 M4 closure build — 2026-10-01

The final M4 Debug build passed strict signature verification, installed in place on the
paired iPad A16 and launched `com.personal.SophiaScriptura` normally. Evidence is retained
under `build/sp013/m4-final/`: `final-device-build.log`, `final-signature.log`,
`final-install.log` and `final-launch.log`. The install preserved the existing app data;
no uninstall, migration, reset or translation sync occurred.

## SP-012 actual-reader annotation update — 2026-09-29

Signed physical-device tests install in place and use a UUID-isolated reader/annotation
store. Both layer-management and font reading-view journeys passed in `build/sp012/ipad-r1.xcresult`.
After testing, launch normally with CoreDevice `--terminate-existing` to clear test process
environment; this does not delete the app or its data. Final signing/build/install/launch
logs are under `build/sp012/`. Existing licensed downloads and Keychain state are retained.

Open Scripture → Annotations → New layer; this is separate from the SP-008 Settings
experiment. Follow the [actual annotation walkthrough](../testing/sp012-ipad-guide.md).
Use test handwriting until the owner completes the Files backup/restore drill. Annotation
backups contain only ink, identities and layout metadata; full-app backup remains future work.

SP-012 owner revision: `build/sp012/revision/device-final-build.log` records a successful
signed build. The first in-place install succeeded, but iPadOS denied launch because the
Personal Team profile was not yet trusted. The owner then accidentally deleted the app;
`device-reinstall.log` and `reinstall-launch.log` record a successful fresh install and
normal launch. App deletion may have removed earlier local data, including annotations,
reader state and licensed downloads. Installation and launch do not establish whether
those data survived or whether the revised Pencil workflow passes physical acceptance.

Latest SP-012 layer-appearance revision: signed build and in-place install succeeded
(`build/sp012/revision/layer-device-build.log`, `layer-device-install.log`). The first
normal launch was denied pending Personal Team profile trust. After the owner trusted
the profile and opened Sophia, the CoreDevice retry launched successfully
(`layer-device-launch-retry.log`). The in-place install did not delete the app; physical
Pencil and annotation-backup acceptance remain separate checks.

The selected-layer color refinement also built, installed in place, and launched on
the paired iPad (`build/sp012/revision/layer-color-device-build.log`,
`layer-color-device-install.log`, `layer-color-device-launch.log`). This verifies
deployment, while the owner's physical visual and Pencil checks remain open.

The SP-012 hidden-reader responsiveness, layer-action and exact eye-icon revision
also built, installed in place and launched on the paired iPad. Final evidence:
`build/sp012/revision/hollow-eye-device-build.log`, `hollow-eye-device-install.log`
and `hollow-eye-device-launch.log`. This is deployment evidence, not completion of
the physical Pencil and Files recovery walkthrough.

## SP-013 M4 Notes test build — 2026-09-29

The signed Debug build succeeded for the paired iPad A16 and retained
`com.personal.SophiaScriptura`. It installed in place and launched normally through
CoreDevice. Evidence: `build/sp013/device-build.log`, `device-install.log`, and
`device-launch.log`. No app deletion or Notes data migration was performed. Open
Notes and follow the [M4 iPad walkthrough](../testing/sp013-ipad-guide.md) for Pencil,
Files recovery, VoiceOver, orientation and realistic-capacity checks. Installation
and launch alone do not establish physical feature acceptance.

### SP-013 study-page revision — 2026-09-30

The final signed Debug build succeeded (`build/sp013/redesign/device-final-build.log`)
and installed over the existing app on the paired iPad, followed by a successful launch.
Evidence: `build/sp013/redesign/device-install.log` and `device-launch.log`. No uninstall
was performed. On first save, Notes retains the original v1 generation before writing
the study-page format. Follow the revised [iPad guide](../testing/sp013-ipad-guide.md).

## Canvas and Page Notes — 2026-10-01

The signed SP-013 Canvas/Page build was installed over `com.personal.SophiaScriptura`
on the paired iPad A16 and launched successfully through CoreDevice. No uninstall, data
reset or translation sync was performed. Build evidence is
`build/sp013/two-types/device-handoff.log`; installation and launch are recorded in
`install.log` and `launch.log` beside it. Signature verification passed with normal Mac
certificate access (the sandboxed check could not establish certificate trust).

Open Notes → New Note → Canvas or Page. Follow the
[updated iPad acceptance guide](../testing/sp013-ipad-guide.md), especially Pencil with
Scribble on/off and typing-to-annotation transitions. Use Hide Pencil tools when the native
palette covers the bottom tab controls. Schema v3 retains legacy types and preserves the
exact prior generation before the first upgraded save. Installation/launch does not prove
physical Pencil routing, palm rejection, Files recovery or resolution of the old crash.


### Canvas/Page workspace refinement — 2026-10-01

Final signed build and strict signature verification passed. CoreDevice installed the
update in place on the paired iPad A16 and launched `com.personal.SophiaScriptura`. No
uninstall, data reset or translation sync occurred. Evidence under
`build/sp013/ux-refinement/`: `device-release.log`, `signature.log`, `install.log`,
`launch.log`. All 33 distinct Notes checks passed across regression/focused result bundles;
see SP-013 for the initial failures, corrections and remaining physical acceptance.


### Ink appearance and full-height theme correction — 2026-10-01

The follow-up signed build passed strict signature verification, installed in place on the
paired iPad A16 and launched normally. Evidence: `build/sp013/theme-edge/device.log`,
`signature.log`, `install.log`, `launch.log`. Existing app storage was retained, with no
uninstall, reset or translation sync. Thirty-five distinct selected checks passed across
`verification.xcresult` and the successful focused `cycles.xcresult`; SP-013 records the
initial failures and corrections. Follow the new theme/screen-edge section in the
[iPad guide](../testing/sp013-ipad-guide.md). Physical acceptance remains pending.


### Canvas ink memory correction and active pen indicator — 2026-10-01

The final signed app was installed in place by the physical Notes regression and passed
strict signature verification. The twenty-stroke/save/reopen iPad test passed in
`build/sp013/ink-stability/ipad-persistence.xcresult`. CoreDevice then launched normally
without test-store variables (`normal-launch.log`); owner storage remains intact. The
SP-013 ticket records 29 distinct passing checks, the ~210 MB diagnostic memory peak,
initial test/trust failures and the remaining physical Pencil acceptance.

### Page viewport recursion correction — 2026-10-01

The corrected app passed strict signature verification and was installed in place on the
paired iPad A16. Page ink theme-cycle and save/reopen tests passed on that device before
installation (`build/sp013/page-crash/ipad-page.xcresult`). CoreDevice then launched the
normal app (`launch.log`); no reset, uninstall, or translation sync occurred.

### Verse Hub actions and collection icons — 2026-10-02

The final signed Debug build passed strict signature verification and installed in place on
the paired iPad A16 without an uninstall or data reset. The app's existing data-container
identity was preserved. Evidence is in `build/verse-hub-device-final-build.log`,
`build/verse-hub-device-final-signature.log`, and
`build/verse-hub-device-final-install.log`. CoreDevice could not perform the final automated
launch because the iPad was locked (`build/verse-hub-device-final-launch.log`); unlock the
device and open Sophia Scriptura to complete the physical visual and interaction review.
The simulator regression evidence is `build/verse-hub-regression.xcresult` (27 passing
collection and reader checks), followed by `build/verse-hub-unit-final.xcresult` (14 passing
focused collection checks) after the final compatibility adjustment.
