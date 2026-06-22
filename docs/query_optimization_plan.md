# Query Optimization Plan — Product & Check Pages

**Goal:** Eliminate the N+1 query floods triggered while rendering `products#show` and
`checks#show`, and stop redundant recomputation of the variant price series. Outputs
must stay byte-identical — this is pure query optimization, **no behavior change**.

**Target impact:** `products#show` goes from ~1,500+ queries to single digits.

---

## Background: where the queries come from

Each variant has ~750 `Price` rows spread across ~750 `Bulletin`s. Three services scan a
variant's full price history, and several of them re-scan it multiple times per request.

### Hotspot A — `SeasonalityCalculator#each_value_with_date`
File: `app/services/seasonality_calculator.rb:58-64`

```ruby
def each_value_with_date
  rows.find_each do |price|
    value = value_for(price)
    next unless value&.positive?
    yield price.bulletin.price_date.month, value   # <-- line 60: lazy-loads bulletin per row
  end
end
```

`rows` (lines 66-73) does `joins(:bulletin)` but **never preloads** it. `price.bulletin`
therefore fires one `Bulletin Load ... WHERE id = ?` per row → the flood of
`WHERE "bulletins"."id" = 766/767/768...` in the log.

### Hotspot B — `Variant#representative_series`
File: `app/models/variant.rb:37-46`

```ruby
def representative_series(months: nil)
  scope = prices.joins(:bulletin)
  scope = scope.where("bulletins.price_date >= ?", months.months.ago) if months
  scope = scope.where(original_unit: "dozen") if pricing_mode == "per_dozen"
  scope = scope.where.not(price_per_kg: nil) unless pricing_mode == "per_dozen"

  bulletin_ids = scope.distinct.order("bulletins.price_date ASC").pluck("bulletins.id")  # line 42
  Bulletin.where(id: bulletin_ids).order(:price_date).filter_map do |b|                  # line 43
    representative_price(bulletin: b)                                                     # calls per-bulletin query
  end
end
```

`representative_price(bulletin:)` (`app/models/variant.rb:27-33`) runs
`prices.where(bulletin: bulletin)...` **once per bulletin** → the flood of
`Price Load ... WHERE bulletin_id = 8/686/685...` in the log. That's ~750 queries.

### Hotspot C — `ChartSeries#point_for`
File: `app/services/chart_series.rb:38-49`

`base_scope` (lines 28-35) does `joins(:bulletin)` without preload; `point_for` reads
`price.bulletin.price_date.iso8601` (line 47) → same N+1 as Hotspot A.

### Hotspot D — redundant recomputation per request
File: `app/controllers/products_controller.rb`

`representative_series` is recomputed ~4× per `products#show`, each time re-running the
full Hotspot B cascade:
1. `@variant.latest_price` (line 35) → `representative_series.last` (`variant.rb:50`) —
   builds the **entire unbounded** series just to take `.last`.
2. `build_stats(@variant)` (line 48) → `variant.representative_series(months: 12)`
   (`products_controller.rb:82`).
3. `FairPriceVerdict#comparable_series` (`fair_price_verdict.rb:202`) →
   `representative_series(months: 12)`.
4. `FairPriceVerdict#latest_representative_bulletin` (`fair_price_verdict.rb:212`) →
   `representative_series.last` (unbounded again).

### Existing indexes (from `db/schema.rb`)
- `prices`: `index_prices_on_bulletin_id`, `index_prices_on_price_per_kg`,
  `index_prices_on_variant_id`, `idx_prices_unique(variant_id, bulletin_id, raw_unit)`.
- `bulletins`: `idx_bulletins_unique(market, price_date)`.

The per-bulletin lookups are already covered by `idx_prices_unique`; the problem is the
**number** of queries, not per-query speed.

---

## Step 1 — Rewrite `Variant#representative_series` to a single query (biggest win)

**File:** `app/models/variant.rb:37-46`

Replace the pluck-then-loop with one eager-loaded query, then group and pick the
representative row in Ruby. The selection rule must stay identical to
`representative_price` / `representative_dozen_row` so outputs don't change.

```ruby
def representative_series(months: nil)
  scope = prices.includes(:bulletin).joins(:bulletin)
  scope = scope.where("bulletins.price_date >= ?", months.months.ago) if months
  if pricing_mode == "per_dozen"
    scope = scope.where(original_unit: "dozen")
  else
    scope = scope.where.not(price_per_kg: nil)
  end

  scope.order("bulletins.price_date ASC")
       .group_by(&:bulletin_id)
       .map { |_bulletin_id, rows| pick_representative(rows) }
       .compact
       .sort_by { |price| price.bulletin.price_date }
end
```

Add a private helper that mirrors the existing in-memory selection rules
(`variant.rb:27-33` for the per_kg/per_unit branch, `variant.rb:60-62` for per_dozen):

```ruby
private

def pick_representative(rows)
  if pricing_mode == "per_dozen"
    rows.select { |p| p.original_unit == "dozen" }.min_by(&:id)
  else
    rows.select { |p| p.price_per_kg }
        .min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
  end
end
```

**Why this is equivalent:**
- Old per_kg path: `representative_price` filters `where.not(price_per_kg: nil)` then
  `min_by { [PackSize.kg(raw_unit) || INFINITY, id] }` — identical to `pick_representative`.
- Old per_dozen path: `representative_dozen_row` does
  `where(original_unit: "dozen").order(:id).first` — identical to `min_by(&:id)` over the
  dozen rows.
- The `scope` filter already restricts rows to `dozen` / non-nil `price_per_kg`, so the
  in-Ruby `select` is belt-and-suspenders but harmless.

**Result:** ~750 queries → **2** (one `prices` load, eager-loaded bulletins batched).

`PackSize` is already available (`app/services/pack_size.rb`) — pure function, no require
needed under Rails autoloading.

---

## Step 2 — Add a cheap dedicated `latest_price`

**File:** `app/models/variant.rb:49-51`

Today `latest_price` calls `representative_series.last`, which builds the **entire
unbounded** series. Replace with a query that finds only the latest usable bulletin, then
picks the representative row for just that one bulletin.

```ruby
def latest_price
  scope = prices.joins(:bulletin)
  if pricing_mode == "per_dozen"
    scope = scope.where(original_unit: "dozen")
  else
    scope = scope.where.not(price_per_kg: nil)
  end

  latest_bulletin_id = scope.order("bulletins.price_date DESC").limit(1).pick("prices.bulletin_id")
  return nil unless latest_bulletin_id

  representative_price(bulletin: Bulletin.find(latest_bulletin_id))
end
```

This removes two unbounded full-series builds per request (Hotspot D items 1 & 4).
`representative_price` already loads only the rows for that single bulletin via
`idx_prices_unique`.

> Note: `FairPriceVerdict#latest_representative_bulletin` (`fair_price_verdict.rb:209-213`)
> also calls `representative_series.last`. After Step 4's memoization that becomes cheap;
> alternatively change it to `@variant.latest_price&.bulletin` for the same result.

---

## Step 3 — Memoize `representative_series` per request

**File:** `app/models/variant.rb`

Memoize keyed by the `months` argument so repeated calls within one request reuse the
result instead of re-querying (Hotspot D items 2 & 3 collapse into one).

```ruby
def representative_series(months: nil)
  @representative_series ||= {}
  @representative_series[months] ||= begin
    # ... body from Step 1 ...
  end
end
```

This is request-scoped (the `@variant` instance lives for one request). No cross-request
staleness risk.

---

## Step 4 — Kill N+1 in `SeasonalityCalculator`

**File:** `app/services/seasonality_calculator.rb:58-64` and `66-73`

Preload the bulletin so `price.bulletin.price_date` (line 60) doesn't lazy-load per row.
Change `rows` to include the association:

```ruby
def rows
  case @variant.pricing_mode
  when "per_dozen"
    @variant.prices.where(original_unit: "dozen").where.not(modal: nil).includes(:bulletin)
  else
    @variant.prices.where.not(price_per_kg: nil).includes(:bulletin)
  end
end
```

Then `each_value_with_date` can iterate without firing per-row queries. Note: `find_each`
ignores ordering and batches by PK; with `includes` it still works but Rails may warn. If
the dataset is small enough (~750 rows), switch `find_each` to `each`:

```ruby
def each_value_with_date
  rows.each do |price|
    value = value_for(price)
    next unless value&.positive?
    yield price.bulletin.price_date.month, value
  end
end
```

**Also note `date_span` (`seasonality_calculator.rb:84-89`)** runs two extra aggregate
queries (`minimum`/`maximum`). These are cheap (indexed) and fine to leave, but if
desired they can be derived from the already-loaded `rows` in memory.

**Result:** ~750 `Bulletin Load` queries → **1**.

---

## Step 5 — Kill N+1 in `ChartSeries`

**File:** `app/services/chart_series.rb:28-35`

Add `.includes(:bulletin)` to `base_scope` so `point_for`'s `price.bulletin.price_date`
(line 47) doesn't fire per-row:

```ruby
def base_scope
  case @variant.pricing_mode
  when "per_dozen"
    @variant.prices.where(original_unit: "dozen").where.not(modal: nil).includes(:bulletin)
  else
    @variant.prices.where.not(price_per_kg: nil).includes(:bulletin)
  end
end
```

`points` (lines 16-22) keeps `.order("bulletins.price_date ASC")`. Because the order
references the bulletins table, keep the `joins` too:
`...includes(:bulletin).joins(:bulletin)` — `includes` alone won't reliably add the join
for the string order clause. Use both to be safe.

**Result:** ~750 `Bulletin Load` queries → **1**.

---

## Step 6 — Pass the 12m series into stats & verdict (optional, after Steps 1-5)

**Files:** `app/controllers/products_controller.rb:81-98`, `app/services/fair_price_verdict.rb`

With Step 3's memoization the redundant recomputation is already gone. This step is only
worth doing if profiling still shows duplicate work. If pursued: compute
`series = @variant.representative_series(months: 12)` once in the controller and thread it
through `build_stats` and the verdict rather than each calling `representative_series`
again. Lower priority — defer unless needed.

---

## Step 7 — Supporting DB index (optional, measure first)

The dominant `DISTINCT ... WHERE variant_id = ? AND price_per_kg IS NOT NULL` filter in
the old code disappears after Step 1. The remaining queries are covered by existing
indexes (`index_prices_on_variant_id`, `idx_prices_unique`). **Do not add new indexes
speculatively.** If after Steps 1-5 a slow query remains, consider a composite
`prices(variant_id, price_per_kg)` index via a migration — but profile first.

---

## Verification

1. **Query count.** Reload `products#show` (e.g. `/produtos/<slug>?variant=2`) and
   `checks#show` (`/?product=<slug>&price=18.50`). Confirm the `Bulletin Load` and
   `Price Load` floods are gone — expect single-digit queries, not hundreds. Use the
   Rails log or `rack-mini-profiler` / `ActiveSupport::Notifications` to count.

2. **Output parity (critical).** The in-memory `pick_representative` must select the exact
   same rows as the old per-bulletin queries. Run the existing test suite:
   ```bash
   bin/rails test
   # or
   bundle exec rspec
   ```
   Pay special attention to tests covering `Variant#representative_series`,
   `Variant#representative_price`, `Variant#latest_price`, `FairPriceVerdict`,
   `SeasonalityCalculator`, `ChartSeries`, and `MarketTiming`.

3. **Spot-check a per_dozen variant** (eggs) and a `per_unit` variant (abacaxi/melancia)
   in addition to a `per_kg` variant, since each pricing mode takes a different branch in
   `pick_representative`.

---

## Implementation order (recommended)

1. Step 1 — `representative_series` single-query rewrite + `pick_representative` helper.
2. Step 3 — memoize `representative_series`.
3. Step 2 — cheap `latest_price`.
4. Step 4 — `SeasonalityCalculator` preload.
5. Step 5 — `ChartSeries` preload.
6. Run verification (query count + full test suite).
7. Steps 6 & 7 only if profiling still shows hotspots.

Each step is independently shippable and individually testable. Steps 1-5 carry the
entire win; 6-7 are conditional.
