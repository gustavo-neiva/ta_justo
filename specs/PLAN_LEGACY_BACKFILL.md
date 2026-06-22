# PLAN — Legacy Historical Backfill (CEASA-RJ pre-March 2023)

**Status:** Ready to build · **Created:** 2026-06-21
**Goal:** Absorb as much CEASA-RJ price history as possible from the **legacy-format**
PDFs (2022-01 → 2023-02), keeping the **modern** (≥ 2023-03-01) data as the source of
truth. Build a format-adaptor + a legacy PDF reader and normalize old bulletins into
the existing schema **without breaking the modern pipeline**.

> Aligns with the v1 priority principle (history is secondary; "looks populated" is
> enough). This plan adds rigor only where it protects the **modern** data and the
> **core-basket** mapping. The legacy long tail is best-effort.

---

## 0. TL;DR of what we're doing

1. Refactor `CeasaRio::Parser` into a **dispatcher** that sniffs the format and delegates
   to `Parser::Modern` (today's logic, unchanged) or `Parser::Legacy` (new).
2. Write `Parser::Legacy` to read the 14-page 2022/early-2023 layout into the **same**
   `Bulletin`/`Row` structs, so `Loader`/`Matcher`/`UnitNormalizer`/schema are untouched.
3. Map the legacy **core basket** spellings into `ProductMap` (iteratively, via
   `pending_matches`).
4. Lower the backfill gate to `2022-01-01`, remove the skip-Legacy branch.
5. Run the backfill politely; verify modern data is untouched, history extends to 2022,
   and real-terms charts/percentiles still compute.

**Expected outcome:** +~250 bulletins (2022-01 → 2023-02); history grows from ~3.3 to
~4.4 years (one extra full seasonal cycle for market-timing percentiles). **Zero risk
to modern data** (clean date cutover + idempotent loader).

---

## 1. Verified facts (live, 2026-06-21)

### 1.1 Availability ceiling
Hub `https://www.rj.gov.br/ceasa/Cota%C3%A7%C3%A3o` year tabs:

| Year | Node | Format |
|------|------|--------|
| 2026 | 600 | modern |
| 2025 | 500 | modern |
| 2024 | 388 | modern |
| 2023 | 330 | **mixed** — Jan/Feb legacy, Mar+ modern |
| 2022 | 328 | legacy (all 12 months) |
| ≤2021 | — | **NOT PUBLISHED** (no tab; direct-URL probes 404) |

**2022-01 is the hard floor.** Pre-2022 is out of scope (would need archive.org/FOI).

### 1.2 Exact cutover
- `01/03/2023` → **modern** (5 pages, `Dia Semana:`). Already ingested.
- `01/02/2023` and earlier → **legacy** (14 pages). Not yet ingested.
- **No temporal overlap.** "Modern wins" is automatic; idempotency is belt-and-suspenders.

### 1.3 Legacy inventory (≈269 PDFs)
All 12 months of 2022 (~232) + Jan 2023 (~21) + Feb 2023 (~16). Each month node
paginates (`?page=0`, `?page=1`). 2022 month nodes: Jan 315, Feb 326, Mar 325, Apr 324,
May 323, Jun 322, Jul 321, Aug 320, Sep 319, Oct 318, Nov 317, Dec 316. 2023: Jan 329,
Feb 336. (These are discovered automatically by the crawler — listed only for reference.)

### 1.4 Index coverage
`PriceIndex::Fetcher` pulls the **full** BCB SGS series (IPCA 1737, INPC 188) with no
date floor, so 2022 index levels are already covered once `RefreshPriceIndicesJob` has
run. No change needed; just verify (Step 8.7).

---

## 2. Legacy vs Modern — the adaptor's exact responsibilities

Reference fixtures (saved):
`test/fixtures/files/ceasa/legacy/{2022-01-25,2022-12-30,2023-01-02}.pdf`,
`test/fixtures/files/ceasa/modern/{2023-03-01,2026-06-19}.pdf`.

| Concern | Modern (existing) | Legacy (new reader must…) |
|---|---|---|
| **Date** | `Dia Semana: <wd> DD/MM/YYYY` | bare `DD/MM/YYYY ... Boletim n° NNN` at top; pick the **first** occurrence (it repeats per page) |
| **Weekday** | read from text | **derive** from the date (`Date#wday` → pt-BR name) |
| **12M variation** | column present | **absent** → `variation_12m = nil` for all rows |
| **Sections** | `N. NAME` (numbered, 7) | named banners, **not numbered**, repeated across pages (see §2.1) → map to canonical ints |
| **Product code** | none | 3-letter+ code column (ACE, OVOGE…) — capture for audit, not a join key in v1 |
| **Packaging/weight** | clean `UNIDADE EMBALAGEM` col | buried in product-name **parentheses** e.g. `Acelga (PGM 20 KG-8 CAB)`, `(MOL 0,25 KG)`, `ABACATE (CXM 20 Kg)` → extract weight from parens |
| **Variant rows** | tipo on same line | header line + `*`-prefixed children inheriting the header's packaging (see §2.2) |
| **No quote** | `S/C` | `Sem cotação` → null prices (row still recorded) |
| **Pages** | 4–5 | 14 |

### 2.1 Legacy section banner → canonical section map

Legacy banners (verbatim, may repeat/wrap across pages) → canonical modern `section` int
(so legacy rows share the existing `ProductMap`):

| Legacy banner (startswith, accent-insensitive) | Canonical section |
|---|---|
| `Folhas, Flores e Hastes` | 4 (HORTALIÇAS FOLHA, FLOR E HASTE) |
| `Frutos` | 3 (HORTALIÇAS FRUTO) |
| `Raízes, Bulbos, Tubérculos` | 5 (HORTALIÇAS RAIZ, BULBO, TUBÉRCULO) |
| `Frutas Nacionais` | 1 (FRUTAS NACIONAIS) |
| `Frutas Importadas` | 2 (FRUTAS IMPORTADAS) |
| `OVOS` | 6 (OVOS) |
| `Pescados` | 7 (PEIXE) |
| `Flores e Plantas Ornamentais` | — (skip: not in checker, not in modern map) |
| `Outros gêneros…` (industrializados) | — (skip / pending only) |

> ⚠️ Validate this mapping against fixtures during Step 4 — the legacy taxonomy is
> coarser than modern in places (e.g. legacy "Frutos" ≈ modern "Hortaliças Fruto"). Where
> a legacy product can't be confidently slotted, it lands in `pending_matches` (safe).

### 2.2 The `*Tipo` block (the trickiest part)

```
ALFACE CRESPA (PGM 6 Kg – 18UN          ← header: product + packaging (paren may be unclosed)
*Extra        ALFCA  E6  20,00  25,00  30,00   ← child: tipo "Extra", code, prices
*Especial     ALFCB  E6  18,00  20,00  25,00   ← child: tipo "Especial"
```
Rules for the reader's state machine:
- A **non-`*` line that has no full price triple** but contains an opening packaging paren
  → it's a **product header**: set `current_product`, parse `current_packaging` from the
  parens, **do not emit a row**.
- A **`*`-line** → emit a row: `raw_product = current_product`, `raw_tipo` = label after
  `*` (e.g. `Extra`), `raw_unit` = weight parsed from `current_packaging`, prices from
  the line.
- A **non-`*` line WITH a full price triple and its own parens** (e.g. `Acelga (PGM 20
  KG-8 CAB) ... 15,00 18,00 20,00`) → single self-contained row: `raw_product` = name,
  `raw_tipo = nil`, packaging from its own parens.
- Reset `current_product`/`current_packaging` on each new product header and on each
  section banner. This prevents children inheriting a stale header (a known modern-bug
  analog).

### 2.3 Weight extraction from parens
From the parenthetical, take the **first** `\d+(?:[.,]\d+)?\s*kg` (case-insensitive):
- `(PGM 20 KG-8 CAB)` → 20 kg → `raw_unit` normalized form drives `UnitNormalizer#per_kg`.
- `(MOL 0,25 KG)` → 0.25 kg.
- `(CXM 20 Kg)` → 20 kg.
- Eggs `(30 DÚZIAS)` / code `X30` → per-dozen family (no kg) → `price_per_kg = nil`.
- No kg found (e.g. truncated `(... 18UN` with no kg) → `price_per_kg = nil`, still
  record the row with whatever `raw_unit` text we have. **Never crash.**

> Set `raw_unit` to a **normalized synthetic string** the existing `UnitNormalizer`
> understands (e.g. `"Cx 20 kg"`, `"Mol 0,25 kg"`, `"Cx 30 dz"`, `"Unid 2,0 kg"`), so
> the SAME normalizer handles both eras. The reader's job is to translate legacy packaging
> into a modern-style `raw_unit` token, then reuse all downstream code.

---

## 3. Design — one seam, everything else reused

```
app/services/ceasa_rio/
  parser.rb                 # → becomes a thin DISPATCHER (public API unchanged)
  parser/
    modern.rb               # today's Parser logic, moved verbatim
    legacy.rb               # NEW
```

- Public surface stays `CeasaRio::Parser.new(path).parse` returning
  `Bulletin(price_date:, weekday:, rows:[Row(...)])`. Callers (`Loader`, rake task,
  jobs, tests) **do not change**.
- Dispatch: run `pdftotext -layout` once, then:
  - `/Dia\s*Semana:/` present → `Parser::Modern`
  - else if `/Boletim\s*n[°º]/i` present → `Parser::Legacy`
  - else → raise (unknown format; surfaces loudly, never silently mis-parses).
- Both sub-parsers share the `Bulletin`/`Row` `Struct` definitions (move them to the
  dispatcher or a small shared module). `Row` keeps the same fields; legacy fills
  `variation_12m = nil`.
- `Loader`, `VariantMatcher`, `UnitNormalizer`, schema, dedup, jobs: **unchanged**.

**Why this is safe:** the only format-coupled code in the whole pipeline is the parser.
Extracting Modern with zero behavior change keeps the modern path byte-identical; Legacy
is purely additive.

---

## 4. "Modern wins" guarantee (explicit, defense-in-depth)

1. **No overlap:** cutover is clean at 2023-03-01; legacy only produces dates ≤ 2023-02-28.
2. **Bulletin idempotency:** `Loader#ingest` early-returns if `Bulletin.exists?(market,
   price_date)`. Any already-ingested modern date is a no-op.
3. **Price idempotency:** per-row `next if Price.exists?(bulletin, variant, raw_unit)`.
4. **Source-url uniqueness:** `BackfillCeasaRioJob` skips `Bulletin.exists?(source_url:)`.
5. **Ordering:** run legacy backfill **after** modern is already in place (it is). Even
   if order flipped, (1)–(3) still protect modern.

**Test for it (Step 7.6):** ingest `2023-03-01` (modern) then attempt to ingest a legacy
PDF that (hypothetically) claims the same date → assert bulletin count unchanged and the
modern row values untouched.

---

## 5. Build order (phased, each phase independently green)

### Phase L0 — Safety net & baseline (no code change)
- [ ] L0.1 `bin/rails db:migrate:status` clean; `bin/rails test` green (record baseline counts).
- [ ] L0.2 **Backup the SQLite DB**: copy `storage/*.sqlite3` to a timestamped file.
      Rationale: backfill writes ~250 bulletins; a snapshot makes rollback trivial.
- [ ] L0.3 Record baseline metrics:
      `Bulletin.count`, `Price.count`, `Bulletin.minimum(:price_date)`,
      `PendingMatch.count`. Save them in this file's Step 9 log.

### Phase L1 — Extract `Parser::Modern` (zero behavior change)
- [ ] L1.1 Create `app/services/ceasa_rio/parser/modern.rb` with the **current**
      `Parser` body (rename class to `CeasaRio::Parser::Modern`).
- [ ] L1.2 Turn `app/services/ceasa_rio/parser.rb` into the dispatcher; move the
      `Bulletin`/`Row` structs to a shared spot both sub-parsers use.
- [ ] L1.3 Add a parser test (new file `test/services/ceasa_rio/parser_test.rb`) that
      parses `modern/2026-06-19.pdf` and asserts: date `2026-06-19`, weekday present,
      a known row (e.g. `ABACATE`, section 1, modal 60.00), eggs per-dozen row exists,
      total row count > 150. **Must pass before touching Legacy.**
- [ ] L1.4 `bin/rails test` green; modern ingestion still works
      (`CeasaRio::Loader` smoke against the fixture).

### Phase L2 — `Parser::Legacy` (TDD against fixtures)
- [ ] L2.1 Write **failing** tests first in `parser_test.rb` for legacy fixtures:
      - `legacy/2022-01-25.pdf` → date `2022-01-25`, weekday derived `terça-feira`,
        `variation_12m` nil on all rows.
      - section mapping: an `Acelga` row → section 4; `ABACATE` → section 1;
        an `OVOS` row → section 6; a `Pescados` row → section 7.
      - a `*Tipo` block: `ALFACE CRESPA *Extra` → `raw_product="ALFACE CRESPA"`,
        `raw_tipo="Extra"`, `raw_unit` carries `6 kg`, modal `25.00`.
      - weight-in-parens: `Acelga (PGM 20 KG-8 CAB)` → `raw_unit` normalizes to 20 kg →
        `price_per_kg = 18.00/20`.
      - eggs: `OVOS *Extra` → per-dozen family, `price_per_kg` nil.
      - `Sem cotação` row → min/modal/max nil, row still present.
      - parse does NOT raise on `2022-12-30.pdf` and `2023-01-02.pdf`; row counts > 150.
- [ ] L2.2 Implement `app/services/ceasa_rio/parser/legacy.rb`:
      - `extract_date`: first `(\d{2})/(\d{2})/(\d{4})` near `Boletim n`.
      - `derive_weekday`: map `Date#wday` → pt-BR (`%w[domingo segunda-feira …]`).
      - section state machine using the §2.1 banner map (accent-insensitive startswith).
      - product-header / `*`-child / self-contained-row logic per §2.2.
      - parens weight → synthetic modern-style `raw_unit` per §2.3.
      - prices: reuse the modern price-triple tokenizer; `Sem cotação` → nils.
      - return `Bulletin` with the same struct shape.
- [ ] L2.3 Iterate until all L2.1 tests pass. Keep modern tests green.
- [ ] L2.4 **Coverage probe** (script, not committed): parse all 3 legacy fixtures, print
      `rows.size`, `% rows with price_per_kg`, and the count of rows whose
      `(section, raw_product, raw_tipo)` are NOT yet in `ProductMap`. Sanity-check the
      reader isn't dropping whole sections.

### Phase L3 — Map the legacy core basket
- [ ] L3.1 Run a **dry ingest** of the 3 legacy fixtures through `Loader` into a scratch
      DB (or wrap in a rolled-back transaction) to populate `pending_matches`.
- [ ] L3.2 Review `pending_matches` ordered by `occurrence_count desc`. For every
      **core-basket** product (see `db/seeds/core_basket.rb`), add a `ProductMap` row in
      a new seed `db/seeds/product_maps_legacy.rb` mapping the legacy
      `(section, raw_product, raw_tipo)` → existing canonical variant.
      - Expect spelling deltas: legacy `Tomate`/`TOMATE LONGA VIDA` vs modern `TOMATE`;
        legacy section numbers differ; legacy eggs `OVOS *Extra` vs modern `OVO …`.
      - Reuse `ProductAlias.normalize` for accent/case where helpful, but `ProductMap` is
        exact-match — transcribe the **exact** legacy codepoints (apostrophes, accents).
- [ ] L3.3 Make the legacy seed **idempotent** (`find_or_create_by`) and load it.
- [ ] L3.4 Re-run the dry ingest → assert **0 core-basket pending** from legacy fixtures.
      Long-tail (flowers, industrializados, extra fish) staying pending is acceptable.
- [ ] L3.5 Reconcile the `rake ceasa:validate_mapping` fixture path: it globs
      `spec/fixtures/ceasa/*.pdf`, but fixtures live in `test/fixtures/files/ceasa/`.
      Either symlink, or update the task to read both `modern/` and `legacy/` dirs.
      Then run it → core basket 100% across BOTH eras.

### Phase L4 — Lower the gate & wire the backfill
- [ ] L4.1 In `app/jobs/backfill_ceasa_rio_job.rb`: change `MODERN_MIN = 2023-03-01` to
      `LEGACY_MIN = Date.new(2022, 1, 1)` and **remove** the
      `if bulletin.price_date < MODERN_MIN ... next` skip branch. Keep the
      `Bulletin.exists?(source_url:)` skip and the `sleep 0.8` politeness.
- [ ] L4.2 Confirm `CeasaRio::Crawler` already discovers 2022/2023 month hrefs (it walks
      every year tab; it does — the only filter was in the job). No crawler change needed
      beyond confirming `paginate_pdfs` reaches `?page=1` for legacy months (it loops
      0..20, fine).
- [ ] L4.3 Add a guard so a parse failure on one PDF doesn't abort the whole run (the job
      already rescues per-URL — verify it logs `source_url` + error and continues).

### Phase L5 — Dry-run, then full backfill
- [ ] L5.1 **Dry-run subset:** temporarily ingest a single legacy month (e.g. Dec 2022)
      via a one-off runner that calls `Crawler` for that month node only, or filter URLs
      by `/2022/`. Verify: ~22 bulletins added, dates all in Dec 2022, `pending_matches`
      grows only with long-tail, no exceptions, modern counts unchanged.
- [ ] L5.2 **Full backfill:** `bin/rails runner "BackfillCeasaRioJob.perform_now"` (or
      enqueue). It will re-walk everything but **skip all existing** modern bulletins via
      `source_url`/`price_date` dedup, ingesting only the ~250 new legacy ones.
      Runtime ≈ 269 × (0.8s sleep + fetch+parse) ≈ several minutes; let it run.
- [ ] L5.3 Watch `log/` for `Failed to process <url>` lines; collect any persistently
      failing PDFs for a follow-up (don't block the whole run on a few oddballs).

### Phase L6 — Verify correctness (nothing broke)
- [ ] L6.1 **Modern untouched:** `Bulletin.where("price_date >= '2023-03-01'").count` ==
      baseline (766). `Price.joins(:bulletin).where("bulletins.price_date >=
      '2023-03-01'").count` == baseline (151,917). **Hard gate.**
- [ ] L6.2 **History extended:** `Bulletin.minimum(:price_date)` ≈ 2022-01-03;
      `Bulletin.group("strftime('%Y-%m', price_date)").count` shows every month
      2022-01 … 2023-02 populated (expect ~14–22 each). No month with 0.
- [ ] L6.3 **Dedup integrity:** no duplicate `(market, price_date)`; no duplicate
      `(variant_id, bulletin_id, raw_unit)`.
- [ ] L6.4 **Pricing sanity:** spot-check 5 legacy rows by hand against the PDF
      (a per-kg produce, eggs per-dozen, a `*Tipo` child, a `Sem cotação`, a per-unit
      fruit) — values and units correct.
- [ ] L6.5 **Verdict still works:** run the checker for tomate/ovo/abacaxi (the 3 modes)
      — verdicts unchanged (they use latest price, which is still modern).
- [ ] L6.6 **Real-terms history:** `PriceHistory` for a staple (e.g. tomate, 18-month
      window crossing the cutover) returns a continuous deflated series with no nil gaps
      at the 2023-02→03 boundary; sample count rose. `MarketTiming` percentile still
      computes (>30 samples).
- [ ] L6.7 **Pending review:** `PendingMatch.where("first_seen < '2023-03-01'")` —
      confirm only long-tail (flowers/industrializados/extra fish), **0 core basket**.
- [ ] L6.8 Full `bin/rails test` green.

### Phase L7 — Document & cleanup
- [ ] L7.1 Update `STATUS.md` / `PROGRESS.md` with new counts and the legacy-era line.
- [ ] L7.2 Note in `AGENTS.md` that legacy is now ingested and how to extend pre-2022 if
      the data ever becomes available.
- [ ] L7.3 Decide on the **weekly reconcile** job: it will now also re-walk 2022/2023 —
      that's fine (idempotent), but if it's noisy, scope reconciliation to the current
      year and keep the legacy crawl one-shot. (Recommendation: make legacy a one-shot;
      leave the Sunday reconcile to recent months only.)
- [ ] L7.4 Keep the L0.2 DB backup until L6 fully passes, then remove.

---

## 6. Files touched (summary)

| File | Change |
|---|---|
| `app/services/ceasa_rio/parser.rb` | → dispatcher (sniff + delegate); owns shared structs |
| `app/services/ceasa_rio/parser/modern.rb` | **new** — today's parser, moved verbatim |
| `app/services/ceasa_rio/parser/legacy.rb` | **new** — legacy reader |
| `test/services/ceasa_rio/parser_test.rb` | **new** — modern + legacy parse tests |
| `db/seeds/product_maps_legacy.rb` | **new** — legacy core-basket `ProductMap` rows |
| `db/seeds.rb` | load the legacy map seed (idempotent) |
| `app/jobs/backfill_ceasa_rio_job.rb` | `LEGACY_MIN = 2022-01-01`; drop skip-Legacy branch |
| `lib/tasks/ceasa_validate.rake` | fix fixture path to `test/fixtures/files/ceasa/**` |
| `STATUS.md`, `PROGRESS.md`, `AGENTS.md` | update counts/notes |

**Not touched (by design):** `Loader`, `VariantMatcher`, `UnitNormalizer`, schema,
models, `Fetcher`, `Crawler` (logic), verdict/history/timing services, views, controllers.

---

## 7. Risks & mitigations (legacy-specific)

| Risk | Likelihood | Mitigation |
|---|---|---|
| `pdftotext -layout` column drift across 14 pages / wrapped banners | high | line-by-line state machine (not fixed columns); accent-insensitive startswith banner detection; repeated banners are harmless (idempotent state set) |
| `*Tipo` child inherits stale packaging | med | reset `current_product`/`current_packaging` on every product header & banner (§2.2) |
| Truncated parens (`(PGM 6 Kg – 18UN` no close) | med | regex on first `\d+ kg` tolerates missing `)`; fallback nil per-kg, never crash |
| Legacy taxonomy coarser than modern → wrong section | med | §2.1 map validated on fixtures; ambiguous rows → `pending_matches` (safe, not wrong data) |
| Accent/apostrophe codepoint mismatch in `ProductMap` | med | transcribe exact legacy bytes; use `ProductAlias.normalize` to spot dupes; the known U+2019/U+00A0 bugs are documented in AGENTS.md |
| One bad PDF aborts backfill | low | per-URL rescue already present; verify it continues + logs `source_url` |
| Backfill accidentally rewrites modern | very low | 4-layer idempotency (§4) + L6.1 hard gate + L0.2 DB backup |
| Index levels missing for 2022 | low | SGS API returns full series; verify via `PriceIndex.where("reference_month < '2023-01-01'").exists?` (Step 8.7) |
| Pre-2022 wanted later | n/a | out of scope; documented ceiling; additive if an archive surfaces |

---

## 8. Acceptance criteria (Definition of Done)

1. `Parser` dispatcher chooses Modern/Legacy correctly; raises on unknown.
2. `Parser::Modern` output **byte-identical** to pre-refactor (modern tests green).
3. `Parser::Legacy` parses all 3 legacy fixtures: correct date, derived weekday, sections
   mapped, `*Tipo` children correct, weights from parens, eggs per-dozen, `Sem cotação`
   nulled, no crashes, >150 rows each.
4. Legacy core basket **100% mapped** (`rake ceasa:validate_mapping` across both eras).
5. Backfill ingests ~250 legacy bulletins (2022-01 → 2023-02); every month populated.
6. **Modern bulletin/price counts unchanged** (766 / 151,917). No dup `(market,
   price_date)` or `(variant, bulletin, raw_unit)`.
7. `PriceHistory`/`MarketTiming` compute continuously across the cutover; sample counts up.
8. Checker verdicts (3 modes) unchanged. Full test suite green.
9. `PendingMatch` pre-2023 contains only long-tail (0 core basket).

---

## 9. Run log (fill during execution)

```
Baseline (L0.3):    Bulletins=____  Prices=____  min(price_date)=____  Pending=____
After dry-run L5.1:  +____ bulletins (Dec 2022)
After full L5.2:     Bulletins=____  Prices=____  min(price_date)=____  Pending=____
Modern gate L6.1:    >=2023-03-01 bulletins=____ (must==766)  prices=____ (must==151917)
Months populated:    2022-01..2023-02 all >0?  [ ]
Failing PDFs:        ____ (urls)
```
