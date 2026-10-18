# Deployment map

Read `docs/deployment/deployment.md`. Open
`application/SophiaScriptura/SophiaScriptura.xcodeproj`, scheme SophiaScriptura.
This is a personal iPad installation with owner-managed Personal Team signing,
Developer Mode, and profile trust. No runtime hosting or App Store distribution is configured.
`.github/workflows/release.yml` builds/tests simulator source and publishes versioned
GitHub source releases; signed iPad delivery remains local via `scripts/install-ipad.sh`.
The owner performs Apple Account sign-in and device trust. Keep credentials out of docs.
Test commands use command-scoped DEVELOPER_DIR when the Mac selects Command Line Tools.
