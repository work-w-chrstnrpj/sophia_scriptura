# Integration map

Source review: 2026-10-18. There is no runtime backend; provider clients run on-device.
Paths below are relative to `application/SophiaScriptura/SophiaScriptura/`.

- `Infrastructure/Scripture/MultiSourceTranslationLibrary.swift` coordinates bundled
  WEBP, API.Bible (`OfflineTranslationLibrary`, `APIBibleClient`) and Hello AO
  (`Infrastructure/Scripture/HelloAO/`). `Core/Scripture/TranslationSourceContracts.swift` and
  `ScriptureReferenceIdentity.swift` own source-neutral identity/operation policy.
- `Core/Scripture/LicensedTranslations.swift` lists NASB/NLT/NKJV and Debug versus
  standard lease policy. Source presence does not establish authenticated access or rights.
- `Infrastructure/Scripture/HelloAOChapterNarrationClient.swift` and narration media/
  engine adapters support SP-039; ESV text/audio under SP-032 remains a draft.
- `Infrastructure/Companion/ProviderRegistry.swift` registers OpenAI, Anthropic, Gemini,
  OpenRouter, GitHub Models, NVIDIA, Cerebras, Groq, Mistral, Hugging Face and separate
  China/International Qwen adapters. These are source capabilities, not proof of live
  model/account availability. Keys use `CompanionCredentialsStore` and device Keychain.
- `PromptPresetCatalog.swift` loads `Resources/Companion/prompt-presets.seed.json`,
  resolves the shared guardrail and snapshots instructions. `CompanionContextBuilder.swift`
  composes bounded saved history and explicit authorized attachments on requests.
- `CompanionStudySources.swift` owns local reference links/lookup and provenance;
  adapters advertise retrieval capabilities. Generated citations do not prove retrieval.
- `AIQuizQuestionGenerator.swift` and `QuizQuestionCacheCoordinator.swift` own provider
  question generation/coalescing; feature cache orchestration lives in CompanionQuizCache.

Intent/contracts: `docs/tdd/tdd.md` §§8/12, `docs/data/companion-contract.md`,
`docs/data/scripture-reader-contract.md`, `docs/integrations/scripture-content.md`.
SP-002's rights evidence remains dated. Preferred translation names and registered AI
adapters do not prove licensing, credentials, offline rights or provider-quality acceptance.
SP-041 MCP bridge is planning only; no external bridge server is implemented.
