# Plan — Redesign the `/precos` Index Page

Goal: make the today's-prices index **scannable, honest, and mobile-first** while
staying beautiful on desktop. Fix the two concrete defects the screenshot exposes,
then layer on the Apple-style polish.

Status: PLAN ONLY — no implementation yet.

---

## 1. The two real bugs (must fix)

### 1.1 The "Banana" identity bug — variants masquerade as separate fruits

**Symptom (from screenshot):** Under *Frutas Nacionais* we see
`Banana / Da Terra`, then bare rows `Figo`, `Maçã Extra`, `Ouro`, `Prata Extra`,
`Nanica/D'Água Extra`. A shopper reads "Figo" as fig and "Maçã Extra" as apple.
They are **all Banana variants** (confirmed in DB:
`Da Terra, Figo, Maçã Extra, Nanica/D'Água Extra, Ouro, Pacovan, Prata Extra`).

**Root cause** — `app/views/precos/index.html.erb`:
```erb
<% if idx == 0 %><%= product.name %><% end %>      # name printed ONCE
<% if prices.size > 1 %><span class="variant-label"><%= variant_label %></span><% end %>
```
After the first row the product name is dropped, so each subsequent variant line
shows only its `variant.name` ("Figo") with no "Banana" anchor. The eye loses the
grouping the moment a row wraps or you scroll past the first line.

**Fix direction — group, don't repeat-then-drop.** Render multi-variant products as a
visually bound cluster so every banana is unmistakably a banana:

- A **product group header row**: `🍌 Banana` (name once, bold, full width), with a
  small count chip `7 tipos`.
- **Indented variant sub-rows** beneath it, each showing `variant.name` + price +
  tag, with a left rule/inset so they read as children, not siblings.
- Single-variant products (Abacate, Abacaxi) stay as a normal one-line row — no
  empty header.
- Never emit a price row whose only label is a variant name with no parent in view.

This also kills the current ambiguity where `idx==0` couples "first row" to "show
name" — the grouping becomes structural, not positional.

### 1.2 "Var. 12 meses" is the wrong signal

**Symptom:** the third column shows the raw `price.variation_12m` string straight
from the PDF (e.g. `-21,25%`, `1650,00%`, `23,83%`). Problems:
- It's **nominal** (not inflation-adjusted), so it conflates real price moves with
  currency drift.
- It's a point-to-point delta (today vs ~today-1yr), wildly noisy →
  `Caqui Fuyu 1650,00%` is meaningless to a shopper.
- It answers a question nobody asked. The shopper wants: **"is now a good time to
  buy this?"** not "what's the YoY tick?".

**Fix direction — replace the column with a Market Timing tag.** The domain already
defines and computes this (`MarketTiming`, `CONTEXT.md` §Market Timing):
- Buckets: **época barata** (≤33rd pct) · **preço normal** · **época cara** (≥67th).
- Computed against the deflated (real-terms) trailing-12-month distribution.
- Labels/emoji already exist in `application_helper.rb` (`timing_label`,
  `timing_emoji`) and styling exists (`timing-bucket--cheap/normal/expensive`).

New column header: **"Época"** (or "Momento"), value = a pill:
`📉 Época barata` / `📊 Preço normal` / `📈 Época cara`.

---

## 2. The data-availability blocker (decide before building 1.2)

`MarketTiming` requires **≥30 deflated samples**. A live check today returned
**0 of 117 shown variants** qualifying (richest variant has only 11 samples; most
have far fewer; `PriceIndex` has a single row). So if we naively swap the column,
**every tag renders blank** and the page looks broken.

We must pick a tiering strategy. Proposed graceful-degradation ladder, best signal
first, each row uses the strongest tier it qualifies for:

1. **Market Timing** (≥30 real-terms samples) → full época tag. *Truest signal.*
2. **Seasonality** (`SeasonalityCalculator`, needs ~6 of 12 months) → "época" tag
   derived from where the current month sits vs the monthly-median climatology
   (cheapest-month / priciest-month). Cheaper data bar; honest as "tipicamente".
3. **Thin history** → **no tag**, show a quiet `—` or nothing (never a fake pill).
   Optionally a tiny muted "sem histórico" only on hover/detail, not inline noise.

Decision needed from user: ship 1.2 **now with seasonality fallback** (most rows get
*a* tag), or ship **timing-only** and accept many blanks until backfill deepens
history. Recommendation: **seasonality fallback**, clearly labelled, because an index
page with mostly-empty tags fails the "more efficient" goal.

> Note: this is consistent with AGENTS.md — "history is SECONDARY, holes acceptable".
> We must therefore make the UI *degrade gracefully*, not depend on full history.

---

## 3. Performance (it's an index page — make it efficient)

Current controller already does the right joins/includes, but the **new tag column
would trigger `MarketTiming.compute` per variant** (117× per request) — each walking
`PriceHistory` + percentile. That's an N+1 storm.

Plan:
- **Precompute timing/seasonality offline.** Add a nightly job (alongside the
  existing CEASA fetch / `RefreshPriceIndices`) that computes each variant's current
  bucket and writes it to a cheap column or cache (`variants.timing_bucket`,
  `variants.timing_source`, `variants.timing_computed_at`), keyed to the latest
  bulletin + index month. The page then reads a column, zero per-request compute.
- Reuse the existing cache keys (`MarketTiming#build_cache_key` already versions on
  bulletin + index month) so invalidation is automatic when a new bulletin lands.
- Keep the controller query shape; just `.includes` the precomputed field.
- Target: index render does **no** history math.

---

## 4. UI / visual redesign (Apple HIG + high-density references)

References pulled: Apple HIG *Lists and tables* (grouped inset tables), and the
Stripe/Linear density principle — *"density is a feature, not a default; typography
is the hierarchy anchor; restrained colour; deliberate hover/focus."*

### 4.1 Layout model — grouped inset list (Apple "grouped" table)
- Each **section** (Frutas Nacionais, etc.) = a grouped card (already close to
  current `.price-section`). Keep the section count chip.
- Inside, **two row archetypes**:
  - *Product row* (single-variant): name · price · época tag.
  - *Product group* (multi-variant): header (name + count) → inset variant rows.
- Use a subtle left inset/rule on variant sub-rows (Apple-style hanging indent), not
  a heavy border. Hierarchy via indentation + weight, not boxes-in-boxes.

### 4.2 Information hierarchy per row (the anchor is typography)
- **Product/variant name**: primary weight, `--color-text`. Variant names slightly
  lighter/smaller under their group.
- **Price**: tabular-nums, semibold, right-aligned, `--color-primary`. Add
  `font-variant-numeric: tabular-nums` so columns align (currently they don't).
- **Época tag**: the only place colour is allowed to "speak" — green (barata),
  neutral grey (normal), warm/orange (cara). Reuse `timing-bucket--*` tokens.
- Drop the loud red/green percentage chips entirely (they were the noisy
  `variation_12m`). Colour now carries *one* meaning: buy-timing.

### 4.3 Density
- Tighten row vertical padding on mobile (comfortable ~44px tap target min per HIG,
  but no wasted space). Compact by default; the data is the point.
- Right-align the two numeric/tag columns; keep a stable 3-column grid
  `name | price | época` that collapses gracefully.

### 4.4 Mobile-first, desktop-beautiful
- **Mobile (default):** single column, full-width section cards, sticky search,
  época tag wraps under price if width is tight (stacked price/tag cell). 16px+ font.
- **Tablet/desktop (`@media min-width: 768px`):** widen container (current
  `max-width: 960px` ok), keep generous gutters, hover state lifts row bg
  (`--color-background-tertiary`), align tags into a clean column. Consider 2-up
  section columns only if it doesn't break grouping legibility (probably keep 1
  column for scanability — Apple keeps tables single-column).
- Sticky **section headers** and the **search box** on scroll so context never
  leaves the viewport on a long list.

### 4.5 Search & affordances (already partially there)
- Keep `list-filter` Stimulus debounce search. Make the empty/zero-result state and
  the stale-bulletin badge match the new visual language.
- Tag the whole row as the tap target (already a `link_to` to product detail) —
  good; ensure the época pill isn't a nested interactive element.

### 4.6 A legend / "what does época mean?"
- One quiet inline legend under the header or a tappable `ⓘ` explaining the três
  buckets and that timing is "em reais de hoje (IPCA)". Honesty per CONTEXT.md —
  never imply more precision than we have; seasonality-sourced tags say
  "tipicamente".

---

## 5. Concrete change set (files)

- `app/views/precos/index.html.erb` — regroup rows into product-group + variant
  sub-rows; replace `variation-chip` column with `época` tag column; legend.
- `app/controllers/precos_controller.rb` — keep grouping by product; expose
  precomputed timing per variant; ensure single-variant vs multi-variant shape is
  explicit for the view.
- `app/helpers/application_helper.rb` — small helper to render the época pill +
  pick tier (timing → seasonality → none).
- `app/services/` — a thin `BuyTiming` resolver (or extend `MarketTiming`) that
  implements the §2 ladder and returns a uniform `{bucket, source, label}`.
- **New job** — nightly precompute of variant timing buckets (§3).
- **Migration** — `variants.timing_bucket / timing_source / timing_computed_at`
  (or a dedicated `variant_timings` table) for O(1) reads.
- `app/assets/stylesheets/domain/ta_justo.css` — grouped inset rows, tabular-nums,
  época pill column, sticky headers; mobile/desktop media queries.
- `app/assets/stylesheets/layouts/index_page.css` — container/spacing tweaks.

## 6. Out of scope / explicitly NOT doing
- No change to the ingestion pipeline, parser, or how variants are matched.
- Not deepening price history here (separate backfill effort); we only make the UI
  degrade gracefully against thin history.
- No new colour system — reuse existing design tokens.

## 7. Open questions for the user
1. **§2 decision:** seasonality fallback on, or timing-only with blanks?
2. Tag column header wording: **"Época"**, "Momento", or "Melhor hora"?
3. Keep nominal "Var. 12m" anywhere (e.g. detail page only), or remove from index
   entirely? (Plan assumes: remove from index, it can live in product detail.)
4. Group header for multi-variant products — show an emoji (🍌) or plain text?
5. Desktop: single column (max scanability) vs 2-up sections — confirm preference.

---

## 8. Suggested build order
1. Fix 1.1 grouping (pure view/controller, no data dependency) — immediate clarity
   win, low risk.
2. Add `BuyTiming` resolver + precompute job + migration (§2, §3).
3. Swap the column to the época tag with graceful fallback (1.2).
4. Visual polish pass (§4): tabular-nums, inset rows, pill colours, sticky, mobile
   breakpoints.
5. Legend + honesty labels.
6. Verify performance: index render issues no per-row history compute.
