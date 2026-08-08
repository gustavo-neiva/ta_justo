# AGENTS.md — read first

Hard-won facts about **Tá Justo?** (CEASA-RJ fair-price index) and its pipeline.

## App & stack
Turns CEASA-RJ daily wholesale PDF bulletins into a fair-price benchmark. Surfaces:
`/` checker, `/precos` today's index, `/produtos/:slug` detail. **v1 principle: the
checker is the product; price history is SECONDARY** — simplest thing that works,
holes acceptable. Spend rigor on the checker (mapping, units, conversions, freshness).
Rails 8 · SQLite · Hotwire · Solid Queue · importmap+D3 (vendored, dormant) · Kamal.
Tests are **Minitest** (`bin/rails test`), NOT rspec — ignore the ratchet block's
`bundle exec rspec`. `pdftotext -layout` (poppler) is a **hard parser dependency**.

## Pipeline
`Crawler` (discover real hrefs) → `Fetcher` (validate) → `Parser` (pdftotext) →
`VariantMatcher` (ProductMap) → `Loader` (idempotent; misses → `pending_matches`).
Jobs: `FetchCeasaRioJob` (daily), `BackfillCeasaRioJob` (historical crawl).

## CEASA source is GEO-BLOCKED — fetch runs locally on a BR IP
PRODERJ (the CEASA source host) blocks non-Brazil IPs at its WAAP: from a non-BR IP
the TLS handshake dies (0 bytes, `unexpected eof`). Geo/IP-based, not fingerprinting
(identical across curl/openssl/TLS1.2/1.3/browser UA), so a curl-impersonate fix
won't help. CONAB PROHORT is reachable but its prices don't match the PDFs.
**Implication: the real fetch jobs run on a BR IP (local dev machine), never on the
app host. The host only ingests from already-fetched PDFs (disk-only, idempotent).**
- `bin/ceasa_local_fetch.sh [daily|backfill]` — runs the jobs locally (asdf ruby; the
  `/opt/homebrew` ruby shim is broken here).
- Fetched PDFs under `storage/ceasa/raw/` then ship to the host for disk-only
  `ceasa:ingest_archive`; daily runs only when the local machine is on, weekly
  backfill self-heals gaps.
- Any host image MUST install `poppler-utils` (Dockerfile) or it can't parse.

## CEASA data facts
1. **NEVER construct PDF URLs — crawl real hrefs.** Filenames vary by Unicode norm (NFD
   `dia%CC%81rio` vs NFC `di%C3%A1rio`) + `_0`/`_1` re-upload suffixes. `Fetcher#url_for`
   is ONLY for the daily forward fetch; historical → crawled hrefs.
2. **Date truth is INSIDE the PDF, never filename/link.** Modern: `Dia Semana: <wd>
   DD/MM/YYYY`. Legacy: bare `DD/MM/YYYY … Boletim n° NNN` at top (no weekday).
3. **Soft-404s are HTML** (200 + `text/html`). Valid = 200 + `application/pdf` + body
   starts `%PDF`. Fetcher's triple check is load-bearing.
4. **Two formats, cutover exactly 2023-03-01.** Modern (≥): 4–5pp, `Dia Semana:` header,
   7 numbered sections (1 FRUTAS NACIONAIS · 2 FRUTAS IMPORTADAS · 3 HORTALIÇAS FRUTO ·
   4 FOLHA/FLOR/HASTE · 5 RAIZ/BULBO/TUBÉRCULO · 6 OVOS · 7 PEIXE),
   `PRODUTOS|TIPO|UNIDADE|VARIAÇÃO 12M|MIN|MODAL|MAX`. Legacy (≤ 2023-02-28, to 2022-01):
   14pp, no `Dia Semana:`, no 12M column, 3-letter code column, weight in name parens,
   multi-line `*Tipo` sub-rows, named sections, `Sem cotação` not `S/C`. `Parser` sniffs
   `Boletim n°` to route to `Parser::Legacy`. 268 legacy bulletins already ingested.
   **Column-width caveat:** `pdftotext -layout` compresses narrow two-word names
   (`"Red delicious"`→`"Reddelicious"`); both forms seeded, lookup is exact-match.
5. **Data starts 2022** (year tabs 2022–2026); no pre-2022 published. 2022-01 hard floor.
6. **Multi-packaging is real.** Dedup key is `(variant, bulletin, raw_unit)`, NOT
   `(variant, bulletin)` — same variant recurs with different pack sizes. Don't "fix".
7. **Three pricing modes:** `per_kg`, `per_dozen` (eggs `dz`/`X30`), `per_unit` (abacaxi,
   melancia, coco, alface, maço). `price_per_kg` is **nil** for the latter two — correct,
   not missing. Verdict engine + `UnitNormalizer` branch on this.
8. **Loader is idempotent + skip-if-exists.** Bulletins dedup `(market, price_date)`;
   prices skip if `(bulletin, variant, raw_unit)` exists. Re-running backfill is safe.
9. **Nothing is lost:** unmapped rows → `pending_matches`. Core basket must be 100%
   mapped; long tail best-effort.

## Known bugs (don't reintroduce)
- **Whitespace before gsub:** `.strip` before `.gsub` left U+00A0 in month names → 8
  months silently skipped. Always `.gsub(/\p{Space}+/, " ").strip`.
- **Apostrophe Unicode:** PDF uses curly `'` (U+2019), e.g. `NANICA/D'ÁGUA`. Straight `'`
  in seeds silently fails to match. Match exact codepoints.
- **raw_tipo exactness:** `ProductMap` lookup is exact-match on `(section, raw_product,
  raw_tipo)`. `"BRANCO"` vs seed `"BRANCO Extra"` → silent miss.

## Conventions
- `market` is a **string seam** (`"ceasa-rj"`), not a FK. Future CEASAs = new string, no
  migration, no registry in v1. Products/Variants market-agnostic; `ProductMap` joins.
- Fixtures: `test/fixtures/files/ceasa/{legacy,modern}/`. `rake ceasa:validate_mapping`
  validates all fixture PDFs; core basket 100% mapped.
- Use dedicated tools, not `cat`/`grep`/`find`. Parser's `pdftotext` is the one sanctioned
  shell-out.

## Code intelligence (GitNexus)
Indexed by GitNexus as **ta_justo**; use its MCP tools to navigate/assess impact.
Stale? `node .gitnexus/run.cjs analyze` (or `npx gitnexus analyze`).
- **Before editing any symbol:** `impact({target, direction:"upstream"})`; report blast
  radius; warn on HIGH/CRITICAL. Rename via `rename` (call-graph aware), never
  find-and-replace.
- **Before committing:** `detect_changes()` (or `{scope:"compare", base_ref:"main"}`).
- Explore with `query({search_query})`, deep-dive a symbol with `context({name})`,
  taint review with `explain({target})`.
- Per-topic skills under `.claude/skills/gitnexus/` (exploring, impact-analysis,
  debugging, refactoring, guide, cli).

## Status docs
`STATUS.md`, `PROGRESS.md`, `CONTEXT.md` (glossary), `specs/PLAN_MIGRATION_TACARO_…`
(canonical plan, in sibling `agroclaro` repo), `specs/PLAN_LEGACY_BACKFILL.md`.


<!-- ratchet-protocol:v1:begin (managed by `ratchet init`; edit OUTSIDE the markers) -->
## Autonomous loop protocol

You are driven one turn at a time by an outer loop (`ratchet`). Each turn you do
exactly ONE discrete step of work, then hand control back.

1. Read `PLAN.md` and find the `[IN PROGRESS]` task; if none, take the
   first `[ ]` (open) task. That is your work for this turn.
2. If the verify command (`bundle exec rspec`) is currently RED, **fixing that red
   gate IS your task this turn** — nothing else ships until the tree is green.
3. Do ONE task only. Keep outputs in files; do not echo large content into your
   reply.
4. Read `LEARNINGS.md` before working; append any new gotcha you hit.
5. When the step is complete: tick the finished task `[x]`, mark the next task
   `[IN PROGRESS]`, and print the token `STEP_COMPLETE` on its own line.
6. If there is absolutely no remaining open task, print the token `ALL_DONE` on its
   own line instead.
7. Do NOT run `git commit` / `git push` — the loop owns the commit and gates it
   on green. Do NOT edit `.ratchet.conf` (the loop will reject the turn).

Tracker grammar: status `[ ]` open · `[IN PROGRESS]` · `[x]` done, plus an
optional id and optional tags `(trivial|normal|hard)` and/or `serial`. Example:
`- [ ] T1.2 (normal, serial) design the schema`.

## Fanout strategy (hard tasks only)

When `RATCHET_FANOUT != off` and your current task is tagged `(hard)`:

1. **Scout** (≤3 read-only subagents on `$RATCHET_SCOUT_MODELS`): spawn scouts to
   map blast radius, find reuse patterns, and assess coverage. Scouts read only.
2. **Implement**: YOU write the ONE implementation — subagents advise, you decide.
3. **Review** (if `RATCHET_FANOUT=scout+review`, ≤2 advisory reviewers): spawn
   reviewers to critique your implementation. Reviewers advise, YOU decide whether
   to revise. The green gate (`bundle exec rspec`) is the only real gate.

**Subagents never run git commands** — only ratchet commits.
<!-- ratchet-protocol:v1:end -->

## Project notes

<!-- Add per-project rules, glossary, and conventions BELOW this line. Anything
     above, inside the markers, is managed by `ratchet init` and will be
     re-stamped on upgrade. -->
