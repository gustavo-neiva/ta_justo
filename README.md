# Tá Justo? — CEASA-RJ Fair Price Index

**The first consumer pricing index for Rio de Janeiro.**

Tá Justo? turns CEASA-RJ's daily wholesale PDF bulletins into a fair-price benchmark that any shopper at a feira or market can check in 3 taps.

---

## 🎯 What It Does

Three surfaces:
1. **`/` — The Checker** (the hero) — Pick a product → enter the R$/kg you're paying → get a verdict: Barato / Na média / Caro
2. **`/precos` — Today's CEASA Index** — Browse today's atacado prices by section, with 12-month variation
3. **`/produtos/:slug` — Product Detail** — History stats + verdict calculator (charts deferred to v1.1)

**Not a SaaS.** Free, droplet-hosted, portfolio-quality, genuinely useful. One city, one source, one question.

---

## 📊 Data Model

- **Bulletins** — CEASA-RJ PDF bulletins (market-aware seam for future expansion)
- **Products** — ~75 canonical products (market-agnostic)
- **Variants** — ~248 product variants (grades, origins, species)
- **ProductMaps** — Explicit market→variant mapping (100% deterministic)
- **ProductAliases** — Flexible naming for search (normalized lookups)
- **Prices** — Time-series price data with unit normalization
- **PendingMatches** — Safety net for unmapped products (nothing lost)

---

## 🔧 Tech Stack

- **Rails 8.1.2** + SQLite3
- **Hotwire** (Turbo + Stimulus)
- **D3.js** (vendored, dormant for v1.1)
- **Solid Queue** for background jobs
- **Kamal** for deployment

---

## 🚀 Current Status (2026-06-20)

### ✅ Completed
- Rails app scaffolding with full configuration
- Complete database schema (7 tables, all models)
- Core services:
  - `CeasaRio::Parser` — Modern PDF parser
  - `CeasaRio::UnitNormalizer` — 76 units, 4 special cases
  - `CeasaRio::Fetcher` — Daily fetch with validation
  - `CeasaRio::Crawler` — Historical URL discovery
  - `CeasaRio::Loader` — Idempotent ingestion
  - `FairPriceVerdict` — Verdict engine
- Background jobs:
  - `FetchCeasaRioJob` — Daily forward fetch
  - `BackfillCeasaRioJob` — Historical crawl

### 🔨 In Progress
- Product/variant seeds (blocked: needs Appendix C data)
- CSS/views migration from old AgroClaro repo
- Controllers & routes

### 📋 Next Steps
1. Create product seeds from Appendix C (248 tuples)
2. Copy CSS from old repo
3. Build controllers & views (checker, index, product detail)
4. Add validation rake task
5. Test end-to-end with sample PDF

---

## 🏗️ Project Structure

```
app/
├── models/               # 7 models (Bulletin, Product, Variant, Price, etc.)
├── services/
│   ├── ceasa_rio/       # Parser, Fetcher, Crawler, Loader, Matcher
│   └── fair_price_verdict.rb
└── jobs/                # FetchCeasaRioJob, BackfillCeasaRioJob

db/
├── migrate/             # Single migration: create_ta_justo_tables
└── schema.rb

storage/ceasa/raw/       # Archived PDFs (not in git)
```

---

## 📖 Documentation

See `~/Code/gustavo-neiva/agroclaro/specs/PLAN_MIGRATION_TACARO_2026_06_20_19:55.md` for the complete migration plan with:
- Full technical spec (§0-14)
- Data model design (§2)
- Parser & services (§4-6)
- Phasing & DoD (§11-12)
- Execution status (updated 2026-06-20 22:30)

---

## 🧪 Development

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate

# Run dev server
bin/dev

# Run jobs (when seeds are ready)
bin/jobs

# Fetch latest CEASA bulletin
bin/rails runner "FetchCeasaRioJob.perform_now"
```

---

## 📝 License

Portfolio project. Not for commercial use.

---

**Built with care in Rio de Janeiro 🇧🇷**
