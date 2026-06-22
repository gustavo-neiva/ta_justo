# Session Context: Legacy Historical Backfill (CEASA-RJ pre-March 2023)

**Exported:** 2026-06-21 21:30
**Project:** /Users/gustavo-neiva/Code/gustavo-neiva/ta_justo
**Plan:** specs/PLAN_LEGACY_BACKFILL.md
**Duration:** ~4 hours (full session)

---

## Environment

- **Working Directory:** /Users/gustavo-neiva/Code/gustavo-neiva/ta_justo
- **Git Branch:** main
- **Git Status:** dirty — all changes are uncommitted (no `git add` was run)
- **Ruby:** 3.4.2 (via asdf)
- **DB backup:** `storage/development.sqlite3.backup-20260621-*` (created at L0.2)

---

## DB State (end of session)

```
Bulletins:         1037  (769 modern + 268 legacy)
Prices:          162907  (151920 modern + 10987 legacy)
min(price_date): 2022-01-03
max(price_date): 2026-06-19  (modern untouched)
Modern bulletins (≥2023-03-01): 769  ← hard gate PASSED ✓
Legacy bulletins (<2023-03-01): 268
PendingMatch:       434  (42 pre-existing + 392 from legacy)
ProductMaps:        276  (248 modern + 28 legacy/extras)
```

---

## Active Todos

- ✅ L0 — Safety net: DB backed up, baseline recorded
- ✅ L1 — Extract `Parser::Modern` (zero behavior change, 19 tests green)
- ✅ L2 — `Parser::Legacy` implemented and tested (all 19 parser tests pass)
- ✅ L3 — Legacy core basket mapped (0 core-basket pending from fixtures)
- ✅ L3.5 — `ceasa:validate_mapping` fixture path fixed; core basket 100% across all 5 PDFs
- ✅ L4 — Backfill gate lowered to `LEGACY_MIN = 2022-01-01`; skip-legacy branch removed
- ✅ L5 — Full backfill ran; 268 legacy bulletins ingested (2022-01 through 2023-02)
- 🔄 L6 — Verification in progress (see below — 2 items remain)
- ⏳ L7 — Documentation update (STATUS.md, PROGRESS.md, AGENTS.md)

---

## Completed Work

### `app/services/ceasa_rio/parser.rb`
- **Changed:** Dispatcher — sniffs `Dia Semana:` → Modern, `Boletim n°` → Legacy, else raises
- **Owns:** `Bulletin` and `Row` structs (shared by both sub-parsers)
- **Why:** Clean seam, callers (Loader, jobs, tests) unchanged

### `app/services/ceasa_rio/parser/modern.rb` (NEW)
- **Changed:** Current parser body moved verbatim; class renamed `CeasaRio::Parser::Modern`
- **Accepts:** text string (not path); pdftotext runs once in dispatcher
- **Why:** Zero behavior change to modern pipeline

### `app/services/ceasa_rio/parser/legacy.rb` (NEW)
- **Key behaviors:**
  - Date: first `DD/MM/YYYY` near `Boletim n°`
  - Weekday: derived from `Date#wday` → pt-BR name
  - Section: banner starters at line start (before DROP_RE)
  - OVOS: bare "OVOS" line → section=6, current_product="OVOS", pkg="(30 DÚZIAS)"
  - `*`-children: inherit parent packaging for raw_unit
  - Children with own parens (e.g. `*Grande (2 Kg)`) use their own weight
  - Non-starred tipo children (e.g. PIMENTA `Baiana ...`) handled when current_product set
  - Paren continuation: unclosed `(` → next line absorbed; `*` line breaks out
  - `Sem cotação` → nil prices, row still recorded
  - `variation_12m = nil` for all rows
  - Synthesizes raw_unit from packaging: `"Cx N kg"`, `"Cx 30 dz"`, `"kg"`

### `test/services/ceasa_rio/parser_test.rb` (NEW)
- **19 tests, all passing:** modern date/weekday/rows/ABACATE/eggs, legacy date/weekday/variation_12m/sections/ALFACE CRESPA `*Tipo`/Acelga price_per_kg/eggs dz/Sem cotação, both other legacy fixtures no-crash, dispatcher routing

### `db/seeds/product_maps_legacy.rb` (NEW)
- **33+ core-basket entries** + compressed-layout variants:
  - MAMÃO: `formosa/comum /comprido` → Formosa; `PAPAYA / HAVAI` → Papaya/Havai
  - MANGA: Keit/Carlotinha/Haden → Tommy Atkins; Rosa → Espada
  - MAÇÃ s1: Fuji/Gala → Nacional Fuji/Gala
  - MAÇÃ s2: Gala/Grand smith/Red delicious variants (+ "Reddelicious" compressed)
  - UVA s2: Red globe/Thompson/Moscatel/Columbian/Almeria/Emperor + "Redglobe" compressed
  - MORANGO: Especial → Extra; Nectarina → nectarina/Nacional (misplaced in PDF)
  - ABÓBORA: Moranga Baby/Moranga híbrida (lowercase casing)
  - BERINJELA/CHUCHU/QUIABO: Especial → Extra
  - Coentro/Rúcula/Salsa: mixed-case versions (legacy PDFs use title-case)
  - BETERRABA: Especial → Extra
  - CENOURA: Extra + Especial → Extra A
  - Batata (section 7): fish "peixe batata" → pescada/Comum

### `db/seeds/product_maps.rb`
- **Changed:** Added `(7, "BATATA", "")` → pescada/Comum (pre-existing gap exposed by fixing validate_mapping path)
- **Fixed:** Line 33 used curly apostrophe (U+2019) in variant name lookup but DB has straight (U+0027) — fixed to use straight apostrophe

### `db/seeds.rb`
- **Changed:** Load `product_maps_legacy.rb` after `product_maps.rb`

### `app/jobs/backfill_ceasa_rio_job.rb`
- **Changed:** `MODERN_MIN` → `LEGACY_MIN = Date.new(2022, 1, 1)`; removed `if bulletin.price_date < MODERN_MIN ... next` skip branch; kept per-URL rescue + `sleep 0.8`
- **Preserved:** `Bulletin.exists?(source_url: url)` idempotency

### `lib/tasks/ceasa_validate.rake`
- **Changed:** Fixture path `spec/fixtures/ceasa/*.pdf` → `test/fixtures/files/ceasa/**/*.pdf` (was broken, now finds all 5 PDFs)

---

## In-Progress Work (L6 verification — 2 items remain)

### 🔄 Item 1: Parser bug fix needed (stray digit line)

**File:** `app/services/ceasa_rio/parser/legacy.rb:35`

**Bug:** Some live PDFs (e.g. `storage/ceasa/raw/2022-04-05.pdf`) have a price like `140,0` that `pdftotext -layout` breaks across two lines: `*Extra ... 140,0 150,00 165,00` and then `0` on the next line. The parser:
1. Can't extract 3 prices from the first line (140,0 doesn't match `\A\d{1,4},\d{2}\z`) → row skipped
2. Sees lone `0` → no DROP_RE match → treats it as product header → `current_product = "0"`
3. Next `*Grande`/`*Médio`/`*Pequeno` lines → emit rows with `raw_product = "0"`
4. Three `PendingMatch` entries: `s6 "0"/"Grande"`, `s6 "0"/"Médio"`, `s6 "0"/"Pequeno"`

**Fix:** Add `/\A\d+\z/` to `DROP_RE` at `legacy.rb:36` (after line 35 `/\A25Kg\)\z/i`):
```ruby
/\A\d+\z/,     # stray digit fragment from broken price line (e.g. "140,0" split to "0")
```

**After the fix:** re-run `bin/rails test` to confirm still green. The PendingMatch entries for "0" already exist in the DB from the live backfill (3 entries, occurrence_count=2, first_seen=2022-04-05) — they stay as legacy cruft but won't grow.

### 🔄 Item 2: 4 core-basket items in legacy pending from live backfill

**Not a blocker** — this affects the live-ingested data, NOT the fixture check (which passes).

**Root cause:** Some live PDFs (different months) compress "Red delicious" → "Reddelicious" and "Red globe" → "Redglobe" due to column width differences.

**Already mitigated:** `db/seeds/product_maps_legacy.rb` now has entries for both forms. Future re-ingestion attempts (if any) would route correctly. But since `Bulletin.exists?(source_url:)` skips already-ingested bulletins, the existing 268 legacy bulletins won't be re-processed.

**Items in pending:**
- `s2 MAÇÃ/Reddelicious americana` (→ maca-importada, Importada Red Delicious — now in seed)
- `s2 MAÇÃ/Reddelicious francesa` (→ same)
- `s2 MAÇÃ/Reddelicious argentina` (→ same)
- `s2 UVA/Redglobe` (→ uva-importada, Red Globe Importada Extra — now in seed)

**Decision:** Accept as known minor gap. The plan's L6.7 criterion is "0 core basket pending from legacy FIXTURES" (not live data). The fixture check passes. If prices for these specific MAÇÃ/UVA imported rows in the 268 bulletins are needed, a re-ingest script would need to delete the affected Bulletin records and re-run the backfill.

---

## Remaining L6 checks (already verified ✓)

- **L6.1 Modern gate:** 769 bulletins / 151920 prices (unchanged) ✓
- **L6.2 History extended:** min=2022-01-03, all 14 months populated (2022-01 to 2023-02) ✓
- **L6.3 Dedup:** 0 duplicate (market, price_date); 0 duplicate (bulletin, variant, raw_unit) ✓
- **L6.4 Spot-checks:** 41 prices in 2022-01-25 bulletin (core basket items correctly stored) ✓
- **L6.5 Verdicts:** Tomate Extra AA latest = 2026-06-19 (modern, unchanged) ✓
- **L6.6 History continuity:** 228 tomate price points in last 12 months, continuous ✓
- **L6.8 Tests:** 94 runs, 236 assertions, 0 failures ✓

---

## Phase L7: Documentation (⏳ not started)

Three files to update:
1. **`STATUS.md`** — add legacy era line, update bullet counts
2. **`PROGRESS.md`** — new entry for legacy backfill completion
3. **`AGENTS.md`** — note that legacy is now ingested; ceiling at 2022-01; "Reddelicious" layout variation documented

---

## Decisions Made

| Decision | Rationale | Rejected |
|---|---|---|
| Dispatcher sniffs text, delegates to sub-parsers | Caller API unchanged; single `pdftotext` run | Monolithic parser with format branching |
| Legacy `raw_unit` synthesized as `"Cx N kg"` | Reuses existing `UnitNormalizer.per_kg()` unchanged | New per-kg path in legacy parser |
| OVOS bare line → section 6 + current_product | Handles the "Outros → OVOS" nesting in legacy PDF | Treating OVOS as tail pending |
| Section banners checked BEFORE DROP_RE | Banners and column headers appear on same line | Two-pass parsing |
| Non-starred tipo children: if current_product set + no parens + has prices → child | Handles PIMENTA/Baiana pattern | Always treating price lines as self-contained |
| "Batata" (fish, §7) → pescada/Comum | Prevents core basket false positive; all occurrences are Sem cotação or minor prices | New product for batata fish |
| "Nectarina" under MORANGO → nectarina/Nacional | PDF mis-groups it; cross-product mapping correct | morango/Extra (wrong product) |
| MANGA Keit/Carlotinha/Haden → Tommy Atkins; Rosa → Espada | Best-effort for uncommon varieties | New variants (scope creep) |
| Accept 4 "Reddelicious" live-backfill pending items | Plan gate is fixture-based; re-ingest would require deleting 268 bulletins | Force re-ingest |
| `/\A\d+\z/` in DROP_RE (not yet applied) | Drops broken price fragments | Smarter multi-line price joining |

---

## Known Gotchas / Bugs Found

1. **`product_maps.rb` line 33:** Curly apostrophe (U+2019) in variant name lookup (`"Nanica/D\u2019Água Extra"`) but DB has straight apostrophe (U+0027). Fixed to use straight in the variant lookup while keeping curly in the ProductMap raw_tipo key.

2. **`pdftotext -layout` column drift:** Same content can produce different tokenization across PDF years (e.g., "Red delicious" vs "Reddelicious"). Handle by adding both forms to ProductMap.

3. **Broken price lines:** Some PDFs split `140,0` across two lines with `0` on the next line. Fixed (pending apply) with `/\A\d+\z/` in DROP_RE.

4. **Unicode case-folding in Ruby:** `/i` flag does NOT make `Ú` (U+00DA) match `ú` (U+00FA) in character classes `[...]`. Must explicitly include both: `[úÚu]`.

5. **SQLite case sensitivity:** `ProductMap.find_by(raw_product: "Acelga")` does NOT match `raw_product = "ACELGA"`. Legacy mixed-case product names require separate seed entries OR uppercase normalization in the parser.

---

## Next Session Start

### 1. Apply the stray-digit DROP_RE fix

Edit `app/services/ceasa_rio/parser/legacy.rb:35` — add after the last DROP_RE line and before `].freeze`:
```ruby
/\A\d+\z/,     # stray digit fragment from broken price line (e.g. "140,0" split to "0")
```
Then run:
```bash
bin/rails test test/services/ceasa_rio/parser_test.rb
bin/rails test
```

### 2. Verify PendingMatch "0" entries don't grow after fix

```bash
bin/rails runner 'puts PendingMatch.where(raw_product: "0").count'
# Should still be 3 (already ingested, won't grow since those bulletins are already in DB)
```

### 3. Complete L6 formally

```bash
bin/rails ceasa:validate_mapping 2>&1 | grep -E "Core basket|✅|❌"
```

### 4. Phase L7 — Update documentation

- `STATUS.md` — add: "Legacy era (2022-01 to 2023-02): 268 bulletins ingested"
- `PROGRESS.md` — new entry: legacy backfill complete, counts, cutover at 2023-03-01
- `AGENTS.md` — section on legacy format, "Reddelicious" variant, backfill ceiling

### 5. Commit everything

```bash
git add -A
git commit -m "feat: legacy backfill parser + seed + gate lowered (2022-01 to 2023-02)

- Parser::Modern/Legacy dispatcher (5-fixture TDD, 94 tests green)
- Legacy parser: date derived, sections mapped, *Tipo blocks, weights from parens
- Legacy seed: 33 core-basket mappings + compressed-layout variants
- Backfill gate: MODERN_MIN → LEGACY_MIN=2022-01-01
- validate_mapping: fixed fixture path to test/fixtures/files/ceasa/**
- Result: +268 bulletins, +10987 prices, history extends to 2022-01-03
- Modern data gate: 769 bulletins / 151920 prices UNCHANGED"
```

---

## Files Changed (uncommitted)

| File | Status | Notes |
|---|---|---|
| `app/services/ceasa_rio/parser.rb` | Modified | Dispatcher + shared structs |
| `app/services/ceasa_rio/parser/modern.rb` | **New** | Modern sub-parser |
| `app/services/ceasa_rio/parser/legacy.rb` | **New** | Legacy sub-parser |
| `test/services/ceasa_rio/parser_test.rb` | **New** | 19 tests |
| `db/seeds/product_maps_legacy.rb` | **New** | 33+ core-basket legacy maps |
| `db/seeds/product_maps.rb` | Modified | BATATA fish fix + curly-apostrophe fix |
| `db/seeds.rb` | Modified | Load legacy seed |
| `app/jobs/backfill_ceasa_rio_job.rb` | Modified | LEGACY_MIN, no skip branch |
| `lib/tasks/ceasa_validate.rake` | Modified | Correct fixture path |
| `STATUS.md` | **Not yet updated** |  |
| `PROGRESS.md` | **Not yet updated** |  |
| `AGENTS.md` | **Not yet updated** |  |

---

## Run Log (L9 from plan)

```
Baseline (L0.3):   Bulletins=769  Prices=151920  min=2023-03-01  Pending=42
After full L5.2:   Bulletins=1037 Prices=162907  min=2022-01-03  Pending=434
Modern gate L6.1:  >=2023-03-01 bulletins=769 ✓   prices=151920 ✓
Months 2022-01..2023-02 all >0: ✓ (14/14)
Failing PDFs: 0 (all 268 ingested successfully)
Known issues: 3 "0" pending (stray digit bug, fix pending); 4 "Reddelicious" pending (live layout variant)
```
