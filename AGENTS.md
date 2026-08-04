# AGENTS.md — Working notes for any agent in this repo

Read this first. It captures hard-won facts about **Tá Justo?** (CEASA-RJ fair-price
index) and the CEASA data pipeline so you don't rediscover them the hard way.

---

## What this app is

Turns CEASA-RJ's daily wholesale PDF bulletins into a consumer fair-price benchmark.
Three surfaces: `/` checker (hero), `/precos` today's index, `/produtos/:slug` detail.
**v1 priority principle:** the checker (today's verdict) is the product. **Price
history is SECONDARY** — pick the simplest thing that works; holes in history are
acceptable; "looks populated" is good enough. Spend rigor on the checker (mapping,
units, conversions, freshness), not on history integrity.

## Stack
Rails 8 · SQLite · Hotwire · Solid Queue · importmap + D3 (vendored, dormant) · Kamal.
`pdftotext -layout` (poppler) is a **hard dependency** of the parser — it shells out.

## The CEASA pipeline (data flow)
`Crawler` (discover real PDF hrefs) → `Fetcher` (validate) → `Parser` (pdftotext →
structs) → `VariantMatcher` (ProductMap lookup) → `Loader` (idempotent insert; misses →
`pending_matches`). Jobs: `FetchCeasaRioJob` (daily forward), `BackfillCeasaRioJob`
(historical crawl).

## The Hetzner server is GEO-BLOCKED from CEASA — fetch runs locally

**PRODERJ (the RJ-state datacenter hosting `www.rj.gov.br`, single A record
`187.62.128.44`) blocks non-Brazilian source IPs at its WAAP.** The Hetzner box
(Nürnberg) writes its TLS ClientHello and reads **0 bytes back** — the connection
is killed mid-handshake (`unexpected eof while reading`). Confirmed identical across
`curl`/`openssl`/TLS1.2/TLS1.3/browser-UA, so it is **geo/IP-based, not TLS
fingerprinting** — a server-side `curl-impersonate` fix will NOT help. Federal
`gov.br` / `serpro.gov.br` work from the server; only RJ-state infra blocks.
CONAB PROHORT (`pentahoportaldeinformacoes.conab.gov.br`) is reachable from the
server but its prices do NOT match the PDF bulletins — not a usable source.

**The fix: run the real jobs on a machine with a Brazilian IP (the dev Mac), then
ship PDFs to the server for disk-only ingest.** The Mac has the three things the
server lacks: BR egress, poppler, and the full app.
- `bin/ceasa_local_fetch.sh [daily|backfill]` — runs `FetchCeasaRioJob` /
  `BackfillCeasaRioJob` locally (uses asdf ruby; the `/opt/homebrew` ruby shim is
  broken on this machine).
- `bin/ceasa_sync_hetzner.sh` — `rsync` `storage/ceasa/raw/` → server Docker volume
  `ta_justo_storage` at `/rails/storage/ceasa/raw`, then `docker exec … bin/rails
  ceasa:ingest_archive` (disk-only, idempotent — archive-first invariant preserved).
- **Deploy dependency:** the parser shells out to `pdftotext`, so the image MUST
  install `poppler-utils` (Dockerfile base packages). Without it the server can
  fetch/archive but never parse. Redeploy also picks up the `ceasa:ingest_archive`
  rake task.
- Daily runs only when the Mac is on; the weekly incremental backfill self-heals
  gaps (history is secondary — see v1 principle).

---

## CEASA data — facts you must respect

1. **NEVER construct PDF URLs. Crawl the real hrefs.** Filenames are chaotic: the same
   date appears under different Unicode normalizations — NFD `Boletim%20dia%CC%81rio…`
   (combining accents) vs NFC `Boletim%20di%C3%A1rio…`, plus `_0`/`_1` re-upload
   suffixes. `Fetcher#url_for` exists only for the daily *forward* fetch of the current
   era; for anything historical, use crawled hrefs.

2. **Date truth lives INSIDE the PDF, never in the filename or the link.** Modern:
   `Dia Semana: <weekday> DD/MM/YYYY`. Legacy: a bare `DD/MM/YYYY ... Boletim n° NNN`
   at top of page (no weekday).

3. **Soft-404s are HTML.** A missing date returns 200 + `text/html`, not 404. Valid =
   200 + `content-type application/pdf` + body starts with `%PDF`. The Fetcher's triple
   check is load-bearing — keep it.

4. **Two PDF formats. The cutover is exactly 2023-03-01.**
   - **Modern** (≥ 2023-03-01): 4–5 pages, `Dia Semana:` header, 7 numbered sections,
     `PRODUTOS|TIPO|UNIDADE EMBALAGEM|VARIAÇÃO 12M|MIN|MODAL|MAX`. This is what the
     current `Parser` reads.
     Sections: 1 FRUTAS NACIONAIS · 2 FRUTAS IMPORTADAS · 3 HORTALIÇAS FRUTO ·
     4 HORTALIÇAS FOLHA/FLOR/HASTE · 5 HORTALIÇAS RAIZ/BULBO/TUBÉRCULO · 6 OVOS · 7 PEIXE.
   - **Legacy** (≤ 2023-02-28, back to 2022-01): 14 pages, no `Dia Semana:`, **no 12M
     variation column**, a 3-letter product-code column, weight buried in product-name
     parentheses, multi-line `*Tipo` sub-rows, named (not numbered) sections,
     `Sem cotação` instead of `S/C`. `Parser::Legacy` handles these; `Parser` (the
     dispatcher) sniffs `Boletim n°` to route. 268 legacy bulletins (2022-01 to 2023-02)
     are already ingested. **Column-width caveat:** `pdftotext -layout` sometimes
     compresses two-word names in narrow columns (e.g. `"Red delicious"` →
     `"Reddelicious"`, `"Red globe"` → `"Redglobe"`). Both forms are in the legacy seed;
     ProductMap lookup is exact-match so both must be present.

5. **The live site only goes back to 2022.** Year tabs: 2026/2025/2024/2023/2022. There
   is **no pre-2022 data published** (direct-URL probes 404). 2022-01 is the hard ceiling.

6. **Multi-packaging is real.** A variant can appear multiple times in one bulletin with
   different pack sizes (Cx 18kg vs Cx 5kg). Dedup key is `(variant, bulletin, raw_unit)`,
   NOT `(variant, bulletin)`. Don't "fix" this into a uniqueness bug.

7. **Three pricing modes.** `per_kg` (most produce), `per_dozen` (eggs — `dz`/`X30`),
   `per_unit` (abacaxi, melancia, coco, alface, maço). `price_per_kg` is **nil** for
   per-dozen/per-unit; that is correct, not a missing value. The verdict engine and
   `UnitNormalizer` branch on this — don't assume everything is per-kg.

8. **Loader is idempotent + skip-if-exists.** Bulletins dedup on `(market, price_date)`;
   prices skip if `(bulletin, variant, raw_unit)` exists. Re-running a backfill is safe
   and will NOT overwrite existing data — important for the "modern wins over legacy"
   guarantee (and there's no date overlap anyway).

9. **Nothing is ever lost.** Unmapped rows go to `pending_matches` (audit + occurrence
   count). Mapping the long tail is iterative; core basket must be 100% mapped, long
   tail is best-effort.

## Known historical bugs (don't reintroduce)
- **Whitespace before gsub:** `.strip` before `.gsub` left U+00A0 (`&nbsp;`) in month
  names → 8 months silently skipped by the crawler. Always `.gsub(/\p{Space}+/, " ").strip`.
- **Apostrophe Unicode:** PDF uses curly `'` (U+2019), e.g. `BANANA NANICA/D'ÁGUA`. Seed
  data with straight `'` silently fails to match. Match the PDF's exact codepoints.
- **raw_tipo exactness:** `ProductMap` lookup is exact-match on `(section, raw_product,
  raw_tipo)`. PDF emits `"BRANCO"` where a seed expected `"BRANCO Extra"` → silent miss.

## Conventions
- `market` is a **string seam** (default `"ceasa-rj"`), not a FK. Future CEASAs = new
  string, no migration. Keep it cheap; don't build a market registry in v1.
- Products/Variants are market-agnostic; `ProductMap` is the per-market join.
- Sample PDFs live in `test/fixtures/files/ceasa/{legacy,modern}/`. The
  `rake ceasa:validate_mapping` task globs `test/fixtures/files/ceasa/**/*.pdf` and
  validates all 5 fixture PDFs. Core basket is 100% mapped across all fixtures.
- Don't shell out to `cat`/`grep`/`find`; use the dedicated tools. Parser's `pdftotext`
  shell-out is the one sanctioned exception (it's the actual data source).

## Testing note
The suite is **Minitest** (`bin/rails test`), NOT rspec — ignore the ratchet
protocol's `bundle exec rspec` verify command below; it isn't in the bundle.

## Status docs
`STATUS.md`, `PROGRESS.md`, `CONTEXT.md` (glossary), `specs/PLAN_MIGRATION_TACARO_…`
(the canonical build plan, in the sibling `agroclaro` repo), and
`specs/PLAN_LEGACY_BACKFILL.md` (legacy/historical import plan).


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
