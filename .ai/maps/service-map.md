# Ingestion map

Sophia has no runtime backend. `service/README.md` and `service/ingestion/` describe a
the implemented WEBP USFM importer, independent VPL comparison and tests. Read TDD §8,
SP-002 and `docs/testing/sp009-reader-evidence.md` before changing bundled content. Do not infer bulk/offline permissions from an API's existence.
`shared/usfm-books.json` holds book seed data. No server deployment or service API exists.
