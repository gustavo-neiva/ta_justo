# Tá Justo? — Migration Status

**Last updated:** 2026-06-20 22:16

## ✅ Complete

### Infrastructure (Phases A1-A2, B1-B3, B5-B7)
- Rails 8 app scaffolded with SQLite, Hotwire, Solid Queue
- Database schema: 7 tables (bulletins, products, variants, product_maps, product_aliases, prices, pending_matches)
- Parser handles both Modern date formats (with/without "DATA:")
- Unit normalizer: 76 units → 72 to R$/kg, 4 special cases
- Seeds: 163 products, 234 variants, 235 CEASA-RJ mappings
- Core basket: 37 staple products
- **Multi-packaging support**: Same variant in different pack sizes tracked separately
  - Example: MANGA TOMMY ATKINS Cx 18kg (R$3.89/kg) vs Cx 5kg (R$7.0/kg)
  - Uniqueness constraint: (variant + bulletin + raw_unit)
  - `retail_packaging` scope prefers smaller packs for checker

### Data (18 Sample Bulletins)
- **18 bulletins ingested** (Mar 2023 - Apr 2024, ~13 months)
- **3,645 prices** (~202/bulletin avg)
- **204 unique variants** with data
- **43 pending matches** (42 fish §7, 1 banana curly-apostrophe variant)
- All core basket products have prices ✓

### Services & Jobs
- `CeasaRio::Parser` - Modern PDF parser (178/178 rows)
- `CeasaRio::UnitNormalizer` - 76 units, 4 special cases
- `CeasaRio::Fetcher` - daily fetch with triple validation
- `CeasaRio::Crawler` - discovers historical URLs
- `CeasaRio::VariantMatcher` - uses ProductMap table
- `CeasaRio::Loader` - idempotent ingestion with pending_matches safety net
- `FairPriceVerdict` - verdict engine (provisional bands: 1.7/2.5)
- `FetchCeasaRioJob` - daily forward with archiving
- `BackfillCeasaRioJob` - historical crawl (ready to run)

### Views & Controllers
- `/` - Checker with pick-from-list (✓ renders 200 OK)
- `/precos` - Today's CEASA index by section
- `/produtos/:slug` - Product detail (chart-free v1, D3 dormant)
- `/sobre` - About page
- CSS: Full design system copied (tokens + 14 components + 3 layouts)
- D3 controllers copied but unwired (deferred to v1.1 per plan)

## ⚠️ Ready to Run (Not Yet Executed)

### B4: Full Historical Backfill
**Status:** All code in place, just needs execution  
**What:** Ingest ~875 bulletins from Mar 2023 - Jun 2026  
**How:** `rails runner "BackfillCeasaRioJob.perform_now"`  
**Time:** ~12 minutes (0.8s delay × 875 requests)  
**Decision:** Run after C3 deploy, not locally (avoid hammering CEASA-RJ from dev machine)

### C1: Recurring Jobs Config
**Status:** Jobs created, config file pending  
**What:** Create `config/recurring.yml` for Solid Queue  
**Content:**
```yaml
production:
  fetch_ceasa_rio_job:
    class: FetchCeasaRioJob
    schedule: every weekday at 09:00 (America/Sao_Paulo)
  backfill_ceasa_rio_job:
    class: BackfillCeasaRioJob
    schedule: every Sunday at 04:00
```

## ❌ Not Started

### C2: Mobile QA
- Test checker, index, product detail on phone width
- Fix layout issues if any

### C3: Deploy
- Register `tajusto.com.br` domain
- Configure Kamal `deploy.yml`
- Set up droplet, SSL, backups
- Run full backfill post-deploy

## 🔧 Known Issues (Non-Blocking)

1. **1 core product variant unmapped:** BANANA "NANICA/D'ÁGUA Extra" (curly apostrophe `'` vs straight `'`)
   - Impact: 1 variant out of 204, ~19 price records
   - Fix: Add curly-apostrophe variant to ProductMap seed
   - Priority: Low (affects <0.5% of data)

2. **42 fish (§7) unmapped**
   - Impact: None (fish are index-only, not in checker per plan)
   - Fix: Seed pescado ProductMaps when enabling fish in index
   - Priority: Deferred to v1.1

## 📋 Next Steps (Priority Order)

1. **Create recurring.yml** (C1) - 5 minutes
2. **Mobile QA pass** (C2) - 30 minutes
3. **Deploy prep** (C3) - domain + Kamal config
4. **Deploy to droplet** - first production deploy
5. **Run full backfill** - post-deploy, on production server
6. **Test live checker** - use at real feira

## 🎯 Definition of Done Checklist (from Plan §12)

| # | Done | Item |
|---|------|------|
| 1 | ✅ | App boots; design system + header/footer + D3 vendored |
| 2 | ⚠️ | Parser: 178/178 on PDF (✓); edge-case tests (pending) |
| 3 | ⚠️ | Validation task created; needs sample PDFs in spec/fixtures/ |
| 4 | ⚠️ | Core basket (✓); 163/234 products/variants seeded (✓); 1 mapping issue (banana) |
| 5 | ⚠️ | Modern history ready to backfill; dedup verified (✓); pending reviewed (✓) |
| 6 | ⚠️ | Checker renders; verdict service done; controller/views need per-mode testing |
| 7 | ⚠️ | `/precos` created; needs QA |
| 8 | ✅ | `/produtos/:slug` minimal page; D3 copied but unwired |
| 9 | ✅ | Daily job created; holiday-aware (✓); needs recurring config |
| 10 | ❌ | Not deployed |
| 11 | ❌ | Not tested at real feira |

**Overall: 60% complete** — Infrastructure solid, ready for QA + deploy.
