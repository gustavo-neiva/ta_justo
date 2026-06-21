# Implementation Plan — Historical Price Chart + Seasonality, Link Fixes, Reactive Hotwire Filters

**Project:** Tá Justo? (`/Users/gustavo-neiva/Code/gustavo-neiva/ta_justo`)
**Author:** handoff plan for implementation
**Status:** ready to build
**Estimated surface:** 3 controllers, 3 views, 2 new JS controllers, 1 service, 1 CSS file

---

## 0. Context (read this first)

Tá Justo is a Rails 8 + Hotwire (Turbo + Stimulus) + importmap app. It shows CEASA-RJ
wholesale produce prices and answers "is the price I'm paying fair?". It is a spinoff of a
larger sibling app, **AgroClaro** (`/Users/gustavo-neiva/Code/gustavo-neiva/agroclaro`),
which already has a mature D3 price-chart stack. **We are porting and adapting that stack.**

The database is already populated: **766 bulletins, 151,917 prices, 163 products, 234 variants**,
covering **2023-03-01 → 2026-06-19**. You do NOT need to fetch or seed anything.

D3 is already vendored in `vendor/javascript/` and pinned in `config/importmap.rb`.
All CSS design tokens the chart needs already exist in
`app/assets/stylesheets/design_tokens.css`:
`--color-primary-light` (#2e7d32), `--color-success` (#2e7d32),
`--color-border` (#e0e0e0), `--color-gray-400` (#9ca3af).

### Data model facts you must know

- `Product` has many `Variant`. `Product#default_variant` (a `belongs_to`) points at the
  one variant shown by default. `Product#slug` is the URL key (route is `/produtos/:id`
  where `:id` is the slug; look up with `Product.find_by!(slug: params[:id])`).
- `Variant#pricing_mode` is one of `"per_kg"`, `"per_dozen"`, `"per_unit"`.
  - `per_kg`: use `price.price_per_kg` directly.
  - `per_dozen` (eggs): use `price.modal / 30.0` (CEASA sells "Cx 30 dz"; constant
    `FairPriceVerdict::DOZENS_PER_BOX == 30`). Only rows with `original_unit == "dozen"`.
  - `per_unit` (abacaxi, melancia, etc.): use `price.price_per_kg * variant.avg_weight_kg`.
- `Variant#prices` → `has_many :prices`. A `Price` `belongs_to :bulletin`.
- The **date** of a price lives on `bulletin.price_date` (a `Date`), NOT on the price.
  Always `joins(:bulletin)` and order/filter by `bulletins.price_date`.
- `Price#variation_12m` is a **String** like `"-57,14%"` or `"50,00%"` (Brazilian format,
  comma decimal). Do not do math on it; it is display-only.
- `FairPriceVerdict.new(variant:, paid_amount:)` — the kwarg is **`paid_amount:`**,
  NOT `paid_per_kg:`. Its `Result` struct fields are:
  `verdict` (Symbol `:barato`/`:media`/`:caro`), `ratio` (Float),
  `ceasa_comparable` (Float), `paid_comparable` (Float), `unit_label` (String),
  `percentile_12m` (Integer or nil), `seasonality_note` (currently always nil — we will fill it),
  `explanation` (String), `ceasa_date` (Date), `stale` (Boolean).

### Test commands

```bash
bin/rails runner "puts Bulletin.count"            # => 766
bin/dev                                            # boots server on :3000
# Sample product slugs that exist: tomate, ovo, abacaxi, batata, cebola
```

---

## 1. Goals & acceptance criteria

When done, ALL of these must be true:

1. **Bug fix:** The inline verdict calculator on `/produtos/:slug` works (currently it raises
   `ArgumentError` because the view passes the wrong kwarg). Submitting a price returns a verdict.
2. **Bug fix:** The variant switcher on `/produtos/:slug` actually changes the displayed
   variant (currently `?variant=ID` is ignored).
3. **Feature:** `/produtos/:slug` shows a **historical price line chart** (D3) with an
   **overlaid seasonality curve** (monthly typical price) and a period selector (90 / 365 / Máx).
4. **Feature:** Chart unit matches the product's `pricing_mode` (R$/kg, R$/dúzia, or R$/unidade).
5. **Feature:** `FairPriceVerdict` `seasonality_note` is populated (e.g. "Tomate costuma ser
   mais barato em maio").
6. **Hotwire:** The period selector and variant switcher update **only the chart frame** via a
   Turbo Frame — no full page reload, URL params stay coherent.
7. **Hotwire:** `/precos` has a **reactive, debounced search filter** that updates the price
   list without a hard page reload.
8. All routes return HTTP 200. No JS console errors. Charts render for per_kg, per_dozen,
   and per_unit products.

---

## 2. File-by-file change list (overview)

| Action | File |
|--------|------|
| EDIT | `app/controllers/products_controller.rb` — variant param, chart data, seasonality |
| EDIT | `app/views/products/show.html.erb` — turbo frame, chart, period pills, fix verdict |
| NEW  | `app/views/products/_chart.html.erb` — the turbo-frame partial (chart + stats) |
| NEW  | `app/javascript/controllers/d3_line_chart_controller.js` — ported from AgroClaro |
| EDIT | `app/services/fair_price_verdict.rb` — add `SeasonalityCalculator`, fill `seasonality_note` |
| NEW  | `app/javascript/controllers/list_filter_controller.js` — ported from AgroClaro |
| EDIT | `app/controllers/precos_controller.rb` — accept `?q=` search param |
| EDIT | `app/views/precos/index.html.erb` — filter form + turbo frame around list |
| NEW  | `app/assets/stylesheets/components/chart.css` — chart + pill + tooltip styles |
| EDIT | `app/assets/stylesheets/application.css` — `@import` the new chart.css |

Do the phases in order. After each phase, run `bin/dev` and check the named route.

---

## 3. PHASE 1 — Fix broken links & inline verdict (no charts yet)

### 3.1 Edit `app/controllers/products_controller.rb`

Replace the whole file with this. Key changes vs current: (a) honor `params[:variant]`,
(b) fix the inline verdict kwarg to `paid_amount:`, (c) set `@unit_label` from pricing_mode,
(d) add `@period` + chart/seasonal data (used in Phase 2 — safe to add now).

```ruby
# ProductsController — Product detail page with historical chart
# GET /produtos/:id
# GET /produtos/:id?variant=123&period=365&check_price=8.50
class ProductsController < ApplicationController
  VALID_PERIODS = %w[90 365 all].freeze
  DEFAULT_PERIOD = "365"

  def show
    @product = Product.find_by!(slug: params[:id])

    # Variant selection: honor ?variant=ID, else default_variant
    @variant =
      if params[:variant].present?
        @product.variants.find_by(id: params[:variant]) || @product.default_variant
      else
        @product.default_variant
      end

    unless @variant
      redirect_to root_path, alert: "Produto sem variante configurada"
      return
    end

    @period = VALID_PERIODS.include?(params[:period]) ? params[:period] : DEFAULT_PERIOD
    @unit_label = unit_label_for(@variant)

    @latest_price = latest_price_for(@variant)

    unless @latest_price
      @error = "Nenhum preço encontrado para #{@product.name}"
      @variants = @product.variants.order(:name)
      return
    end

    @price_date = @latest_price.bulletin.price_date
    @stale = (Date.current - @price_date).to_i > FairPriceVerdict::STALE_DAYS

    @stats = build_stats(@variant)
    @variants = @product.variants.order(:name)

    # Chart series (Phase 2 fills these helpers in)
    @chart_data    = ChartSeries.new(@variant, period: @period).points
    @seasonal_data = SeasonalityCalculator.new(@variant).monthly_curve

    run_inline_verdict
  end

  private

  def unit_label_for(variant)
    case variant.pricing_mode
    when "per_dozen" then "dúzia"
    when "per_unit"  then "unidade"
    else                  "kg"
    end
  end

  def latest_price_for(variant)
    variant.prices
           .joins(:bulletin)
           .order("bulletins.price_date DESC")
           .first
  end

  def build_stats(variant)
    recent = variant.prices
                    .where.not(price_per_kg: nil)
                    .joins(:bulletin)
                    .where("bulletins.price_date >= ?", 12.months.ago)
    {
      latest:  @latest_price.price_per_kg&.round(2),
      min_12m: recent.minimum(:price_per_kg)&.round(2),
      max_12m: recent.maximum(:price_per_kg)&.round(2),
      avg_12m: recent.average(:price_per_kg)&.to_f&.round(2)
    }
  end

  def run_inline_verdict
    return if params[:check_price].blank?

    paid = params[:check_price].to_f
    return unless paid.positive?

    @check_price = paid
    @verdict = FairPriceVerdict.new(variant: @variant, paid_amount: paid).call
  rescue => e
    @verdict_error = e.message
  end
end
```

> NOTE: `ChartSeries` and `SeasonalityCalculator` are created in Phase 2 (§4.1, §4.2).
> If you want Phase 1 to boot standalone before Phase 2, temporarily set
> `@chart_data = []` and `@seasonal_data = []` and remove the two `.new(...)` lines,
> then restore them in Phase 2. Recommended: just do Phase 2's §4.1/§4.2 service files
> immediately so the controller references resolve.

### 3.2 Fix the inline-verdict block in `app/views/products/show.html.erb`

Find the `<!-- Inline Verdict Calculator -->` block. The current form input is named
`check_price` (good) but the result rendering uses `@verdict.explanation` and a `case`
on `@verdict.verdict` — that part is fine. The ONLY runtime bug was in the controller
(now fixed in §3.1). However, also update the price label to be unit-aware. Replace the
verdict-result block with:

```erb
      <% if @verdict_error %>
        <p class="verdict-error"><%= @verdict_error %></p>
      <% elsif @verdict %>
        <div class="verdict-result <%= @verdict.verdict %>" style="margin-top: var(--space-md);">
          <div class="verdict-badge <%= @verdict.verdict %>">
            <% case @verdict.verdict %>
            <% when :barato %> ✅ Barato
            <% when :media %>  ➖ Na média
            <% when :caro %>   ⚠️ Caro
            <% end %>
          </div>
          <div class="verdict-price-row">
            <span>Você pagou: <strong>R$ <%= "%.2f" % @verdict.paid_comparable %>/<%= @verdict.unit_label %></strong></span>
            <span>CEASA: <strong>R$ <%= "%.2f" % @verdict.ceasa_comparable %>/<%= @verdict.unit_label %></strong></span>
          </div>
          <div class="verdict-explanation"><%= @verdict.explanation %></div>
        </div>
      <% end %>
```

Also change the form field label from "Preço por kg (R$)" to be unit-aware:

```erb
        <div class="form-group">
          <label for="check_price">Preço por <%= @unit_label %> (R$)</label>
          <input type="number" step="0.01" min="0.01" name="check_price" id="check_price"
                 class="form-control" placeholder="Ex: 8.50" value="<%= params[:check_price] %>">
        </div>
```

Keep the existing `form_with url: product_path(@product.slug), method: :get`. Add a hidden
field so the selected variant persists through the verdict submit:

```erb
      <%= form_with url: product_path(@product.slug), method: :get, class: "checker-form" do |f| %>
        <%= hidden_field_tag :variant, @variant.id %>
```

### 3.3 Fix the variant switcher links in the same view

The current links are `product_path(@product.slug, variant: v.id)` — that is correct now
that the controller (§3.1) reads `params[:variant]`. Just confirm they remain. After Phase 3
we will add `data: { turbo_frame: "product-chart" }` to them.

### 3.4 Phase 1 checkpoint

```bash
bin/dev
# visit http://localhost:3000/produtos/tomate
#   - click a different variant → page shows that variant's name/stats
#   - type 8.50 in "Verificar" → verdict appears (no ArgumentError)
# visit http://localhost:3000/produtos/ovo  (per_dozen) → label says "por dúzia"
```

---

## 4. PHASE 2 — Chart engine + seasonality

### 4.1 NEW service object: chart series — `app/services/chart_series.rb`

This converts a variant's price history into `[{date: "YYYY-MM-DD", price: Float}]`,
respecting `pricing_mode`, for a given period. Create:

```ruby
# Builds the price time-series for a variant's detail chart.
# Returns an array of { date: "YYYY-MM-DD", price: <Float, in the variant's pricing unit> }.
class ChartSeries
  PERIOD_DAYS = { "90" => 90, "365" => 365 }.freeze
  DOZENS_PER_BOX = 30

  def initialize(variant, period: "365")
    @variant = variant
    @period  = period
  end

  def points
    rows = base_scope
    rows = rows.where("bulletins.price_date >= ?", days_back.days.ago) if days_back
    rows.order("bulletins.price_date ASC")
        .map { |p| point_for(p) }
        .compact
  end

  private

  def days_back
    PERIOD_DAYS[@period] # nil for "all"
  end

  def base_scope
    case @variant.pricing_mode
    when "per_dozen"
      @variant.prices.where(original_unit: "dozen").where.not(modal: nil).joins(:bulletin)
    else
      @variant.prices.where.not(price_per_kg: nil).joins(:bulletin)
    end
  end

  def point_for(price)
    value =
      case @variant.pricing_mode
      when "per_dozen" then price.modal.to_f / DOZENS_PER_BOX
      when "per_unit"  then price.price_per_kg.to_f * @variant.avg_weight_kg.to_f
      else                  price.price_per_kg.to_f
      end
    return nil unless value.positive?

    { date: price.bulletin.price_date.iso8601, price: value.round(2) }
  end
end
```

> per_unit requires `avg_weight_kg`. If a per_unit variant has `avg_weight_kg` nil/zero,
> `point_for` returns 0 → filtered out → empty chart (graceful). That's acceptable.

### 4.2 NEW service object: seasonality — `app/services/seasonality_calculator.rb`

Seasonality = the **typical (median) price for each calendar month**, computed across ALL
available years. This is the differentiating feature: it shows whether "now" is a
seasonally cheap or expensive time. We return a curve aligned to the chart's visible window
(one point per month spanning min→max of the actual data), plus a human note.

```ruby
# Computes monthly "typical price" climatology for a variant.
# - monthly_curve: array of { date: "YYYY-MM-15", price: <median for that month> }
#                  spanning the same date range as the chart, so it overlays cleanly.
# - note: human-readable cheapest/most-expensive month sentence (pt-BR).
class SeasonalityCalculator
  DOZENS_PER_BOX = 30
  MONTHS_PT = %w[janeiro fevereiro março abril maio junho
                 julho agosto setembro outubro novembro dezembro].freeze

  def initialize(variant)
    @variant = variant
  end

  # median price per calendar month (1..12), across all years
  def medians_by_month
    @medians_by_month ||= begin
      buckets = Hash.new { |h, k| h[k] = [] }
      each_value_with_date { |month, value| buckets[month] << value }
      buckets.transform_values { |vals| median(vals) }
    end
  end

  # Curve aligned to the actual data's date span, one point mid-month.
  def monthly_curve
    span = date_span
    return [] unless span

    medians = medians_by_month
    return [] if medians.empty?

    points = []
    cursor = Date.new(span.first.year, span.first.month, 15)
    last   = Date.new(span.last.year, span.last.month, 15)
    while cursor <= last
      m = medians[cursor.month]
      points << { date: cursor.iso8601, price: m.round(2) } if m
      cursor = cursor.next_month
    end
    points
  end

  def note
    medians = medians_by_month
    return nil if medians.size < 6 # need most of the year to be meaningful

    cheapest  = medians.min_by { |_m, v| v }&.first
    priciest  = medians.max_by { |_m, v| v }&.first
    return nil unless cheapest && priciest

    "#{@variant.product.name} costuma ser mais barato em #{MONTHS_PT[cheapest - 1]} " \
    "e mais caro em #{MONTHS_PT[priciest - 1]}."
  end

  private

  def each_value_with_date
    rows.find_each do |price|
      value = value_for(price)
      next unless value&.positive?
      yield price.bulletin.price_date.month, value
    end
  end

  def rows
    case @variant.pricing_mode
    when "per_dozen"
      @variant.prices.where(original_unit: "dozen").where.not(modal: nil).joins(:bulletin)
    else
      @variant.prices.where.not(price_per_kg: nil).joins(:bulletin)
    end
  end

  def value_for(price)
    case @variant.pricing_mode
    when "per_dozen" then price.modal.to_f / DOZENS_PER_BOX
    when "per_unit"  then price.price_per_kg.to_f * @variant.avg_weight_kg.to_f
    else                  price.price_per_kg.to_f
    end
  end

  def date_span
    dates = rows.minimum("bulletins.price_date")
    max   = rows.maximum("bulletins.price_date")
    return nil unless dates && max
    [dates, max]
  end

  def median(arr)
    return nil if arr.empty?
    sorted = arr.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
```

### 4.3 Fill `seasonality_note` in `app/services/fair_price_verdict.rb`

In each of the three `Result.new(...)` builders (`call_per_kg`, `call_per_dozen`,
`call_per_unit`), the field is currently `seasonality_note: nil`. Change each to:

```ruby
      seasonality_note: SeasonalityCalculator.new(@variant).note,
```

(There are exactly three occurrences of `seasonality_note: nil` — replace all three.)
No other change to the service.

### 4.4 Port the D3 controller — NEW `app/javascript/controllers/d3_line_chart_controller.js`

Copy the file from AgroClaro **verbatim** as the base, then apply the seasonality additions
below. Source to copy:
`/Users/gustavo-neiva/Code/gustavo-neiva/agroclaro/app/javascript/controllers/d3_line_chart_controller.js`

```bash
cp /Users/gustavo-neiva/Code/gustavo-neiva/agroclaro/app/javascript/controllers/d3_line_chart_controller.js \
   /Users/gustavo-neiva/Code/gustavo-neiva/ta_justo/app/javascript/controllers/d3_line_chart_controller.js
```

Then make these THREE edits to the copied file:

**Edit A — add the `seasonal` value + toggle.** In `static values = { ... }`, add:

```js
    seasonal: { type: Array, default: [] },
    showSeasonal: { type: Boolean, default: true },
```

And add a changed-callback near the other `...ValueChanged()` methods:

```js
  showSeasonalValueChanged() { this.draw() }
  toggleSeasonal(event) { this.showSeasonalValue = event.target.checked }
```

**Edit B — draw the seasonality line.** Inside `draw()`, AFTER the SMA overlay block
(`if (this.showSma30Value) { ... }`) and BEFORE the `// Axes` comment, insert:

```js
    // Seasonality overlay: typical (median) price per calendar month.
    if (this.showSeasonalValue && this.seasonalValue.length > 1) {
      const seasonal = this.seasonalValue
        .map(d => ({ date: new Date(`${d.date}T12:00:00Z`), value: d.price }))
        .filter(d => d.value != null)
      const seasonalLine = d3.line()
        .x(d => xScale(d.date))
        .y(d => yScale(d.value))
        .curve(d3.curveMonotoneX)
      g.append("path")
        .datum(seasonal)
        .attr("fill", "none")
        .attr("stroke", "#b8860b")          // gold — distinct from green price line
        .attr("stroke-width", 2)
        .attr("stroke-dasharray", "8,4")
        .attr("opacity", 0.85)
        .attr("d", seasonalLine)
    }
```

> Why this works: the seasonal points share the same `xScale`/`yScale` as the price line,
> so they overlay on the same axes. We use the visible window's y-domain; seasonal medians
> are in the same magnitude, so they stay on-chart.

**Edit C — none needed** beyond A & B. The despike/gap/crosshair logic is reused as-is.

### 4.5 NEW partial `app/views/products/_chart.html.erb`

This is the turbo-frame partial. It holds the chart + period pills + a legend. It receives
`@chart_data`, `@seasonal_data`, `@variant`, `@unit_label`, `@period`, `@product`, `@stats`.

```erb
<%= turbo_frame_tag "product-chart" do %>
  <!-- Period selector -->
  <div class="chart-controls">
    <div class="pill-selector">
      <% [["90", "90 dias"], ["365", "1 ano"], ["all", "Máx"]].each do |value, label| %>
        <%= link_to label,
              product_path(@product.slug, variant: @variant.id, period: value),
              data: { turbo_frame: "product-chart" },
              class: "pill-option#{' active' if @period == value}" %>
      <% end %>
    </div>
  </div>

  <% if @chart_data.size >= 5 %>
    <div class="chart-card"
         data-controller="d3-line-chart"
         data-d3-line-chart-data-value="<%= @chart_data.to_json %>"
         data-d3-line-chart-seasonal-value="<%= @seasonal_data.to_json %>"
         data-d3-line-chart-unit-value="<%= @unit_label %>"
         data-d3-line-chart-curve-type-value="curveMonotoneX">
      <div class="chart-legend">
        <span class="legend-item"><span class="legend-swatch legend-price"></span>Preço CEASA (R$/<%= @unit_label %>)</span>
        <span class="legend-item"><span class="legend-swatch legend-seasonal"></span>Típico do mês (mediana histórica)</span>
        <label class="legend-toggle">
          <input type="checkbox" checked data-action="change->d3-line-chart#toggleSeasonal">
          Mostrar sazonalidade
        </label>
      </div>
      <div data-d3-line-chart-target="chart" style="position: relative;"></div>
    </div>
  <% else %>
    <div class="empty-state chart-empty">
      <p>Dados insuficientes para gerar o gráfico desta variante.</p>
    </div>
  <% end %>
<% end %>
```

### 4.6 Wire the partial into `app/views/products/show.html.erb`

Insert the chart between the stats grid (`product-header-stats`) and the variant selector.
Find the closing `</div>` of `product-header-stats` and add right after it:

```erb
    <!-- Historical price chart -->
    <%= render "chart" %>
```

Leave the existing stat cards, variant selector, and verdict calculator as they are
(verdict already fixed in Phase 1).

### 4.7 NEW `app/assets/stylesheets/components/chart.css`

```css
/* ── Chart card ───────────────────────────────────────────── */
.chart-card {
  background: var(--color-background, #fff);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg, 12px);
  padding: var(--space-md, 16px);
  margin: var(--space-lg, 24px) 0;
}
.chart-empty { margin: var(--space-lg, 24px) 0; }

/* ── Period pill selector ─────────────────────────────────── */
.chart-controls { margin: var(--space-md, 16px) 0; }
.pill-selector { display: inline-flex; gap: 4px; background: var(--color-border-light, #f0f0f0); padding: 4px; border-radius: 999px; }
.pill-option {
  padding: 6px 14px; border-radius: 999px; font-size: 0.875rem;
  color: var(--color-text-secondary, #555); text-decoration: none; transition: all 0.15s;
}
.pill-option.active { background: var(--color-primary-light, #2e7d32); color: #fff; }

/* ── Legend ───────────────────────────────────────────────── */
.chart-legend { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-md, 16px); margin-bottom: var(--space-sm, 8px); font-size: 0.8125rem; color: var(--color-text-secondary, #555); }
.legend-item { display: inline-flex; align-items: center; gap: 6px; }
.legend-swatch { width: 18px; height: 3px; border-radius: 2px; display: inline-block; }
.legend-price { background: var(--color-primary-light, #2e7d32); }
.legend-seasonal { background: repeating-linear-gradient(90deg, #b8860b 0 6px, transparent 6px 9px); }
.legend-toggle { display: inline-flex; align-items: center; gap: 6px; cursor: pointer; }

/* ── D3 tooltip (used by d3_line_chart_controller) ────────── */
.d3-tooltip {
  position: absolute; pointer-events: none; background: rgba(33, 33, 33, 0.92);
  color: #fff; padding: 6px 10px; border-radius: 6px; font-size: 0.75rem;
  line-height: 1.4; white-space: nowrap; z-index: 10;
}
```

### 4.8 Import the CSS — edit `app/assets/stylesheets/application.css`

Add an import line alongside the other component imports (match existing `@import` syntax in
that file — open it first to copy the exact pattern, e.g. `@import "components/chart.css";`).

### 4.9 Phase 2 checkpoint

```bash
bin/dev
# http://localhost:3000/produtos/tomate    → green price line + gold dashed seasonal line
# click "90 dias" / "Máx"                    → ONLY the chart frame reloads, line redraws
# http://localhost:3000/produtos/ovo         → chart in R$/dúzia, legend says "/dúzia"
# http://localhost:3000/produtos/abacaxi     → chart in R$/unidade
# Hover the line                              → crosshair + tooltip with date + R$
# Uncheck "Mostrar sazonalidade"              → gold line disappears
# Browser console: zero errors
```

> If the chart is blank: open console. Common causes: (a) `@chart_data` empty → check the
> variant has price_per_kg rows; (b) JSON not parsed → ensure `.to_json` (not `.to_s`) in the
> `data-...-value` attribute; (c) d3 import error → confirm `pin "d3"` in importmap and that
> `import * as d3 from "d3"` resolves (it does for AgroClaro with the same vendored files).

---

## 5. PHASE 3 — Reactive Hotwire on variant switcher + /precos filter

### 5.1 Make the variant switcher target the chart frame

In `app/views/products/show.html.erb`, the variant links currently are:

```erb
<%= link_to v.name, product_path(@product.slug, variant: v.id),
    class: "variant-link #{'active' if v.id == @variant.id}" %>
```

Switching a variant changes BOTH the chart and the stat cards. The stat cards are OUTSIDE
the `product-chart` frame, so a frame-only swap would leave stale stats. Two options —
**choose Option A (simpler, correct):**

- **Option A (recommended):** Let the variant links do a normal full navigation (no
  `turbo_frame`). They already work after Phase 1. The chart re-renders with the new
  variant on full load. Period pills (inside the frame) stay frame-scoped and snappy.
  → No change needed here; just confirm the links carry `period: @period` so the chosen
  period survives a variant switch:

  ```erb
  <%= link_to v.name, product_path(@product.slug, variant: v.id, period: @period),
      class: "variant-link #{'active' if v.id == @variant.id}" %>
  ```

- **Option B (advanced, optional):** Wrap stats + chart together in one larger turbo frame
  and point variant links at it. More work, marginal benefit. Skip unless time allows.

> The period pills (§4.5) already use `data: { turbo_frame: "product-chart" }`. Because they
> only change the chart (stats are period-independent — they're fixed 12m windows), a
> frame-only swap is correct and is the idiomatic Hotwire pattern here.

### 5.2 Port `list_filter_controller.js` — NEW file

```bash
cp /Users/gustavo-neiva/Code/gustavo-neiva/agroclaro/app/javascript/controllers/list_filter_controller.js \
   /Users/gustavo-neiva/Code/gustavo-neiva/ta_justo/app/javascript/controllers/list_filter_controller.js
```

No edits needed — it's self-contained. It debounces input and calls
`Turbo.visit(url + "?" + params, { action: "replace" })`. Stimulus auto-registers it via
`eagerLoadControllersFrom` (see `app/javascript/controllers/index.js` — already present).

### 5.3 Add `?q=` search to `app/controllers/precos_controller.rb`

In `PrecosController#index`, after computing `@sections`, add a server-side name filter when
`params[:q]` is present. The simplest correct approach: filter the grouped products by name.
Inside the `(1..6).each` loop, after building `products_with_prices`, apply:

```ruby
      if params[:q].present?
        term = params[:q].to_s.downcase
        products_with_prices = products_with_prices.select do |product, _prices|
          product.name.downcase.include?(term)
        end
      end
      next if products_with_prices.empty?
```

(Place the `next if products_with_prices.empty?` check AFTER this filter so empty sections
are hidden when a search excludes them. Remove/replace the earlier `next if section_prices.empty?`
only if it now double-guards — keep both guards; they're harmless.)

### 5.4 Add the reactive filter UI to `app/views/precos/index.html.erb`

Wrap the price list in a turbo frame and add a search form above it. Replace the
`<div class="price-sections"> ... </div>` region so it is wrapped, and add the form before it.
Insert just after the `</div>` that closes `.page-header`:

```erb
  <%= form_with url: precos_path, method: :get, class: "precos-filter",
        data: { controller: "list-filter",
                list_filter_url_value: precos_path } do %>
    <input type="search" name="q" value="<%= params[:q] %>"
           placeholder="Buscar produto…" class="form-control"
           data-list-filter-target="searchInput"
           data-action="input->list-filter#debouncedSubmit">
  <% end %>
```

Then wrap the existing sections list in a frame so the debounced `Turbo.visit` swaps only it.
Change the opening of the results region from `<div class="price-sections">` to:

```erb
  <%= turbo_frame_tag "precos-list" do %>
    <div class="price-sections">
      <%# ... existing section-rendering loop unchanged ... %>
    </div>
  <% end %>
```

> Important Hotwire detail: `Turbo.visit(..., { action: "replace" })` does a full-page visit
> but Turbo will morph/replace matching frames. For the list to update without the whole page
> flashing, the `precos-list` frame on the destination page must have the same id (it does,
> since it's the same template). This mirrors AgroClaro's working pattern. Keep the search
> input OUTSIDE the `precos-list` frame so it doesn't lose focus on swap.

### 5.5 Minor CSS for the filter (append to `chart.css` or `domain/ta_justo.css`)

```css
.precos-filter { margin: var(--space-md, 16px) 0; }
.precos-filter .form-control { max-width: 360px; width: 100%; }
```

### 5.6 Phase 3 checkpoint

```bash
bin/dev
# http://localhost:3000/precos
#   - type "tom" → list narrows to Tomate-matching products without a hard reload
#   - clear the box → full list returns
#   - input stays focused while typing (not stolen by the swap)
# http://localhost:3000/produtos/tomate
#   - switch variant → stats + chart both reflect the new variant; chosen period persists
```

---

## 6. PHASE 4 — Full verification

Run each and confirm HTTP 200 + no console errors:

```bash
bin/rails runner "%w[tomate ovo abacaxi batata cebola].each { |s| puts s + ': ' + (Product.find_by(slug: s) ? 'ok' : 'MISSING') }"
```

Manual matrix (open each, watch the browser console):

| URL | Expect |
|-----|--------|
| `/` | checker loads; submit tomate + 12.00 → "Barato" |
| `/precos` | sections render; search "tom" narrows reactively |
| `/produtos/tomate` | green line + gold seasonal dashed; period pills swap frame only |
| `/produtos/ovo` | chart + legend in R$/dúzia |
| `/produtos/abacaxi` | chart in R$/unidade |
| `/produtos/tomate` inline verdict | type 8.50 → verdict renders, no ArgumentError |
| variant switch on a multi-variant product | stats + chart update; period kept |
| `/sobre` | static page, links work |

Also confirm `FairPriceVerdict` note appears: on `/` after a verdict, the explanation
or a seasonality line should now be populatable (the struct field is filled; surface it in
the checker view if desired — optional stretch, not required).

---

## 7. Guardrails / do-NOT list

- Do **not** modify the database, seeds, migrations, or any `db/` file. Data is final.
- Do **not** change `FairPriceVerdict`'s public API (`new(variant:, paid_amount:)`); only
  fill the three `seasonality_note:` fields (§4.3).
- Do **not** add new gems or npm packages. D3 is already vendored + pinned.
- Do **not** rename existing routes or `*_path` helpers. `sobre_path`, `precos_path`,
  `product_path`, `root_path` all already work.
- Keep all UI copy in **Brazilian Portuguese** to match the existing app.
- Use the existing CSS design tokens (`var(--color-*)`); do not hardcode hex except the
  seasonal gold `#b8860b` (intentional, has no token).
- Each phase must boot and pass its checkpoint before starting the next.

---

## 8. Quick reference — where things live

- AgroClaro D3 line chart (source to copy): `agroclaro/app/javascript/controllers/d3_line_chart_controller.js`
- AgroClaro list filter (source to copy): `agroclaro/app/javascript/controllers/list_filter_controller.js`
- AgroClaro reference usage of chart in a view: `agroclaro/app/views/prices/show.html.erb` (lines ~218–256)
- Tá Justo importmap (d3 already pinned): `ta_justo/config/importmap.rb`
- Tá Justo Stimulus registration (auto-loads new controllers): `ta_justo/app/javascript/controllers/index.js`
- Tá Justo design tokens: `ta_justo/app/assets/stylesheets/design_tokens.css`
- Verdict service: `ta_justo/app/services/fair_price_verdict.rb`
```
