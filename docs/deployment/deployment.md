# Personal iPad deployment

Current product slice: SP-009/SP-010 / M2 reader, with SP-006 retained as a Notes experiment; Xcode 26.6. No server or App Store deployment.

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
