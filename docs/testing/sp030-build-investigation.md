# SP-030 build investigation — 2026-10-10

## Summary and symptoms

Owner reported latest changes could not build. Scope: reproduce and correct confirmed build/package blockers, preserving incoming SP-029/SP-030 changes. No deployment, migration or release.

## Facts and observations

A fresh full-scheme generic iOS Simulator Debug build succeeded before source changes. A signed generic iOS build failed because the new `com.personal.SophiaScriptura.StudyActivityWidget` extension had no development provisioning profile. Retrying with `-allowProvisioningUpdates` reported **No Accounts: Add a new account in Accounts settings**. Current command-line environment cannot generate the new profile.

Inspection of built bundles also found missing app UIBackgroundModes and missing extension NSExtension. Flat/generated build-setting names did not produce the required array/nested dictionary. These packaging defects can survive compilation and block valid runtime/installation behavior.

## Suspected failing boundary and primary investigator

DevOps/build configuration and signing, with packaging verification. Investigation performed in the current task; no separate agents used. Supporting areas: native extension integration and SQA.

## Hypotheses and evidence

- Swift compile regression: not reproduced; fresh full-scheme simulator compilation succeeded.
- Missing extension profile: confirmed by device-baseline.log.
- Xcode account unavailable for provisioning: confirmed by device-fixed.log even with provisioning updates enabled. This establishes the current build environment, not whether the owner has an Apple ID elsewhere.
- Missing generated plist entries: confirmed by reading built app/extension Info.plist files, not inferred from project settings.

## Most likely root cause and confidence

High confidence for reproduced device-build failure: the newly added extension requires its own signing profile, and Xcode currently has no available account to create one. Separate high-confidence packaging defects are fixed below. The owner's exact original error was not provided, so do not assert every observed failure had the same cause.

## Corrections

- `application/SophiaScriptura/AppInfoSupplement.plist`: explicit UIBackgroundModes array containing audio.
- `application/SophiaScriptura/StudyActivityWidgetInfo.plist`: explicit nested NSExtension dictionary with com.apple.widgetkit-extension.
- `application/SophiaScriptura/SophiaScriptura.xcodeproj/project.pbxproj`: use extension plist in Debug/Release; remove ineffective flat extension/audio generated settings.

No Swift behavior, bundle identity, team or on-disk study schema was changed. Docs include signing remediation; no automated tests added because the change is plist/build configuration and is verified against actual compiled packages.

## Verification evidence

Logs under ignored `build/build-repair-20261010/`:
- baseline.log: fresh simulator build passed.
- device-baseline.log: missing extension profile; failed.
- device-fixed.log: provisioning retry failed with No Accounts/missing extension profile.
- simulator-fixed.log: corrected full app+extension simulator Debug build passed.
- Built package assertions passed: audio array, Live Activities flag, nested extension point and extension identifier under parent app identifier.
- device-unsigned.log: unsigned generic iOS Debug app+extension build passed. Device package plist assertions also passed. This unsigned artifact is not installable evidence.

Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project application/SophiaScriptura/SophiaScriptura.xcodeproj -scheme SophiaScriptura`, generic iOS Simulator or iOS destination, separate DerivedData under the evidence directory. Unsigned checks use CODE_SIGNING_ALLOWED=NO; signing retry uses -allowProvisioningUpdates. No credentials logged.

## Recommended fixes, open questions and status

Owner must sign into Xcode Settings → Accounts using the existing Apple ID, ensure both targets select the existing Personal Team and Automatic Signing, then retry the normal signed build with provisioning updates. Do not use another account/team, change bundle IDs, delete the extension or uninstall Sophia to bypass the failure. Account setup cannot be completed by editing application source.

Physical signing/install and actual Home/Lock Screen acceptance remain unverified. Status: source/package correction verified on simulator and unsigned iOS build; signed device build blocked by unavailable Xcode account/profile. Full SP-030 acceptance remains independent.

## RCA needed?

No formal RCA requested or needed for this local build repair; retained logs and remediation instructions suffice.
