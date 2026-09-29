# Integration map

No provider client is implemented. Read `docs/tdd/tdd.md` §8 and
`tickets/SP-002-free-scripture-access.md` for content-provider candidates and permissions.
SP-002's dated findings are in `docs/integrations/scripture-content.md`: WEBP USFM baseline,
conditional licensed editions, import checks and unverified account-specific grants.
`application/SophiaScriptura/SophiaScriptura/Core/ModuleBoundaries.swift` contains boundary
placeholders. `shared/prompt-presets.seed.json` has an approved shared foundation and Biblical Studies/
Christian Living wording; Apologetics/Tough Questions wording is also owner-approved. No runtime consumption
or behavioral evaluation exists. Read shared/README.md for composition requirements.

Preferred translation names do not prove access, licensing, offline rights, or completed
integration. Future provider tickets must establish exact contracts and tests before code.
