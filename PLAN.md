# PLAN.md — Tá Justo?: post-QA fixes (unit pricing, metrics clarity, manga, PDF link, live search)

Tracker grammar: `[ ]` open → `[IN PROGRESS]` → `[x]` done. Tags: `(trivial|normal|hard)` and `(serial)`.

**Goal (rearticulated):** Fix five defects found in manual QA without regressing the green gate.
(1) The checker `/` uses a static `<select>` — replace it with a **live search** that also matches
subcategories (variant/type names like "Espada", "Seco"). (2) Surface the **CEASA PDF link** for each
price day (already stored in `bulletins.source_url`, never shown). (3) Make **R$/kg metrics explicit** —
every weight type per product must state how its price/kg (or /unidade, /dúzia) is derived from CEASA
pack-weight normalization, and the label must match the real unit. (4) **Coco is broken** ("Nenhum preço
encontrado para Coco") because its default variant **Verde** is sold as bare `"Unid"` (direct piece price,
`price_per_kg = nil`), which representative-row selection drops. (5) **Manga** shows a duplicate
"Tommy Atkins" (two pack sizes on one bulletin) and clicking any variety opens the default variant instead
of the clicked one.

## Design constraints (read before ANY task — non-negotiable)
1. **VERIFY_CMD is the only "done" signal.** A task is done when `bin/rubocop && bin/rails test` is green
   AND the task's own verify command passes. No green, no commit. `.ratchet.conf` is human-owned — the loop
   FORBIDS agent turns from touching it. Do not create a task that edits it.
2. **Ruby via asdf.** Shell PATH must include `$HOME/.asdf/shims` (system Ruby breaks bundler). Prefix every
   verify line with `export PATH="$HOME/.asdf/shims:$PATH"`.
3. **STAGE, don't commit/push**, unless explicitly told. (User reviews first; the loop owns commits.)
4. **No new dependencies.** Reuse Stimulus, existing services, vanilla CSS/ERB. The live search is
   client-side over the already-loaded core basket — no new gem, no new JS lib, no new endpoint in v1.
5. **Zero regression on the verdict path for products that already work.** `FairPriceVerdict`,
   `MarketTiming`, `BuyTiming`, `PriceHistory` are correct for per_kg/per_dozen and weight-derived per_unit.
   Only extend the **direct-unit** (`original_unit='unit'`) branch; do not alter existing per_kg/per_dozen math.
6. **Respect the original CEASA unit; never fabricate.** Display each price in the unit CEASA actually
   quotes: if the bulletin gives a **unit** price (bare "Unid" — Coco Verde), show **/unidade** from `modal`;
   if it gives a **kg** price (bare "kg"), show **/kg**. Convert to /kg **only** for odd packaging (boxes/
   sacks like `Cx 18 kg`, `SC 30 KG`) where `price_per_kg = modal ÷ pack weight`. Do NOT invent a /kg via a
   guessed `avg_weight_kg`; it may only *estimate* a secondary "≈ R$/kg" for display, clearly marked "≈".

## VERIFY_CMD (the green gate — run after every task)
```bash
export PATH="$HOME/.asdf/shims:$PATH"
bin/rubocop && bin/rails test
```

## State at plan start (verified live against prod-derived dev DB)
- Prior PLAN.md (filter integrity / deflated chart / pt-BR / branding) is fully `[x]` and in git history;
  this file supersedes it.
- **Coco** (`products.id=11`, slug `coco`): default_variant = **Verde** (`variants.id=19`, `pricing_mode=per_unit`,
  `avg_weight_kg=1.2`). All 799 Verde rows are `raw_unit="Unid"`, `original_unit="unit"`, `modal≈3.30`,
  **`price_per_kg=nil`**. `UnitNormalizer#per_kg` returns nil for bare "Unid" (SPECIAL 4) — correct.
  `Variant#latest_price` / `#representative_price` / `#pick_representative` filter `where.not(price_per_kg: nil)`,
  so Verde yields **no** representative row → `ProductsController#show` sets
  `@error = "Nenhum preço encontrado para Coco"`. `/precos` survives only via its `modal` fallback.
  Coco **Seco** (`id=20`, `raw_unit="SC 30 KG"`) has `price_per_kg≈4.33` and would resolve — the page just
  never reaches it because it defaults to Verde.
- **FairPriceVerdict#call_per_unit** assumes `ceasa_per_unit = price_per_kg × avg_weight_kg` and hard-raises
  without `avg_weight_kg`; it cannot price a direct-unit row (would multiply nil).
- **Manga** (`products.id=23`, slug `manga`, default_variant=Palmer `id=39`): on the latest bulletin, variant
  **Tommy Atkins** (`id=40`) has TWO rows — `Cx 18 kg`→6.11 and `Cx 5 kg`→13.00. `precos/index.html.erb`
  renders **every** `Price` row in the multi-type branch, so Tommy Atkins appears twice. The variant `link_to`
  is `product_path(product.slug)` with **no** `variant:`, so every variety opens the default (Palmer).
  `ProductsController#show` already honors `?variant=ID`.
- **bulletins.source_url** holds the exact PDF URL (e.g. the 07/08/2026 boletim). Not surfaced on any page.
- **/precos** header hardcodes the column label "Preço/kg" and, for direct-unit/dozen rows, shows a `modal`
  number under a "/kg" heading (misleading). Detail page prints "R$ x/kg" with no statement of the pack
  weight used to derive it.
- `CoreBasket.checkable_list` returns `{slug, name, default_variant}` for the 37 core products; variants are
  loaded per product only on the detail page. `list_filter_controller.js` already implements a debounced
  client filter (used on /precos).
- Existing tests: `test/models/variant_representative_price_test.rb`,
  `test/controllers/products_controller_representative_price_test.rb`,
  `test/integration/precos_page_test.rb`, `test/services/fair_price_verdict_percentile_test.rb`.

---

## Milestone 0 — baseline green gate (serial)
> No feature task runs before this is green. Bootstraps "no green, no commit".
> `.ratchet.conf` VERIFY_CMD is already `bin/rubocop && bin/rails test` (human-owned; do not touch).

- [x] T0.1 (trivial, serial) Establish the baseline green gate
      do: Run VERIFY_CMD. Confirm rubocop clean + all minitest green. This is the baseline every later task
          must preserve. Record the test count in LEARNINGS.md (append one line).
      accept: Given T0.1 applied, Then `bin/rubocop && bin/rails test` is fully green.
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rubocop && bin/rails test

---

## Phase 1 — Data correctness: direct-unit pricing (Coco) + metrics honesty
> The verdict/detail path must not drop or misprice direct-unit variants. This is the root-cause fix; it
> lives in the ONE place all callers route through (Variant representative-row selection + the per_unit
> verdict branch), not per-page.

- [x] T1.1 (hard, serial) Select & price direct-unit rows (original_unit='unit') everywhere representative-row selection runs
      touches: app/models/variant.rb, app/services/fair_price_verdict.rb, app/controllers/products_controller.rb
      do: A per_unit variant has two CEASA sub-cases: **direct-unit** (`original_unit="unit"`, price IS `modal`,
          `price_per_kg` nil — Coco Verde, R$3.30/peça) and **weight-derived** (`original_unit="kg"`,
          `price_per_kg` present, unit price = `price_per_kg × avg_weight_kg` — Melancia, Abacaxi). Today the
          selection helpers keep only `where.not(price_per_kg: nil)`, silently dropping every direct-unit row so
          the variant looks priceless. Fix the shared selection + the per_unit verdict/stats to treat a
          direct-unit row as a first-class priced row.
          (A) `Variant#representative_price(bulletin:)`: when `pricing_mode == "per_unit"`, consider rows that are
              EITHER `original_unit="unit"` OR have `price_per_kg` present. Prefer... keep it deterministic:
              reuse the smallest-retail-pack rule for weight-derived rows; for direct-unit rows (no pack weight)
              fall back to stable min id. If both kinds exist for a variant, prefer the direct-unit row (that is
              the piece price the shopper pays).
          (B) `Variant#pick_representative(rows)` and `#representative_series(months:)`: same per_unit rule — do
              not `where.not(price_per_kg: nil)` for per_unit; include `original_unit="unit"` rows. Keep per_kg
              and per_dozen branches byte-identical.
          (C) `Variant#latest_price`: for per_unit, the scope must include direct-unit rows (drop the kg-only
              filter for this mode) so Coco Verde resolves a latest bulletin.
          (D) `FairPriceVerdict#call_per_unit`: branch on the representative row. If it is direct-unit
              (`row.original_unit == "unit"` / `price_per_kg` nil), `ceasa_per_unit = row.modal.to_f` and do NOT
              require `avg_weight_kg`. Else keep `price_per_kg × avg_weight_kg`. `comparable_series(:per_unit)`
              must mirror this (direct-unit → `modal`; weight-derived → `price_per_kg × avg_weight_kg`).
          (E) `ProductsController#comparable_for`: same per_unit branch (direct-unit → `price.modal.to_f`).
          Reason (root cause): representative-row selection is the single seam every surface routes through
          (verdict, stats, /precos, detail). Fixing it here fixes Coco Verde AND any other bare-"Unid" variant at
          once, instead of patching each page.
      snippet:
          # Variant#pick_representative
          def pick_representative(rows)
            case pricing_mode
            when "per_dozen"
              rows.select { |p| p.original_unit == "dozen" }.min_by(&:id)
            when "per_unit"
              direct = rows.select { |p| p.original_unit == "unit" }
              return direct.min_by(&:id) if direct.any?
              rows.select(&:price_per_kg).min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
            else
              rows.select(&:price_per_kg).min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
            end
          end
          # FairPriceVerdict#call_per_unit (head)
          latest = representative_latest
          raise "Sem preço CEASA para #{@variant.name}" unless latest
          if latest.original_unit == "unit"
            ceasa_per_unit = latest.modal.to_f
          else
            raise "Variante #{@variant.name} sem avg_weight_kg" unless @variant.avg_weight_kg&.positive?
            ceasa_per_unit = latest.price_per_kg.to_f * @variant.avg_weight_kg.to_f
          end
      accept:
          Given Coco (default variant Verde, sold as bare "Unid")
          When the product detail page and the verdict for Verde are computed
          Then `@variant.latest_price` returns the "Unid" row (not nil), the page does NOT show
               "Nenhum preço encontrado para Coco", and FairPriceVerdict returns a per-unidade Result with
               ceasa_comparable == modal, without raising
          And Coco Seco (per-kg source) and every existing per_kg/per_dozen/weight-derived per_unit variant
               (Melancia, Abacaxi, ovo) resolve exactly as before
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/models/variant_representative_price_test.rb test/controllers/products_controller_representative_price_test.rb test/services/fair_price_verdict_percentile_test.rb
      constraints: only the per_unit branches change; per_kg/per_dozen paths byte-identical. Add test cases:
          (a) Coco Verde `latest_price` returns the unit row; (b) verdict for Verde is per-unidade == modal and
          never raises; (c) a weight-derived per_unit variant still prices `price_per_kg × avg_weight_kg`.

- [x] T1.2 (normal, serial) State how each price is derived (metrics transparency) on detail + /precos
      touches: app/views/products/show.html.erb, app/views/precos/index.html.erb, app/controllers/precos_controller.rb, app/helpers/application_helper.rb
      do: Show each price in the unit CEASA quotes; only explain a conversion when one actually happened
          (odd packaging → /kg). Builds on T1.1's direct-unit branch (annotation 3, principle 6).
          (A) `products/show.html.erb`: under the "Último preço" stat, render one basis line sourced from the
              representative `@latest_price` row:
              - odd-packaging per_kg (pack weight parses, e.g. `Cx 18 kg`/`SC 30 KG`):
                `R$ <price_per_kg>/kg = modal R$<modal> ÷ <pack kg> kg (embalagem <raw_unit>, CEASA)`
                (pack kg via `PackSize.kg(raw_unit)`) — this is the only case that gets a "÷ peso" derivation.
              - bare-kg per_kg (raw_unit already "kg", no conversion): `R$ <price_per_kg>/kg (preço CEASA por kg)`.
              - direct-unit (`original_unit="unit"`): `R$ <modal>/unidade (preço CEASA por peça)` and, only if
                `avg_weight_kg` present, a secondary `≈ R$ <modal/avg_weight_kg>/kg (peça ~<g>g estimada)`.
              - weight-derived per_unit: `R$ <calc>/unidade ≈ R$/kg × ~<g>g (estimado)`.
              - per_dozen: `R$ <modal/30>/dúzia = caixa R$<modal> ÷ 30 dz (CEASA)`.
              Add a small helper `price_basis_line(variant, price)` in ApplicationHelper returning the pt-BR
              string; use existing values already loaded — no new query.
          (B) `precos/index.html.erb`: the column header hardcodes "Preço/kg". Replace with a neutral "Preço"
              label, and render each row's value with its true unit suffix (`/kg`, `/unidade`, `/dúzia`) from the
              variant's `pricing_mode` — never show a `modal` number under a "/kg" heading. Reuse the existing
              display-price branch (`price_per_kg` → `/kg`; else `modal` → unit-appropriate suffix).
          (C) Raw-data table caption on the detail page: add one sentence stating the normalization rule
              ("R$/kg de embalagens em caixa/saco = preço modal ÷ peso da embalagem CEASA"). No new query.
      snippet:
          # ApplicationHelper
          def price_basis_line(variant, price)
            case variant.pricing_mode
            when "per_dozen"
              "R$ %.2f/dúzia = caixa R$ %.2f ÷ 30 dz (CEASA)" % [ price.modal.to_f / 30, price.modal.to_f ]
            when "per_unit"
              if price.original_unit == "unit"
                "R$ %.2f/unidade (preço CEASA por peça)" % price.modal.to_f
              else
                "R$ %.2f/unidade ≈ R$ %.2f/kg × ~%dg (estimado)" %
                  [ price.price_per_kg.to_f * variant.avg_weight_kg.to_f, price.price_per_kg.to_f, (variant.avg_weight_kg.to_f * 1000).round ]
              end
            else # per_kg
              kg = PackSize.kg(price.raw_unit)
              kg ? "R$ %.2f/kg = modal R$ %.2f ÷ %g kg (embalagem %s, CEASA)" % [ price.price_per_kg.to_f, price.modal.to_f, kg, price.raw_unit ] : "R$ %.2f/kg (preço CEASA por kg)" % price.price_per_kg.to_f
            end
          end
      accept:
          Given a box-packaged per_kg product (Manga, embalagem Cx 18 kg) detail page
          Then a basis line states "= modal R$… ÷ … kg (embalagem …, CEASA)"
          And given a bare-kg per_kg product the basis line states "/kg (preço CEASA por kg)" with no "÷ peso"
          And given Coco Verde (direct-unit) the basis line states "/unidade (preço CEASA por peça)" with NO
              bare "/kg" claim
          And on /precos every row's price suffix matches its variant unit (no "/kg" over a per-unidade modal)
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/precos_page_test.rb test/controllers/products_controller_representative_price_test.rb
      constraints: additive view/helper only; do not change any pricing math. Add an assertion that a direct-unit
          product renders "/unidade" and a per_kg product renders the "÷ … kg" basis string.

---

## Phase 2 — /precos grouping: manga dedupe + click-through to the clicked variety

- [x] T2.1 (normal, serial) Collapse each variant to its representative row on /precos (fix duplicate Tommy Atkins)
      touches: app/controllers/precos_controller.rb
      do: The index renders every `Price` row, so a variant with two packs on one bulletin (Tommy Atkins:
          Cx 18 kg→6.11 and Cx 5 kg→13.00) shows twice. Collapse to ONE row per variant using the same
          representative-row rule the rest of the app uses. In `PrecosController#index`, after loading
          `section_prices`, reduce to one price per variant via
          `Variant#representative_price(bulletin: @latest_bulletin)` (or pick, per variant, the min-pack row from
          the already-loaded set to avoid an extra query). Then `group_by { |p| p.variant.product }` over the
          deduped set. Both pack prices remain visible on the detail page's raw-data table.
      snippet:
          section_prices = section_prices
            .group_by(&:variant_id)
            .map { |_vid, rows| rows.min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] } }
      accept:
          Given the latest bulletin where Tommy Atkins has two pack rows
          When /precos renders the Manga group
          Then Tommy Atkins appears exactly once (its representative/min-pack row)
          And no other product loses a distinct variant
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/precos_page_test.rb
      constraints: dedupe by variant only within a section's loaded rows; do not change section grouping, timing,
          or the fair_relevant filter. Add a test asserting one Tommy Atkins row on /precos.

- [x] T2.2 (trivial, serial) Link each /precos variety row to that exact variant (?variant=ID)
      touches: app/views/precos/index.html.erb
      do: In the multi-type branch, the per-variant `link_to product_path(product.slug)` carries no variant, so
          clicking any variety opens the default (Palmer for Manga). Pass the variant id:
          `product_path(product.slug, variant: price.variant.id)`. `ProductsController#show` already honors
          `?variant=ID`. Single-product rows keep the default link.
      snippet:
          <%= link_to product_path(product.slug, variant: price.variant.id), class: "price-row price-row--variant" do %>
      accept:
          Given the Manga group on /precos
          When the "Espada" row is clicked
          Then the detail page opens with variant=41 (Espada) selected, not the default
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/precos_page_test.rb
      constraints: only the multi-type branch link gains `variant:`. Add an assertion the variant row href
          includes `variant=`.

---

## Phase 3 — Surface the CEASA PDF link per price day

- [IN PROGRESS] T3.1 (trivial) Show the source PDF link on /precos and the detail raw-data section
      touches: app/views/precos/index.html.erb, app/views/products/show.html.erb
      do: `bulletins.source_url` holds the exact PDF. Surface it read-only.
          (A) `/precos` header: below the "Atualizado…" subtitle add
              `link_to "Ver boletim PDF", @latest_bulletin.source_url, target: "_blank", rel: "noopener"`.
          (B) Detail raw-data accordion (`products/show.html.erb`): in the "Dados brutos CEASA (<date>)" summary,
              link the date to `@latest_price.bulletin.source_url` (`target=_blank`, `rel=noopener`).
          Reason: annotation 2 — let people open the underlying bulletin.
      accept:
          Given /precos and a product detail page
          Then each renders an external link to the bulletin's `source_url` (target=_blank, rel=noopener)
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/precos_page_test.rb && grep -q 'source_url' app/views/precos/index.html.erb
      constraints: view-only; no controller change (both `@latest_bulletin` and `@latest_price.bulletin` are
          already loaded). Add an assertion the /precos page includes the source_url href.

---

## Phase 4 — Live product search on the checker (replaces the dropdown)

- [ ] T4.1 (normal, serial) Expose core-basket products + their variant names as a search index for the checker
      touches: app/controllers/checks_controller.rb, db/seeds/core_basket.rb
      do: The live search must match products AND subcategories (variant/type names like "Espada", "Seco")
          (annotation 1). Build the search data server-side once and hand it to the view.
          Add `CoreBasket.search_index` returning, for each core product, `{slug, name, variants: [{id, name}]}`
          (variant names come from `product.variants.order(:name)`; the products are already the checkable list).
          In `ChecksController#show`, assign `@search_index = CoreBasket.search_index` (JSON-encodable) for the
          client filter. Keep `@core_products` for the no-JS `<select>` fallback.
      accept:
          Given the checker page
          Then `@search_index` contains every core product with its variant names (e.g. Manga → [Espada, Palmer,
               Tommy Atkins]) and each variant's id
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/controllers
      constraints: no new model/table; reuse `CoreBasket.all_products` with `includes(:variants)`. Add a
          controller test asserting `@search_index` includes a product with variants.

- [ ] T4.2 (hard, serial) Client-side live search UI on the checker, accent-insensitive, links to product or variant
      touches: app/views/checks/show.html.erb, app/javascript/controllers/product_search_controller.js, app/javascript/controllers/index.js
      do: Replace the `<select>` with a live search input over `@search_index` (embedded as JSON in a
          `data-` attribute). New Stimulus controller `product_search_controller.js`:
          - On input (debounced ~150ms), normalize the query (strip accents via
            `.normalize("NFD").replace(/\p{Diacritic}/gu, "")`, lowercase) and filter the index matching product
            name OR any variant name.
          - Render a results list (≤8) as clickable items. A product-name match links to `?product=<slug>`;
            a variant-name match links to `?product=<slug>&variant=<id>` and shows "Produto › Variante".
          - Selecting a result sets the hidden `product` field (and optional `variant`) the existing price form
            submits — keep the price input + "Tá justo?" button and the whole verdict flow intact.
          - No-JS fallback: keep the existing `<select>` inside a `<noscript>` (or render it and let the
            controller replace it on connect) so the page still works without JS.
          Register the controller in `app/javascript/controllers/index.js`. No JS test runner exists — gate with
          a grep self-check for the controller shape + a Rails integration test on the server-rendered markup
          (input present, `@search_index` JSON embedded, `<noscript>` select fallback present).
      snippet:
          // product_search_controller.js
          static targets = ["input", "results", "product", "variant"]
          static values = { index: Array }
          norm(s){ return s.normalize("NFD").replace(/\p{Diacritic}/gu,"").toLowerCase() }
          filter(){ const q=this.norm(this.inputTarget.value); /* match name|variant, render ≤8 */ }
      accept:
          Given the checker with JS enabled
          When the user types "espada"
          Then a result "Manga › Espada" appears and selecting it sets product=manga & variant=41 for submission
          And with JS disabled the `<noscript>` `<select>` still submits `product=<slug>`
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration && grep -q 'product-search' app/views/checks/show.html.erb && grep -q 'normalize("NFD")' app/javascript/controllers/product_search_controller.js
      constraints: no new gem/JS lib; client-side only (no /buscar endpoint in v1 — ~37 products, <150 variants
          is a tiny payload). ponytail: if the index outgrows the inline payload, add a `/buscar.json` endpoint
          later. Keep the price form + verdict flow unchanged. Add an integration test asserting the search input
          + embedded index + `<noscript>` fallback render.

---

## Definition of done
- All tasks `[x]`; `bin/rubocop && bin/rails test` green on a clean checkout.
- Coco (and any bare-"Unid" variant) resolves a per-unidade price on the detail page and verdict — no
  "Nenhum preço encontrado"; existing per_kg/per_dozen/weight-derived per_unit variants unchanged.
- Every price surface states its unit honestly; the detail page shows how R$/kg (or /unidade, /dúzia) is
  derived from the CEASA pack weight; /precos never shows a modal number under a "/kg" label.
- Manga (and any multi-pack variant) shows one row per variety on /precos, and clicking a variety opens that
  exact variant.
- /precos and the detail raw-data section link the source CEASA PDF (`bulletins.source_url`, new tab).
- The checker `/` has a live search matching products and variant/type names, accent-insensitive, linking to
  product or product+variant, with a working no-JS `<select>` fallback.
- Everything **staged** for user review (not committed).

## Non-goals (explicitly OUT)
- Re-deriving per_kg for variants CEASA genuinely sells by the piece (no fabricated weights).
- A search backend/endpoint or fuzzy-search library (client-side exact/substring match is enough in v1).
- Changing the verdict bands, timing math, or deflation.
- Touching the CEASA fetch/parse pipeline or `.ratchet.conf`.
- Any real deploy / domain / infra change.
