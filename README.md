# Tá Justo? — CEASA-RJ Fair Price Index

**The first consumer pricing index for Rio de Janeiro.**

Tá Justo? turns CEASA-RJ's daily wholesale PDF bulletins into a fair-price
benchmark that any shopper at a feira or market can check in 3 taps.

> **Agents/contributors:** read [`AGENTS.md`](AGENTS.md) first — it captures the
> non-obvious facts about the CEASA pipeline (two PDF formats, URL/date traps,
> idempotency, pricing modes, and known historical bugs).

---

## 🎯 What It Does

Three surfaces:
1. **`/` — The Checker** (the hero) — Pick a product → enter the R$/kg you're
   paying → get a verdict: *Barato / Na média / Caro*, plus a two-axis read:
   markup vs. wholesale and **when in the year** to buy (seasonality).
2. **`/precos` — Today's CEASA Index** — Today's atacado prices by section,
   with 12-month variation.
3. **`/produtos/:slug` — Product Detail** — Price-history line chart +
   seasonality chart + verdict calculator.

**Not a SaaS.** Free, droplet-hosted, portfolio-quality, genuinely useful.
One city, one source, one question.

---

## 📊 Data (live)

- **~1,000+ bulletins** ingested (Jan 2022 → today, modern + legacy formats)
- **~185k price rows** across **238 variants** / **169 products**
- **428 product maps** (deterministic CEASA→variant); **280 pending matches**
  (unmapped long tail — nothing is lost, audited in `pending_matches`)

---

## 📐 Data Model

- **Bulletins** — CEASA-RJ PDF bulletins (`market` is a string seam for future CEASAs)
- **Products** — canonical products (market-agnostic)
- **Variants** — grades / origins / species
- **ProductMaps** — explicit market→variant mapping (100% deterministic)
- **ProductAliases** — flexible naming for search (normalized lookups)
- **Prices** — time-series with unit normalization (`per_kg` / `per_dozen` / `per_unit`)
- **PriceIndex** — derived index view
- **PendingMatches** — safety net for unmapped products

---

## 🔧 Tech Stack

- **Ruby 3.4.2 · Rails 8.1** + SQLite3
- **Hotwire** (Turbo + Stimulus) + **importmap**
- **D3.js** (vendored) — history line chart + seasonality, via a Stimulus controller
- **Solid Queue** for background jobs
- **Kamal** for deployment

---

## 🧠 Verdict Engine

A fair-price verdict is decomposed into composable value objects, each tested:
- **`FairPriceVerdict`** — orchestrator
- **`Markup`** — shopper price vs. wholesale band
- **`MarketTiming`** + **`BuyTiming`** — is now a good moment in the season?
- **`PriceHistory`** + **`SeasonalityCalculator`** — percentile bands & trends
- **`PackSize`** / **`UnitNormalizer`** — multi-packaging & unit edge cases

---

## 🏗️ Project Structure

```
app/
├── controllers/   checks, precos, products, pages
├── models/        Bulletin, Product, Variant, Price, PriceIndex,
│                  ProductMap, ProductAlias, PendingMatch
├── services/
│   ├── ceasa_rio/ Parser (modern + legacy), Fetcher, Crawler,
│   │              Loader, VariantMatcher, UnitNormalizer, Archiver
│   └── ...        FairPriceVerdict, Markup, MarketTiming, BuyTiming,
│                  PriceHistory, SeasonalityCalculator, ChartSeries
├── jobs/          FetchCeasaRioJob (daily), BackfillCeasaRioJob (historical)
└── javascript/    d3_line_chart_controller (Stimulus)
```

---

## 📖 Documentation

- [`AGENTS.md`](AGENTS.md) — working notes & CEASA data caveats (read first)
- [`CONTEXT.md`](CONTEXT.md) — ubiquitous-language glossary
- [`STATUS.md`](STATUS.md) / [`PROGRESS.md`](PROGRESS.md) — execution status
- [`specs/PLAN_LEGACY_BACKFILL.md`](specs/PLAN_LEGACY_BACKFILL.md) — pre-2023
  historical import (the legacy PDF format cutover is exactly 2023-03-01)

---

## 🧪 Development

```bash
bundle install
bin/rails db:create db:migrate
bin/dev                # web + Solid Queue (Procfile.dev)

# fetch today's CEASA bulletin
bin/rails runner "FetchCeasaRioJob.perform_now"
```

PDF parsing shells out to `pdftotext -layout` (poppler) — a hard dependency.

---

## 📝 License

Portfolio project. Not for commercial use.

---

**Built with care in Rio de Janeiro 🇧🇷**
