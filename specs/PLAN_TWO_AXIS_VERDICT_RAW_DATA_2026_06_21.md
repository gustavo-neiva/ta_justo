# Plan — Two-Axis Verdict, Raw Data & Inflation-Adjusted Market Timing

**Date:** 2026-06-21
**Status:** Designed (grilled). Not yet implemented.
**Glossary:** see `CONTEXT.md` (Fair Price context).

---

## 1. Motivation

Today's verdict is too simplistic: `FairPriceVerdict#classify` answers a single
question — `paid ÷ atacado` against two fixed, admittedly-provisional bands
(1.7× / 2.5×). It conflates two genuinely different ideas and discards richer signals
it already computes (`percentile_12m`, `seasonality_note` are never rendered).

We split "cheap vs expensive" into **two axes** and expose the **raw wholesale data**
the farmer/seller sees (the caixa/dúzia → R$/kg translation), plus a market-timing
signal corrected for inflation so it isn't biased toward "caro" at the present edge.

### User story
> *I'm at a feira stall in Rio. The seller quotes me a price. Is this fair?*

"Fair" fractures into two questions with different blame:
1. **Is this _seller_ charging a fair margin?** (Markup — paid vs wholesale, same day)
2. **Is this _commodity_ expensive right now?** (MarketTiming — today's wholesale vs its
   own deflated 12-month distribution; nobody's fault, supply/season)

Plus a third, deeper layer: the **raw wholesale source** (box/dúzia quotes) and its
translation into R$/kg — currently a hidden `÷ weight`, which is why it feels shallow.

---

## 2. Domain model (Fair Price bounded context)

| Concept | Type | Responsibility |
|---|---|---|
| **ReferencePrice** | Value object | Raw wholesale quote(s) + derived comparable (R$/kg·dúzia·un). Owns caixa→kg translation and representative-row pick. The raw-data seam. |
| **PriceHistory** | VO / domain svc | Deflated 12-month real-terms series for a variant. Owns deflation + percentile. |
| **MarketTiming** | Value object | `{percentile, bucket, base_month, index_name, sample}` or **Null**. Paid-independent. |
| **Markup** | Value object | `{ratio, bucket}` from paid + ReferencePrice. |
| **FairPriceVerdict** | Aggregate root | Composes Markup + MarketTiming → synthesized verdict. |

**Invariant:** a Verdict is the coherent fusion of a Markup judgment and a MarketTiming
judgment; the synthesis sentence is the aggregate voicing that fusion. Markup is the
spine (always present); MarketTiming is enrichment (may be Null).

---

## 3. Decisions (from grilling session)

### 3.1 Representative row — determinism & shared selection
- **Bug:** `percentile_12m_per_unit` (fair_price_verdict.rb:150) ranks `@paid_amount`,
  not the CEASA price — inconsistent with the per_kg/per_dozen paths and paid-dependent.
  **Fix:** rank the historical CEASA-per-unit series; MarketTiming must be strictly
  paid-independent.
- **Bug:** verdict (×3), `ProductsController#latest_price_for`, and `Variant#latest_price`
  each select "the" price differently; among same-date packing sizes the choice is
  undefined. **Fix:** one deterministic rule = smallest retail pack (`retail_packaging`).
- **Single source of truth:** `Variant#representative_price(bulletin:)`, consolidating
  `latest_price` / `latest_price_per_kg`. Called by verdict, controller stats, and the
  raw-section "usamos esta" highlight so the displayed number == the computed number.
- **Blast radius gate:** switching to retail-pack selection changes `price_per_kg` for
  multi-box produce variants and can flip verdicts. **Before committing**, run a one-off
  script counting verdict flips across multi-box variants at current bands. Small/expected
  → ship. Large/surprising → scrutinise the `retail_packaging` `SUBSTR` parse first.

### 3.2 Market Timing — inflation-adjusted percentile
- Compute the trailing-12m percentile on **real (deflated)** prices, not nominal.
  Nominal is inflation-biased toward "caro" at the present edge — rejected.
- **Buckets:** ≤33rd pct = **época barata** · 33–67 = **preço normal** · ≥67th = **época cara**.
- **Sample guard:** ≥30 points required; below that → **Null** (render nothing).
- Axis 1 (Markup) stays on **nominal** prices (same-day comparison, no inflation).

### 3.3 Deflation methodology (verified against IBGE + `deflateBR`)
- **Official IBGE formula:** `real = nominal × (índice_base / índice_data)`.
  Confirmed via IBGE IPCA Calculadora and the R `deflateBR::ipca()` reference impl.
- **Store número-índice LEVELS directly** (not chained monthly variations):
  - **IPCA** = BCB SGS series **1737** (base dez/1993 = 100).
  - **INPC** = BCB SGS series **188**.
  - (agrobr's deflator chained series 433 and treated it as a level — a latent bug it
    survived only because it used ratios within forward-filled data. We avoid it.)
- **Base = latest published index month**, forward-filled. Bulletins newer than the last
  published month use factor 1.0. Surface the base month honestly:
  "em reais de hoje (IPCA, base mai/2026)". No forecasting/nowcasting.
- **Publication lag** (~mid next month, e.g. May/2026 released 12-Jun-2026) handled by
  forward-fill + a **>90-day-stale ⇒ Null** guard.
- Percentile rank is **base-invariant**, so index choice (IPCA vs INPC) moves coarse
  buckets only marginally.

### 3.4 Index choice — IPCA + INPC, both stored
- Track **both** (IPCA default; INPC = lower-income 1–5 min wages, weights food more
  heavily, better feira fit). Index becomes a **dimension**, switchable via filter/flag
  later. Not a config constant.

### 3.5 Price-index storage & jobs
- **One table** `price_indices`, grain `{index_name, reference_month, index_level}`,
  unique on `(index_name, reference_month)`. Model `PriceIndex`.
- **Seed full history** (~1100 rows total since 1979) in one fetch — permanently removes
  "insufficient index history" as a failure mode, including for the future CEASA
  legacy-PDF backfill.
- **`RefreshPriceIndicesJob`** — **weekly**, independent of the CEASA pipeline,
  idempotent upsert of both series; plus run-once on seed so timing works on fresh deploy.

### 3.6 Computation & caching
- MarketTiming computed **on demand**, cached on
  `(variant_id, latest_bulletin_id, index_name, index_month)`. Any input change ⇒ new
  key ⇒ recompute; staleness structurally impossible. No materialised columns.
- **Missing/stale IPCA ⇒ Null timing**, never a hard dependency. Markup (nominal,
  same-day) always works; fresh deploy is fully functional before the index job runs.

### 3.7 Raw data section
- Raw = **latest bulletin's row(s)** for the variant — show **all packaging variants**,
  mark the representative one ("usamos esta"). Columns: Embalagem (raw_unit),
  Atacado (modal), Faixa min–máx, Equivale a R$/kg, Var. 12m.
- Purpose is **unit-translation transparency** (box → R$/kg), not a time trend (the chart
  already owns trend). Single-snapshot only; no raw-history table.
- Collapsible `<details>` reusing existing `.accordion` CSS; **detail page only**,
  low on the page, collapsed.

### 3.8 Presentation
- **`/` checker hero:** stays **margin-only** (Markup badge + explanation, as today).
  Preserves the clean 3-tap price check. No timing, no synthesis, no raw data.
- **Product detail page** layout (order):
  header → stat cards → **quiet MarketTiming line** (under price) → chart →
  variant selector → **verdict calculator** (two axes + synthesis on price entry) →
  **raw data `<details>`** (collapsed) → nav.
- **Markup is the visual spine** (loud colored badge). MarketTiming, synthesis, and raw
  are **quiet secondary context**. Each degrades independently (Null timing → omit line;
  no price → no verdict; raw always available).
- **Synthesis** lives in the `FairPriceVerdict` aggregate (returns `synthesis_key` symbol
  + rendered pt-BR sentence). Labels/emoji stay in helpers (pure formatting).
- **Synthesis fires only on ~4 high-signal cells** (genuine disagreements + the one
  strong agreement); silent otherwise:

  | | Época barata | Normal | Época cara |
  |---|---|---|---|
  | **Barato** | silent (both good) | silent | ✓ "bom preço, mas o produto está caro pro ano" |
  | **Na média** | ✓ "preço ok, e o produto está barato — bom momento" | silent | ✓ "margem ok, mas é época cara" |
  | **Caro** | ✓ "vendedor caro num momento em que o produto está barato" | silent | silent (both bad) |

- **Chart/stats stay nominal** this iteration; real-terms toggle deferred to the chart work.

---

## 4. Work breakdown (suggested order — representative-row fix first, everything builds on it)

1. **Representative row**
   - `Variant#representative_price(bulletin:)`; consolidate `latest_price` /
     `latest_price_per_kg`. Route verdict (×3), controller, stats through it.
   - Fix `percentile_12m_per_unit` to rank CEASA series (paid-independent).
   - One-off **verdict-flip count script**; review before committing.
2. **Price index infra**
   - Migration `create_table :price_indices` (`index_name`, `reference_month`,
     `index_level`, unique index on the pair). `PriceIndex` model.
   - `PriceIndex::Fetcher` (BCB SGS, rotated bot headers — WAF blocks plain requests;
     pull série 1737 + 188). `RefreshPriceIndicesJob`, weekly + run-once on seed.
   - Seed full history.
3. **Deflation + MarketTiming**
   - `PriceHistory` (deflated 12m series; forward-fill base; >90d-stale ⇒ Null).
   - `MarketTiming` VO (buckets, ≥30 guard, Null states). On-demand + keyed cache.
4. **Verdict aggregate**
   - `Markup` VO; `FairPriceVerdict` returns Markup + MarketTiming + `synthesis_key`
     + sentence. Helpers for labels/emoji.
5. **Views (detail page only)**
   - Quiet MarketTiming line; two-axis verdict + synthesis; raw-data `<details>`.
   - `.timing-*` / `.verdict-axes` quiet-secondary CSS in `domain/ta_justo.css`.
6. **Tests** — representative_price; per-unit percentile fix; deflation vs known IBGE
   example; MarketTiming buckets + Null states; synthesis_key matrix (copy-independent).

---

## 5. Backlog (noted, explicitly out of scope)

- **Legacy CEASA PDF parser variant** → deeper history → more variants clear the ≥30
  guard and eventually enable true seasonal (calendar-month) comparison.
- **INPC** as selectable/default index; **real-terms chart toggle**; **timing on `/precos`**
  (would need materialisation per §3.6, currently premature).
- Re-tuning the 1.7×/2.5× Markup bands against real feira data (still unvalidated).

---

## 6. References

- IBGE deflation formula — https://www.ibge.gov.br/explica/inflacao.php
- SIDRA tabela 1737 (IPCA número-índice) — https://sidra.ibge.gov.br/ajax/tabela/descricao/1/1737
- `deflateBR::ipca()` (R reference impl) — https://search.r-project.org/CRAN/refmans/deflateBR/html/ipca.html
- BCB SGS price-indices FAQ — https://www.bcb.gov.br/conteudo/home-en/FAQs/FAQ%2002-Price%20Indices.pdf
- Prior art: `~/Code/gustavo-neiva/agrobr/agrobr/analytics/deflator.py` (BCB SGS client pattern, bot headers)
