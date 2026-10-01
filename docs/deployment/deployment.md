# Personal iPad deployment

Current product slice: M4/SP-013 Notes alongside the M2 reader and M3 annotations,
with SP-006 retained as a DEBUG Notes experiment; current verification uses Xcode 27.0. No server or App Store
deployment.

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

## SP-015 Notes and Collections minimal-header refinement — 2026-10-02

The current Notes and Collections minimal-header build passed strict signature validation,
installed in place on the paired iPad A16, and launched normally as
`com.personal.SophiaScriptura`. No uninstall or data reset was performed. Build, signature,
install and launch evidence is retained under `build/sp015/library-toolbar-device/`.
Installation proves deployment only; review the preset-font titles and expandable search
across portrait/landscape, light/dark appearance, Dynamic Type, and VoiceOver on the device.

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
