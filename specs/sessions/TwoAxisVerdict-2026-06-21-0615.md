# Session Context: Two-Axis Verdict, Raw Data & Inflation-Adjusted Timing

**Exported:** 2026-06-21 06:15
**Project:** `/Users/gustavo-neiva/Code/gustavo-neiva/ta_justo`
**Plan:** `specs/PLAN_TWO_AXIS_VERDICT_RAW_DATA_2026_06_21.md`
**Task source:** user said "read specs/PLAN_TWO_AXIS_VERDICT_RAW_DATA_2026_06_21.md, understand, execute, tdd, linter, add commit"
**Orchestration note:** user enabled `pi-subagents` and asked to parallelize with **GLM-4.7** model in each subagent.

---

## Environment

- **Working Directory:** `/Users/gustavo-neiva/Code/gustavo-neiva/ta_justo`
- **Git Branch:** `main`
- **Git Status:** DIRTY — but most uncommitted files are **PRE-EXISTING work from OTHER tasks** (chart, seasonality, precos views). Do NOT touch those. Only the files listed under "Completed Work" below belong to THIS task.
- **Stack:** Rails 8.1.3, Ruby 3.4.2, SQLite, minitest, Solid Queue/Cache, Omakase Rubocop.
- **Models:** Product → Variant → Price → Bulletin. `Variant.pricing_mode` ∈ `per_kg|per_dozen|per_unit`.
- **Tests:** `bin/rails test`. Test DB is empty by default (no fixtures) — tests create their own data. **0 fixtures exist.**

## GLM-4.7 subagent setup (already done, reusable)

- Added `glm-4.7` model to `~/.pi/agent/models.json` (provider `zai`, same baseUrl/api/compat as `glm-5.2`). Verified available via `curl https://api.z.ai/api/coding/paas/v4/models`.
- To launch parallel GLM-4.7 subagents: `subagent({ tasks: [...], model: "glm-4.7", context: "fresh", async: true, concurrency: N })`.
- Builtin agents available: `scout`, `planner`, `worker`, `reviewer`, `context-builder`, `researcher`, `delegate`, `oracle`.
- **Pattern that worked:** 3 async read-only researchers (BCB API + deflation example + agrobr prior art) running while I did single-writer Phase-1 implementation. Reports saved to `tmp/research/` (see "Research outputs" below).

## Research outputs (in `tmp/research/` — READ THESE before Phase 2/3)

These were produced by GLM-4.7 subagents and are directly actionable:

- **`tmp/research/bcb-sgs-api.md`** — BCB SGS API contract. Use the SIMPLE endpoint:
  `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{code}/dados?formato=json`
  Returns full history in ONE response, no auth, no WAF block. Shape: `[{ "data": "DD/MM/YYYY", "valor": <level-number> }, ...]`. `valor` is the index LEVEL (e.g. IPCA ~6600+ in 2024, base dez/1993=100). IPCA série 1737 from dez/1979; INPC série 188 from jan/1979. Add a bot User-Agent anyway for safety. Ruby Net::HTTP snippet included in the file.
- **`tmp/research/deflation-example.md`** — **hardcoded test values** (Phase 3 test): `R$ 1000` (Jun/2025) × (7640.15 / 7312.97) = **`R$ 1044.74`** (May/2026 real). IPCA número-índice Jun/2025 = 7312.97, May/2026 = 7640.15. Formula verbatim: `real = nominal × (índice_base / índice_data)`. Base-invariant. Publication lag confirmed (~mid next month; May/2026 released 12-Jun-2026).
- **`tmp/research/agrobr-priorart.md`** — prior art at `/Users/gustavo-neiva/Code/gustavo-neiva/agrobr/agrobr/analytics/deflator.py`. Confirms the **série 433 latent bug** (433 = monthly variation, misused as a level). We use 1737 + 188 (true levels). Forward-fill pattern + idempotent upsert pattern documented.

---

## Plan progress (6 phases from plan §4)

- ✅ **Phase 1 — Representative row** (DONE, tests GREEN, blast-radius gate PASSED)
- ⏳ **Phase 2 — Price index infra** (NEXT: migration + model + fetcher + job + seed)
- ⏳ Phase 3 — Deflation + MarketTiming VO
- ⏳ Phase 4 — Verdict aggregate (Markup VO + synthesis_key matrix)
- ⏳ Phase 5 — Views (detail page only: quiet timing line, two-axis, raw `<details>`)
- ⏳ Phase 6 — Tests (partially done during each phase)

## Active Todos

- ✅ Phase 1: `Variant#representative_price` + per-unit percentile bug fix + controller routing
- 🔄 **NOT YET committed** — user asked for "add commit" but we paused first. Phase 1 is GREEN and ready to commit in isolation.
- ⏳ Phase 2: `create_table :price_indices` migration, `PriceIndex` model, `PriceIndex::Fetcher`, `RefreshPriceIndicesJob`, full-history seed.
- ⏳ Phase 3: `PriceHistory` (deflated 12m series, forward-fill, >90d-stale⇒Null), `MarketTiming` VO (buckets ≤33/33–67/≥67, ≥30 sample guard, Null states), keyed cache.
- ⏳ Phase 4: `Markup` VO, `FairPriceVerdict` returns Markup + MarketTiming + `synthesis_key` + pt-BR sentence, synthesis matrix (plan §3.8 — 4 high-signal cells only).
- ⏳ Phase 5: detail-page views + `.timing-*` / `.verdict-axes` quiet-secondary CSS in `app/assets/stylesheets/domain/ta_justo.css`.
- ⏳ Linter: run `bin/rubocop` before final commit (not yet run this session).

## Completed Work (Phase 1 — all GREEN, 26 tests)

1. **`app/services/pack_size.rb`** (NEW, full file)
   - Pure function `PackSize.kg(raw_unit)` → Float (kg) or nil.
   - Regex `/(\d+(?:[.,]\d+)?)\s*kg/i` extracts first kg weight; tolerates BR decimal comma, missing prefix, uppercase, trailing pack-count.
   - Test: `test/services/pack_size_test.rb` (17 assertions, GREEN).

2. **`app/models/variant.rb`** — public methods (lines):
   - `representative_price(bulletin:)` (line 25) — single source of truth. per_dozen → stable dozen row; else smallest retail pack via `PackSize.kg` (+ id tiebreak). Returns nil if no usable row.
   - `representative_series(months: nil)` (line 36) — one representative row per bulletin, oldest→newest, optionally windowed. Basis for percentile/market-timing.
   - `latest_price` (line 49) — now `representative_series.last` (was ad-hoc SQL `.retail_packaging.first`).
   - `latest_price_per_kg` (line 53) — delegates to `latest_price`.
   - PRIVATE `representative_dozen_row(rows)` (line 60) + `generate_slug`.
   - Test: `test/models/variant_representative_price_test.rb` (6 assertions, GREEN).

3. **`app/services/fair_price_verdict.rb`** (full rewrite via `write`)
   - **BUG FIX (plan §3.1):** `percentile_12m_per_unit` ranked `@paid_amount` → now `percentile_12m(current, mode)` (line 112) ranks the CEASA series via `comparable_series(mode)` (line 119). Strictly paid-independent.
   - All three `call_per_*` now go through `representative_latest` (line 129) → `latest_representative_bulletin` (line 134) → `@variant.representative_series.last`.
   - `comparable_series` (line 119) maps prices to the variant's unit (kg / dúzia / unidade).
   - Test: `test/services/fair_price_verdict_percentile_test.rb` (2 assertions: paid-independence + CEASA-position = 92nd pctile, GREEN).

4. **`app/controllers/products_controller.rb`**
   - `@latest_price = @variant.latest_price` (line 29) — was private `latest_price_for` (now deleted).
   - `build_stats` (line 60) + `comparable_for` (line 75) — stats now route through `representative_series(months: 12)` and the variant's comparable unit, so the displayed stat == the verdict's comparable.
   - Test: `test/controllers/products_controller_representative_price_test.rb` (1 integration test, GREEN — asserts stat card shows 13.00 not 6.11 for a multi-pack variant).

5. **`script/check_verdict_flips.rb`** (NEW) — one-off blast-radius gate (plan §3.1). Run: `bin/rails runner script/check_verdict_flips.rb`. **RESULT: 1 multi-pack variant (Tommy Atkins manga), 1 flip, and it's the EXPECTED correction** (old picked Cx 18 kg @ R$4.44/kg wholesale; new picks Cx 5 kg @ R$8.00/kg retail). Small/expected → safe to ship.

## Decisions Made

- **Single source of truth = `Variant#representative_price`.** Verdict (×3 modes), controller stats, and (later) raw-data highlight all call it. Replaces 3 divergent ad-hoc selections.
- **Selection rule = smallest retail pack** (feira shoppers buy small). Determinism tiebreak: `[PackSize.kg(unit) || Infinity, id]`.
- **Blast-radius gate passed** — only 1 affected variant, correct direction. Did NOT need to scrutinise PackSize parsing.
- **Percentile stays nominal in Phase 1** (Markup axis). Deflated percentile is the MarketTiming axis (Phase 3) — separate, computed on demand.
- **per_dozen handled specially** (all "Cx 30 dz" — pack size N/A → stable first dozen row by id).
- **GLM-4.7 registered** in `~/.pi/agent/models.json` for subagent use (provider `zai`).
- **Parallel research (3 GLM-4.7 subagents) used effectively** for Phase 2/3 unblocking while doing Phase 1 single-writer work.

## Next Session Start (Phase 2 — Price index infra)

1. **Commit Phase 1 first** (it's GREEN, blast-gate passed). Stage ONLY these files (avoid the unrelated pre-existing dirty files):
   ```
   git add app/services/pack_size.rb app/models/variant.rb \
           app/services/fair_price_verdict.rb app/controllers/products_controller.rb \
           script/check_verdict_flips.rb \
           test/services/pack_size_test.rb \
           test/models/variant_representative_price_test.rb \
           test/services/fair_price_verdict_percentile_test.rb \
           test/controllers/products_controller_representative_price_test.rb
   ```
   Also stage `~/.pi/agent/models.json`? NO — that's user-scope, outside repo. Skip.
   Run `bin/rubocop` on staged files before committing (user asked for "linter").

2. **Phase 2 migration** — `bin/rails g migration CreatePriceIndices`. Schema (plan §3.5): `index_name:string` (IPCA/INPC), `reference_month:date` (1st of month), `index_level:decimal`, unique index on `(index_name, reference_month)`. `db/migrate/` currently has 2 migrations; last version `20260621011019`.

3. **`app/models/price_index.rb`** — `validates :index_name, inclusion: %w[ipca inpc]`; `validates :reference_month, uniqueness: { scope: :index_name }`. Add scopes `for_month`, `latest`.

4. **`app/services/price_index/fetcher.rb`** — use SIMPLE endpoint from `tmp/research/bcb-sgs-api.md`:
   `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{1737|188}/dados?formato=json`.
   Parse `[{data:"DD/MM/YYYY", valor:N}]` → `{reference_month: Date, index_level: BigDecimal}`. Add bot User-Agent. TDD with a stubbed HTTP response (no network in tests).

5. **`app/jobs/refresh_price_indices_job.rb`** — idempotent upsert of both series. Add to `config/recurring.yml` weekly + run-once on seed (plan §3.5). Mirror `FetchCeasaRioJob` structure.

6. **`db/seeds/price_indices.rb`** + wire into `db/seeds.rb` — seed full history (~1100 rows, plan §3.5) via the fetcher. Run-once.

7. **Tests** (Phase 2): fetcher parsing (known `data`/`valor` JSON), model uniqueness, job idempotency (run twice → same row count).

## Phase 3 & 4 reminders (when you get there)

- **Hardcoded deflation test values** in `tmp/research/deflation-example.md`: IPCA Jun/2025 = 7312.97, May/2026 = 7640.15 → `1000 × (7640.15/7312.97) = 1044.74`. Use for `PriceHistory` known-answer test.
- **MarketTiming buckets** (plan §3.2): ≤33 = época barata, 33–67 = preço normal, ≥67 = época cara. Sample guard ≥30 else Null. >90d-stale index ⇒ Null.
- **Cache key** (plan §3.6): `(variant_id, latest_bulletin_id, index_name, index_month)`. Test env uses `:null_store` (`config/environments/test.rb:21`) — so don't rely on cache in tests; cache is an optimization, MarketTiming must compute correctly uncached.
- **Synthesis matrix** (plan §3.8) — only 4 cells fire; test each + the silent ones (copy-independent: assert on `synthesis_key` symbol, not the pt-BR string).
- **Views (Phase 5) detail-page only** — `/` checker stays margin-only. Order: header → stat cards → quiet timing line → chart → variant selector → verdict calculator (two axes + synthesis) → raw `<details>` → nav. New CSS classes `.timing-*` / `.verdict-axes` in `app/assets/stylesheets/domain/ta_justo.css` (quiet-secondary).

## Blockers

None. Phase 1 is GREEN and committed-ready. The aborted `bin/rails runner` smoke test at the end of the session was just a slow query on 151k prices — not a real failure; can re-run with a timeout or skip.

## Key file paths for quick reference

- Plan: `specs/PLAN_TWO_AXIS_VERDICT_RAW_DATA_2026_06_21.md`
- Context glossary: `CONTEXT.md`
- Verdict service: `app/services/fair_price_verdict.rb`
- Variant model: `app/models/variant.rb`
- Pack size: `app/services/pack_size.rb`
- Products controller: `app/controllers/products_controller.rb`
- Domain CSS: `app/assets/stylesheets/domain/ta_justo.css`
- Recurring jobs: `config/recurring.yml`
- Research: `tmp/research/{bcb-sgs-api,deflation-example,agrobr-priorart}.md`
