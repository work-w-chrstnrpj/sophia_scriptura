# Service — Content Preparation

No runtime backend. `ingestion/ingest.py` prepares the public-domain WEBP Bible from
publisher archives downloaded separately. It never accesses accounts or provider keys.

```sh
python3 service/ingestion/ingest.py \
  --usfm build/sp009/source/engwebp_usfm.zip \
  --vpl build/sp009/source/engwebp_vpl.zip \
  --output build/sp009/generated
python3 -m unittest discover -s service/ingestion -v
```

Follow the USFM and VPL links on the [publisher listing](https://ebible.org/find/details.php?id=engwebp).
Keep original bytes in ignored build inputs. The importer rejects unsafe archives, unknown
syntax, duplicate/missing/extra books and unexplained independent-format differences.
It preserves structural runs and ancillary source files, creates read-only SQLite content
plus a provenance manifest, and never operates on user databases. Reusing an output directory
replaces only its generated artifact; use `build/`, not a personal-data directory.

See [reader evidence](../docs/testing/sp009-reader-evidence.md) and the
[content policy](../docs/integrations/scripture-content.md). Copy verified artifacts to
`application/SophiaScriptura/SophiaScriptura/Resources/Scripture/` only after comparison,
repeat-build checks and source inspection. Copyrighted provider ingestion is not implemented.
