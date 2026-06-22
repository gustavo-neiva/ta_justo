# Tá Justo? — Migration Status

**Last updated:** 2026-06-21

---

## ✅ Complete

### Infrastructure (Phases A1–A2, B1–B3, B5–B7, C1)

- Rails 8 app scaffolded: SQLite, Hotwire, Solid Queue, importmap + D3 vendored
- Database schema: 7 tables (bulletins, products, variants, product_maps, product_aliases, prices, pending_matches)
- Seeds: 163 products, 234 variants, 235+ CEASA-RJ product_maps, 37 core-basket staples
- Multi-packaging uniqueness: `(variant + bulletin + raw_unit)` — tracks Cx 18kg vs Cx 5kg separately
- All 7 services: Parser, UnitNormalizer, Fetcher, Crawler, Loader, VariantMatcher, FairPriceVerdict
- All 4 controllers + views: `/` checker, `/precos` index, `/produtos/:slug` detail, `/sobre`
- CSS: full design system (tokens + 14 components + 3 layouts + domain/ta_justo.css)
- D3 controllers copied but unwired (deferred to v1.1)
- `config/recurring.yml`: daily fetch (weekdays 9am BRT) + Sunday backfill reconciliation

### Data (Full Backfill — B4 + Legacy Backfill Complete)

- **1,037 bulletins** ingested · 2022-01-03 → 2026-06-19
  - 769 modern (≥ 2023-03-01) · 268 legacy (2022-01-03 → 2023-02-28)
- **162,907 prices** (151,920 modern + 10,987 legacy)
- **434 pending matches** (42 pre-existing §7 fish + 392 from legacy; core basket not affected)
- **0 pending for core basket** (§1–6 produce + eggs fully mapped, fixtures and live data)
- All 54 months populated (2022-01 through 2026-06)

**Year breakdown:**

| Year | Bulletins | Era |
|------|-----------|-----|
| 2022 (Jan–Dec) | ~228 | Legacy |
| 2023 (Jan–Feb) | ~40 | Legacy |
| 2023 (Mar–Dec) | 201 | Modern |
| 2024 | 238 | Modern |
| 2025 | 224 | Modern |
| 2026 (Jan–Jun) | 103 | Modern |

### Bugs Found & Fixed During Backfill

| Bug | Root cause | Fix |
|-----|-----------|-----|
| BANANA NANICA missing from all 766 bulletins | PDF uses curly `'` (U+2019); seed had straight `'` | Updated ProductMap raw_tipo + re-ingested all bulletins |
| OVO BRANCO/VERMELHO missing | PDF emits `"BRANCO"`, seed expected `"BRANCO Extra"` | Added plain-raw_tipo ProductMap entries |
| 8 months silently skipped by crawler (Sep/Oct/Feb/Apr/Dec) | `.strip` ran before `.gsub` → U+00A0 not removed → month-name regex failed | Swapped to `.gsub(/\p{Space}+/, " ").strip` in `parse_month_links` |
| `ceasa:validate_mapping` found 0 fixture PDFs | Task globbed `spec/fixtures/ceasa/*.pdf` (non-existent) | Fixed to `test/fixtures/files/ceasa/**/*.pdf` |
| Legacy §2 MAÇÃ/UVA compressed variants unparseable | `pdftotext -layout` drops space in narrow columns: "Red delicious" → "Reddelicious" | Added both forms to `product_maps_legacy.rb` seed |
| Stray `0` line treated as product header | `140,0` price split across two lines by pdftotext; orphan `0` passed through | Added `/\A\d+\z/` to `DROP_RE` in `Parser::Legacy` |

---

## ✅ Completed in This Session

### Eggs verdict fix (per\_dozen mode)
- `FairPriceVerdict` now branches on `variant.pricing_mode`: `per_kg` / `per_dozen` / `per_unit`
- `per_dozen`: fetches `original_unit = 'dozen'` prices, computes `modal / 30` → R$/dúzia
- `per_unit`: computes `price_per_kg * avg_weight_kg` for single-unit produce
- `Result` struct updated: `ceasa_comparable`, `paid_comparable`, `unit_label` (replaces `ceasa_per_kg`/`paid_per_kg`)
- `ChecksController` updated: uses `paid_amount`, sets `@unit_label` from default_variant.pricing_mode
- View updated: dynamic label (R$/kg vs R$/dúzia vs R$/unidade), price-row display
- Added `config/locales/pt-BR.yml` with date formats `:long` / `:short` + month/day names

### End-to-end smoke test
- All 7 routes respond 200: `/`, `/precos`, `/produtos/tomate`, `/produtos/ovo`, `/sobre`, `/produtos/abacaxi`
- Checker verdicts verified in all 3 modes:
  - `per_kg` (tomate R$12.00): Barato, 1.4×, R$8.33/kg CEASA
  - `per_dozen` (ovo R$7.50): Barato, 1.3×, R$5.67/dúzia CEASA ← previously raised
  - `per_unit` (abacaxi R$5.00): Barato, 1.1×, ~1500g estimado
- `/precos` renders section groups (Frutas, Hortalicas, Ovos)
- `/produtos/ovo` and `/produtos/tomate` render correctly

## ❌ Not Started

### C2: Mobile QA (browser pass)
- Open http://localhost:3000 in browser at 375px width
- Check checker form, verdict display, `/precos` table scroll, product page

### C3: Deploy
- Register `tajusto.com.br`
- Fill `__DROPLET_IP__` in `config/deploy.yml`, run `bin/kamal setup`
- SSL auto-provisioned by Kamal/Thruster
- Daily SQLite backup cron + `storage/ceasa/raw/` backup

---

## 📋 Next Steps

1. **Mobile QA** (C2) — open in browser at 375px, check all 3 pages + checker all 3 modes
2. **Deploy** (C3) — domain → droplet → `bin/kamal setup` → verify `/up`
3. **Use it at a real feira** — first real-world verdict

---

## 🎯 Definition of Done (§12)

| # | Status | Item |
|---|--------|------|
| 1 | ✅ | App boots; design system + header/footer; D3 vendored |
| 2 | ⚠️ | 94 tests green (Parser::Modern + Parser::Legacy, 19 parser tests); edge-case unit tests not written |
| 3 | ✅ | Validation rake task + 5 fixture PDFs in test/fixtures/files/ceasa/; core basket 100% |
| 4 | ✅ | Core basket 100% mapped; 234 variants seeded; default_variants set |
| 5 | ✅ | 1,037 bulletins backfilled (769 modern + 268 legacy); 0 core-basket pending; dedup verified |
| 6 | ✅ | Checker renders; per-dozen (eggs) + per-unit verdict modes wired and tested |
| 7 | ⚠️ | `/precos` built; needs QA with live data |
| 8 | ✅ | `/produtos/:slug` minimal page; D3 copied but unwired |
| 9 | ✅ | Daily job + recurring.yml configured; holiday-aware |
| 10 | ❌ | Not deployed |
| 11 | ❌ | Not tested at real feira |

**Overall: ~80% complete** — data layer solid, recurring jobs configured, ready for QA + deploy.

---

## 🔧 Known Open Issues

| Issue | Impact | Priority |
|-------|--------|----------|
| Parser edge-case unit tests not written | No CI gate on parser regression | Post-deploy |
| 4 live "Reddelicious"/"Redglobe" pending matches in 268 legacy bulletins | Column-width drift compresses "Red delicious" in some PDF years; seed has both forms for future re-ingest | Low |
| Mobile QA not done | Layout regressions possible at 375px | Before deploy |
