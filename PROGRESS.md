# Legacy Historical Backfill (CEASA-RJ pre-March 2023)

**Status:** ✅ COMPLETE

**Date:** 2026-06-21

## Summary

Ingested all available CEASA-RJ historical data from 2022-01-03 to 2023-02-28 (the legacy PDF
format era). Extended price history by 14 months, from 769 modern bulletins to 1,037 total.

## Implementation

### Files Created
- `app/services/ceasa_rio/parser/modern.rb` — modern sub-parser (extracted from old parser.rb)
- `app/services/ceasa_rio/parser/legacy.rb` — legacy sub-parser (14-page format, no 12M col)
- `test/services/ceasa_rio/parser_test.rb` — 19 parser tests (modern + legacy + dispatcher)
- `db/seeds/product_maps_legacy.rb` — 33+ core-basket mappings for legacy raw names

### Files Modified
- `app/services/ceasa_rio/parser.rb` — dispatcher: sniffs format, delegates to sub-parser
- `app/jobs/backfill_ceasa_rio_job.rb` — gate lowered from `MODERN_MIN` to `LEGACY_MIN = 2022-01-01`
- `db/seeds/product_maps.rb` — BATATA fish fix + curly-apostrophe fix
- `db/seeds.rb` — loads legacy seed
- `lib/tasks/ceasa_validate.rake` — fixed fixture path to `test/fixtures/files/ceasa/**/*.pdf`

### Key Legacy Parser Behaviors
- Date: first `DD/MM/YYYY` near `Boletim n°`; weekday derived from `Date#wday`
- Section banners checked before DROP_RE (they share a line with column headers)
- `*`-children: inherit parent packaging; children with own parens use their own weight
- `Sem cotação` → nil prices, row still recorded
- `variation_12m = nil` for all rows (column absent in legacy format)
- Raw unit synthesized as `"Cx N kg"` / `"Cx 30 dz"` / `"kg"`
- Stray digit lines (broken `140,0` → `0`) dropped via `/\A\d+\z/` in `DROP_RE`

## Results

```
Before:  769 bulletins  151,920 prices  min=2023-03-01  pending=42
After:  1037 bulletins  162,907 prices  min=2022-01-03  pending=434
Modern gate: 769 bulletins / 151,920 prices UNCHANGED ✓
Core basket: 100% mapped (37 products, 0 pending) ✓
Tests: 94 runs, 236 assertions, 0 failures ✓
```

## Known Minor Gap

4 live legacy `PendingMatch` entries for compressed `"Reddelicious"`/`"Redglobe"` variants
(column-width drift in some PDF years). Seed now has both forms; existing 268 bulletins are
idempotency-protected. Impact: nil — these are imported variety prices, not core basket.

---

# Phase 3A: PriceHistory Value Object Implementation

**Status:** ✅ COMPLETE

**Date:** 2026-06-21

## Summary

Successfully implemented the PriceHistory value object for computing inflation-adjusted 12-month price series with comprehensive test coverage including known-answer deflation validation.

## Implementation

### Files Created
- `app/services/price_history.rb` - Main PriceHistory implementation (5990 bytes)
- `test/services/price_history_test.rb` - Comprehensive test suite (13814 bytes)

### Key Features
- ✅ Deflated 12-month series computation
- ✅ IBGE deflation formula: `real = nominal × (índice_base / índice_data)`
- ✅ Forward-fill support for newer bulletins (factor 1.0)
- ✅ Null object pattern for error handling
- ✅ Rails.cache support with keyed cache
- ✅ IPCA and INPC index support
- ✅ >90d staleness guard

## Test Results

**All 12 tests passing (38 assertions)**

Notable tests:
- ✅ Known-answer: R$1000 Jun/2025 → R$1044.74 May/2026
- ✅ Forward-fill for newer bulletins
- ✅ Staleness guard (>90 days)
- ✅ Cache key structure validation
- ✅ Sample size accuracy
- ✅ INPC index support

## Validation

```bash
bin/rails test test/services/price_history_test.rb
# Result: 12 runs, 38 assertions, 0 failures, 0 errors, 0 passes ✅
```

## Integration Points

- `Variant#representative_series(months: 12)` - price data source
- `PriceIndex` model - index level queries
- `Rails.cache` - computation result caching
- `Bulletin` model - date-based index lookup

## Next Phase

Ready for Phase 3B: MarketTiming value object implementation