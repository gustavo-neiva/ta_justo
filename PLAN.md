# PLAN.md — Tá Justo?: filter integrity, real-terms chart, prices UX, pt-BR + branding

Tracker grammar: `[ ]` open → `[IN PROGRESS]` → `[x]` done. Tags: `(trivial|normal|hard)` and `(serial)`.

**Goal (rearticulated):** Deliver seven product changes without regressing the green gate: (1) toggle the
seasonality line via CSS instead of a D3 re-render, (2) add the author's name + site to About/footer, (3) deflate
the **historical price chart** to real terms (the verdict/timing path is already deflated — only `ChartSeries` is
still nominal), (4) redesign the /precos tab so época pills stop clipping, (5) make every chart filter change
preserve all other selected filters, (6) add a console-log easter egg with cornucopia ASCII art, (7) a pt-BR
localization pass that removes anglicisms ("checker" → "verificador"). Grouped into the three user-requested phases.

## Design constraints (read before ANY task — non-negotiable)
1. **VERIFY_CMD is the only "done" signal.** A task is done when `bin/rubocop && bin/rails test` is green AND the
   task's own verify command passes. No green, no commit. `.ratchet.conf` was already corrected to
   `VERIFY_CMD=bin/rubocop && bin/rails test` by the human (the loop FORBIDS agent turns from touching that file,
   so no task edits it — do not attempt to).
2. **Zero data / behavior regressions on the verdict path.** `FairPriceVerdict`, `MarketTiming`, `PriceHistory`,
   and `BuyTiming` already deflate correctly (IPCA série 1737 / INPC 188 — the agrobr "série 433 as level" bug is
   already avoided). Do NOT touch those services except where a task names them. The chart is the only nominal
   surface.
3. **Ruby via asdf.** Shell PATH must include `$HOME/.asdf/shims` (system Ruby breaks bundler). Prefix VERIFY
   with `export PATH="$HOME/.asdf/shims:$PATH"` when a turn's shell can't find the right Ruby.
4. **STAGE, don't commit/push**, unless explicitly told. (User reviews first.)
5. **No new dependencies.** Reuse the existing deflation math (`PriceHistory#deflate` + forward-fill), Stimulus,
   vanilla CSS. No new gems, no new JS libs.
6. **Deflation fallback is graceful, never a crash.** If IPCA index is missing or >90d stale, the chart shows
   **nominal** prices (same rule `PriceHistory` uses via its Null path) — it must never blank the chart.
7. **No JS test runner exists.** JS-only changes (seasonality toggle, easter egg) are gated by (a) a `grep`
   self-check in the task's `verify` line proving the code shape is present, and (b) the server-rendered markup
   that drives them, asserted in a Rails integration test. Do not add a JS framework to test three lines.

## VERIFY_CMD (the green gate — run after every task)
```bash
export PATH="$HOME/.asdf/shims:$PATH"
bin/rubocop && bin/rails test
```

## State at plan start (2026-08-04, verified live)
- Prior PLAN.md (green gate / CI / PWA / hygiene) is fully `[x]` and in git history; this file supersedes it.
- `app/services/chart_series.rb` → returns **nominal** `{ date, price }` points. `ProductsController#show` feeds it
  straight to the D3 controller. The verdict path (`PriceHistory`) is deflated; the chart is not. (Req 3 gap.)
- `app/javascript/controllers/d3_line_chart_controller.js` → `showSeasonalValueChanged()` calls `this.draw()`
  (full SVG teardown + rebuild) on every checkbox toggle. (Req 1.)
- `app/views/products/_chart.html.erb` → period pills link `product_path(slug, variant:, period:)` — drop
  `check_price` and any other param. `show.html.erb` variant links link `(variant:, period:)` — drop `check_price`.
  Changing one filter silently resets the others. (Req 5.)
- `app/assets/stylesheets/domain/ta_justo.css` → `.price-list-header,.price-row,.price-row--variant` grid is
  `grid-template-columns: 1fr 130px 145px`; `.col-epoca { text-align:right }`; `.epoca-pill { white-space:nowrap }`.
  Text "tipicamente preço normal" overflows the 145px época column and is clipped (see screenshot). (Req 4.)
- "checker" anglicism in: `app/views/products/show.html.erb` (×3: class `checker-container`, `checker-form`,
  "Novo checker"), `app/views/checks/show.html.erb` (×2: `checker-container`, `checker-form`),
  `app/views/precos/index.html.erb` (×2: "Voltar ao checker"), `app/views/pages/sobre.html.erb` (×1),
  `app/controllers/checks_controller.rb` (comment), `config/routes.rb` (comment), and CSS selectors in
  `app/assets/stylesheets/domain/ta_justo.css` + `app/assets/stylesheets/layouts/landing_page.css`. (Req 7.)
- `app/views/shared/_footer.html.erb` and `app/views/pages/sobre.html.erb` have no author attribution. (Req 2/6.)
- `app/javascript/application.js` is 4 lines; no easter egg. (Req 6.)
- Deflation reference: `tmp/research/agrobr-priorart.md`. Correct IPCA level = série 1737 (NOT 433). Forward-fill
  monthly index; base = latest published month. Formula: `real = nominal × (index_base / index_data)`.

---

## Milestone 0 — baseline green gate (serial)
> No feature task runs before this is green. Bootstraps "no green, no commit".
> NOTE: `.ratchet.conf` VERIFY_CMD is already fixed to `bin/rubocop && bin/rails test` (human-owned file, agent
> turns are FORBIDDEN from editing it). Do not create a task that touches `.ratchet.conf`.

- [x] T0.1 (trivial, serial) Establish the baseline green gate
      do: Run VERIFY_CMD. Confirm rubocop clean + all minitest green. This is the baseline every later task
          must preserve. Record the test count in LEARNINGS.md (append one line).
      accept: Given T0.1 applied, Then `bin/rubocop && bin/rails test` is fully green.
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rubocop && bin/rails test

---

## Phase 1 — State Management & Core Logic (Filters & Inflation)
> Ratchet milestone. Filter integrity first (pure view/link change), then the deflated chart series.

- [x] T1.1 (hard) Preserve ALL current query params when switching chart period or variant
      touches: app/views/products/_chart.html.erb, app/views/products/show.html.erb
      do: Today the period pills link `product_path(@product.slug, variant: @variant.id, period: value)` and the
          variant links link `product_path(@product.slug, variant: v.id, period: @period)`. Each rebuilds the URL
          from a hardcoded subset, so switching period drops `check_price` (and any future filter) and switching
          variant drops `check_price` too. Fix by merging the live query string: build the link params from
          `request.query_parameters.merge(...)` so every link carries the full current filter state and only
          overrides the one dimension it changes. In `_chart.html.erb`, the period pill becomes
          `product_path(@product.slug, request.query_parameters.merge(period: value))`. In `show.html.erb`, the
          variant link becomes `product_path(@product.slug, request.query_parameters.merge(variant: v.id))`.
          `request.query_parameters` excludes the `:id`/`:controller`/`:action` route params, so it is safe to
          splat. Reason: changing one filter must strictly preserve every other selected filter (req 5).
      snippet:
          <%# period pill %>
          <%= link_to label,
                product_path(@product.slug, request.query_parameters.merge(period: value)),
                data: { turbo_frame: "product-chart" },
                class: "pill-option#{' active' if @period == value}" %>
          <%# variant link %>
          <%= link_to v.name,
                product_path(@product.slug, request.query_parameters.merge(variant: v.id)),
                class: "variant-link #{'active' if v.id == @variant.id}" %>
      accept:
          Given a product page loaded with ?variant=V&period=90&check_price=8.50
          When the rendered period pills and variant links are inspected
          Then every one of those links' href includes variant, period AND check_price=8.50, each overriding only
          its own dimension
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/product_filter_preservation_test.rb
      constraints: additive to the views only; do not change ProductsController param parsing; the "active" state
          logic stays as-is. Add the new integration test asserting hrefs contain all three params.

- [IN PROGRESS] T1.2 (hard, serial) Add a real-terms (deflated) option to ChartSeries, reusing existing IPCA math
      touches: app/services/chart_series.rb
      do: `ChartSeries#points` returns nominal prices. Add deflation so the chart can show real terms, reusing the
          exact IBGE formula the verdict path already uses (`real = nominal × (index_base / index_data)`), base =
          latest published IPCA month, forward-filled per month (agrobr prior art: série 1737 is already what
          `PriceIndex` stores — do NOT reintroduce série 433). Implementation: give the constructor a
          `deflated: false` keyword. When `deflated: true`, build a `month(Date bom) → index_level` lookup once
          from `PriceIndex.where(index_name: "ipca")`, capture `base_level` = level of the latest month, and in
          `point_for` multiply the nominal value by `base_level / level_for(bulletin_month)` using forward-fill
          (latest month `<=` the bulletin month). Fallbacks (constraint 6): if there is no IPCA data at all, or the
          latest IPCA month is >90 days stale (reuse `PriceHistory::STALE_THRESHOLD_DAYS = 90`), return nominal
          points unchanged — never blank the series. Keep the default (`deflated: false`) byte-identical to today.
      snippet:
          def initialize(variant, period: "365", deflated: false)
            @variant = variant; @period = period; @deflated = deflated
          end
          # in point_for, after computing nominal `value`:
          value *= deflation_factor(price.bulletin.price_date) if @deflated
          # deflation_factor forward-fills: base_level / level_at_or_before(month)
          # returns 1.0 when index missing or stale (nominal fallback)
      accept:
          Given a variant with prices spanning months whose IPCA levels differ
          When ChartSeries.new(variant, deflated: true).points is called and IPCA data is fresh
          Then each older point's price is scaled by base_level/month_level (strictly ≥ nominal for past inflation)
          And when no IPCA data exists (or latest is >90d stale) the points equal the nominal series exactly
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/services/chart_series_test.rb
      constraints: reuse the 90-day stale rule from PriceHistory; no new gem; default deflated:false unchanged.
          Add chart_series_test cases: (a) deflated scales past prices up, (b) no-index → nominal, (c) stale → nominal.

- [ ] T1.3 (normal, serial) Render the chart in real terms and label it as such
      touches: app/controllers/products_controller.rb, app/views/products/_chart.html.erb
      do: With T1.2 shipped, switch the detail chart to real terms so historical prices are inflation-adjusted
          (req 3). Two exact edits:
          (A) `app/controllers/products_controller.rb` — find the line
          `    @chart_data    = ChartSeries.new(@variant, period: @period).points`
          and replace it verbatim with
          `    @chart_data    = ChartSeries.new(@variant, period: @period, deflated: true).points`
          (B) `app/views/products/_chart.html.erb` — the price legend span currently reads exactly:
          `        <span class="legend-item"><span class="legend-swatch legend-price"></span>Preço CEASA (R$/<%= @unit_label %>)</span>`
          Replace the visible label text so it becomes exactly:
          `        <span class="legend-item"><span class="legend-swatch legend-price"></span>Preço CEASA em R$ de hoje (IPCA) — R$/<%= @unit_label %></span>`
          Reason: the /precos época tags already say "Calculado em reais de hoje (IPCA)"; the chart must match that
          promise. The seasonality overlay (median) stays as-is ("Típico do mês (mediana histórica)") — do NOT edit it.
      snippet:
          @chart_data    = ChartSeries.new(@variant, period: @period, deflated: true).points
      accept:
          Given a product detail page with fresh IPCA data
          When the chart renders
          Then the price series is the deflated series AND the legend states it is in "R$ de hoje (IPCA)"
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/controllers/products_controller_test.rb && grep -q "R\$ de hoje" app/views/products/_chart.html.erb
      constraints: only the one controller line + the legend text change; do not alter seasonal/USD/SMA handling.

---

## Phase 2 — UI/UX & CSS Optimizations (Seasonality toggle, Prices pills)

- [ ] T2.1 (hard, serial) Toggle the seasonality line via CSS class, not a D3 re-render
      touches: app/javascript/controllers/d3_line_chart_controller.js, app/views/products/_chart.html.erb,
               app/assets/stylesheets/components/chart.css
      do: Today `toggleSeasonal` flips `showSeasonalValue`, and `showSeasonalValueChanged()` calls `this.draw()` —
          a full SVG teardown/rebuild just to hide one path. Change to CSS visibility: (1) in `draw()`, always
          append the seasonal path when `seasonalValue.length > 1` (drop the `showSeasonalValue &&` guard on the
          draw side) and give it `.attr("class", "seasonal-line")`. (2) Replace `toggleSeasonal` so it toggles a
          class on `this.chartTarget` (e.g. `this.chartTarget.classList.toggle("seasonal-hidden", !checked)`)
          instead of setting the value. (3) Delete the `showSeasonalValueChanged()` redraw hook (and the now-unused
          `showSeasonal` value can stay for initial state but must no longer trigger `draw`). (4) In `chart.css`
          add `.seasonal-hidden .seasonal-line { display: none; }`. (5) In `_chart.html.erb`, the checkbox keeps
          `data-action="change->d3-line-chart#toggleSeasonal"` and `checked`. Reason: hiding a line is a pure
          presentation change; re-running D3 (scales, axes, animation, crosshair rebuild) on every toggle is
          wasteful and re-triggers the 800ms line-draw animation (req 1).
      snippet:
          toggleSeasonal(event) {
            this.chartTarget.classList.toggle("seasonal-hidden", !event.target.checked)
          }
          // in draw(), seasonal block — no showSeasonalValue guard:
          if (this.seasonalValue.length > 1) {
            /* ...build seasonalLine... */
            series.append("path").attr("class", "seasonal-line") /* ...attrs... */
          }
      accept:
          Given the chart is drawn
          When the "Mostrar sazonalidade" checkbox is toggled
          Then the seasonal path's visibility flips via the .seasonal-hidden CSS class with NO call to draw()
          (the price line does not re-animate)
      verify: grep -q 'seasonal-hidden' app/assets/stylesheets/components/chart.css && grep -q 'classList.toggle("seasonal-hidden"' app/javascript/controllers/d3_line_chart_controller.js && ! grep -q 'showSeasonalValueChanged' app/javascript/controllers/d3_line_chart_controller.js && echo OK
      constraints: keep the initial-render default (line visible when checkbox checked). Do not remove the seasonal
          drawing code — only ungate it and class it. No JS test runner: the grep self-check is the gate.

- [ ] T2.2 (hard, serial) Fix época pill clipping — redesign the /precos row grid so pills never truncate
      touches: app/assets/stylesheets/domain/ta_justo.css, app/views/precos/index.html.erb
      do: The 3-col grid `1fr 130px 145px` gives época a fixed 145px; "tipicamente preço normal" plus emoji
          overflows and is clipped (screenshot). Redesign for legibility (req 4): (1) widen and left-align the
          época column so the full pill fits — change the shared grid to give época real room and let it size to
          content, e.g. `grid-template-columns: minmax(0,1fr) 120px minmax(150px, max-content)` and set
          `.col-epoca { text-align: left; justify-self: start; }`. (2) Let the pill wrap gracefully instead of
          clipping: change `.epoca-pill { white-space: nowrap }` to allow wrapping (`white-space: normal;
          line-height: 1.3;`) and add `overflow-wrap: anywhere;`. (3) The `.col-product` cell must not eat the
          space — keep it `minmax(0,1fr)` so it can shrink. (4) Verify the mobile breakpoint (`@media
          max-width:768px`) still stacks correctly: there época is `grid-column: 2; text-align:right` — switch
          that to `text-align: left` too for consistency, and let it wrap. Reason: the pill text is the whole
          signal; clipping it destroys the feature.
      snippet:
          .price-list-header, .price-row, .price-row--variant {
            grid-template-columns: minmax(0, 1fr) 120px minmax(150px, max-content);
          }
          .col-epoca { text-align: left; justify-self: start; }
          .epoca-pill { white-space: normal; overflow-wrap: anywhere; line-height: 1.3; }
      accept:
          Given the /precos page at desktop and at ≤768px
          When an época pill reads "tipicamente preço normal"
          Then the full text renders inside the pill with no clipping/ellipsis on either layout
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/precos_page_test.rb && grep -q 'minmax(150px, max-content)' app/assets/stylesheets/domain/ta_justo.css
      constraints: keep the header/row/variant grids in sync (they share the template). Do not change pill colors
          or the legend. Visual clipping is CSS-only; the integration test just asserts the page still 200s with pills.

---

## Phase 3 — Localization & Branding (pt-BR pass, Footer/About, Console Easter Egg)

- [ ] T3.1 (normal, serial) Remove the "checker" anglicism from all user-facing copy (pt-BR pass)
      touches: app/views/products/show.html.erb, app/views/checks/show.html.erb,
               app/views/precos/index.html.erb, app/views/pages/sobre.html.erb,
               app/controllers/checks_controller.rb, config/routes.rb
      do: Replace user-visible "checker" with pt-BR terms (req 7). Make these EXACT string replacements (find the
          left literal, replace with the right literal — whole line shown so there is no ambiguity):

          1. `app/views/precos/index.html.erb` (line ~34, inside the @error empty-state):
             FIND:    `        <%= link_to "← Voltar ao checker", root_path, class: "button primary" %>`
             REPLACE: `        <%= link_to "← Voltar ao verificador", root_path, class: "button primary" %>`
          2. `app/views/precos/index.html.erb` (line ~116, bottom nav):
             FIND:    `      <%= link_to "← Voltar ao checker", root_path, class: "button secondary" %>`
             REPLACE: `      <%= link_to "← Voltar ao verificador", root_path, class: "button secondary" %>`
          3. `app/views/pages/sobre.html.erb` (line ~73):
             FIND:    `      <%= link_to "← Voltar ao checker", root_path, class: "button primary" %>`
             REPLACE: `      <%= link_to "← Voltar ao verificador", root_path, class: "button primary" %>`
          4. `app/views/products/show.html.erb` (line ~227):
             FIND:    `      <%= link_to "Novo checker", root_path, class: "button primary" %>`
             REPLACE: `      <%= link_to "Nova consulta", root_path, class: "button primary" %>`
          5. `app/controllers/checks_controller.rb` (line 1 comment):
             FIND:    `# ChecksController — The hero checker page`
             REPLACE: `# ChecksController — Página principal do verificador`
          6. `config/routes.rb` (line 12 trailing comment):
             FIND:    `  root "checks#show"                                # The hero checker`
             REPLACE: `  root "checks#show"                                # Verificador principal`

          DO NOT rename CSS classes in this task (`checker-container`/`checker-form`) — that is T3.2 (it must move
          HTML + CSS together to stay green). Reason: split so each turn is atomic and green.
      accept:
          Given the rendered /precos, /sobre and product pages
          When their visible text is inspected
          Then no visible string contains "checker"; the back-links read "verificador" and the button reads
          "Nova consulta"
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test && ! grep -rn 'ao checker\|Novo checker' app/views
      constraints: text/comment only; leave the `checker-container`/`checker-form` CSS class names for T3.2 so this
          turn stays green.

- [ ] T3.2 (normal, serial) Rename checker-* CSS classes to verificador-* across HTML + CSS together
      touches: app/views/products/show.html.erb, app/views/checks/show.html.erb,
               app/assets/stylesheets/domain/ta_justo.css, app/assets/stylesheets/layouts/landing_page.css
      do: Finish the anglicism removal by renaming the CSS classes `checker-container` → `verificador-container`
          and `checker-form` → `verificador-form` in BOTH the markup that uses them (`products/show.html.erb`,
          `checks/show.html.erb`) AND the stylesheets that define them (`domain/ta_justo.css` "Checker page"
          block + `.checker-container`; `layouts/landing_page.css` `.checker-container`, `.checker-form`, and
          nested selectors). This is one serial task because a class rename split across turns would leave the page
          unstyled mid-flight. Also update the CSS comments "Checker page" → "Verificador" and "Checker form card"
          → "Cartão do verificador". Reason: leftover English class names are the last of the anglicism pass (req 7).
      accept:
          Given the landing (/) and product detail pages
          When rendered
          Then they are styled identically to before AND `grep -rn "checker" app/assets app/views` returns nothing
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test && ! grep -rn 'checker' app/assets app/views
      constraints: pure rename — every `checker-container`/`checker-form` occurrence in the four files flips in the
          same turn. No visual change. Do not touch `checks_controller.rb`/`routes.rb` (done in T3.1).

- [ ] T3.3 (normal) Add author attribution (name + site) to the footer and About page
      touches: app/views/shared/_footer.html.erb, app/views/pages/sobre.html.erb
      do: Add the author's name and website (req 2). Two exact edits:

          (A) `app/views/shared/_footer.html.erb` — the footer-bottom currently reads exactly:
              FIND (the whole div):
              `    <div class="footer-bottom">`
              `      © 2026 Tá Justo? — Dados do CEASA-RJ`
              `    </div>`
              REPLACE with:
              `    <div class="footer-bottom">`
              `      © 2026 Tá Justo? — Dados do CEASA-RJ ·`
              `      Feito por <%= link_to "Luiz Gustavo Zincone Neiva", "https://gustavoneiva.dev",`
              `                            target: "_blank", rel: "noopener noreferrer" %>`
              `    </div>`

          (B) `app/views/pages/sobre.html.erb` — the "Quem fez isso?" section's paragraph currently ends exactly:
              FIND:
              `        Projeto pessoal de código aberto. Sem publicidade, sem venda de dados, 100% gratuito.`
              `        Se quiser contribuir ou reportar um problema, entre em contato.`
              REPLACE with:
              `        Projeto pessoal de código aberto. Sem publicidade, sem venda de dados, 100% gratuito.`
              `        Se quiser contribuir ou reportar um problema, entre em contato.`
              `        Feito por <%= link_to "Luiz Gustavo Zincone Neiva", "https://gustavoneiva.dev",`
              `                              target: "_blank", rel: "noopener noreferrer" %>.`

          Keep copy pt-BR. Reason: attribution on the two pages the user named (req 2).
      snippet:
          Feito por <%= link_to "Luiz Gustavo Zincone Neiva", "https://gustavoneiva.dev",
                                target: "_blank", rel: "noopener noreferrer" %>
      accept:
          Given the footer (any page) and the /sobre page
          When rendered
          Then both show "Luiz Gustavo Zincone Neiva" linking to https://gustavoneiva.dev with rel="noopener"
      verify: export PATH="$HOME/.asdf/shims:$PATH"; bin/rails test test/integration/branding_test.rb
      constraints: external link must carry rel="noopener noreferrer"; no layout redesign. Add branding_test asserting
          both the footer partial and /sobre contain the name + href.

- [ ] T3.4 (normal) Add the cornucopia console-log easter egg
      touches: app/javascript/application.js
      do: Append a console banner easter egg (req 6). `app/javascript/application.js` currently reads EXACTLY these
          four lines (plus trailing newline):
          `// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails`
          `import "@hotwired/turbo-rails"`
          `import "controllers"`
          ``
          `Turbo.config.drive.progressBarDelay = 200`
          APPEND the following block VERBATIM to the end of the file (after the Turbo.config line). It prints a
          cornucopia — "horn of plenty", a symbol of abundance, on-theme for a food-price app — then the message.
          Copy the block exactly, including the message string "Liked what you saw? Visit my website":
          snippet-begin (append verbatim):

          // Console easter egg — cornucopia (horn of plenty), a symbol of abundance
          console.log(`
               .-"""-.
             .'  🌽🍇  '.
            /  🍎🥕🍊🍇  \\
            \\   ~~~~~~~   /
             '.__________.'
              Tá Justo?
          `)
          console.log(
            "%cLiked what you saw? Visit my website — https://gustavoneiva.dev",
            "font-size:14px;color:#035925;font-weight:bold"
          )
          snippet-end
      accept:
          Given the app JS loads in a browser
          When devtools console is open
          Then it prints cornucopia/abundance ASCII art AND the line "Liked what you saw? Visit my website"
      verify: grep -q 'Liked what you saw? Visit my website' app/javascript/application.js && grep -q 'cornucopia' app/javascript/application.js && echo OK
      constraints: no new imports; keep the existing four lines untouched and only append. No JS test runner: the
          grep self-check is the gate.

- [ ] T3.5 (normal) Update README to document the new features (deflated chart, filter integrity, pt-BR, branding)
      touches: README.md
      do: The README describes the three surfaces but not the changes this plan ships. Make these EXACT edits so a
          reader (and future agents) know the current behavior:

          (A) In the "🎯 What It Does" list, the product-detail bullet currently reads exactly:
              FIND:
              `3. **\`/produtos/:slug\` — Product Detail** — Price-history line chart +`
              `   seasonality chart + verdict calculator.`
              REPLACE:
              `3. **\`/produtos/:slug\` — Product Detail** — Inflation-adjusted (IPCA, R$ de hoje)`
              `   price-history line chart + seasonality overlay (toggled via CSS, no redraw) +`
              `   verdict calculator. Chart filters (period / variant) preserve all other selected filters.`

          (B) In the "🧠 Verdict Engine" section, append one bullet after the `PriceHistory` line. FIND:
              `- **\`PriceHistory\`** + **\`SeasonalityCalculator\`** — percentile bands & trends`
              REPLACE:
              `- **\`PriceHistory\`** + **\`SeasonalityCalculator\`** — percentile bands & trends`
              `- **\`ChartSeries\`** — detail-chart series; deflates to real terms (IPCA série 1737, base = latest`
              `  published month, forward-filled) with graceful nominal fallback when the index is missing/stale`

          (C) At the very end, ABOVE the final line `**Built with care in Rio de Janeiro 🇧🇷**`, insert an
              attribution line. FIND:
              `**Built with care in Rio de Janeiro 🇧🇷**`
              REPLACE:
              `Feito por [Luiz Gustavo Zincone Neiva](https://gustavoneiva.dev).`
              ``
              `**Built with care in Rio de Janeiro 🇧🇷**`

          Reason: keep the README truthful about deflation, filter integrity, the CSS toggle, and authorship (reqs
          1–7). English README copy is fine (it is already in English); the app UI stays pt-BR.
      accept:
          Given README.md
          When read after this task
          Then it mentions the inflation-adjusted (IPCA) chart, filter preservation, the CSS seasonality toggle,
          the ChartSeries deflation bullet, AND credits Luiz Gustavo Zincone Neiva linking gustavoneiva.dev
      verify: grep -q 'Inflation-adjusted (IPCA' README.md && grep -q 'gustavoneiva.dev' README.md && grep -q 'ChartSeries' README.md && echo OK
      constraints: doc-only; do not restructure the README or touch other sections. Exact string edits above.

---

## Definition of done
- All tasks `[x]`.
- `bin/rubocop && bin/rails test` green on a clean checkout.
- Seasonality checkbox hides/shows the line via CSS with no D3 redraw (T2.1 grep + no `showSeasonalValueChanged`).
- Detail chart plots deflated (real-terms, IPCA) prices with graceful nominal fallback; legend says "R$ de hoje".
- Switching chart period or variant preserves every other query param (check_price etc.).
- /precos época pills render in full at desktop and ≤768px (no clipping).
- No "checker" anglicism remains in `app/views` or `app/assets` (verificador/consulta throughout).
- Author name + gustavoneiva.dev on footer and /sobre; console easter egg prints on load.
- README documents the deflated (IPCA) chart, filter preservation, CSS seasonality toggle, and author attribution.
- Everything **staged** for user review (not committed).

## Non-goals (explicitly OUT)
- Re-deflating the verdict/timing services (already correct — do not touch).
- Adding a BCB live-fetch or new index series (série 1737/188 ingestion already exists).
- A JS test harness (three JS lines are gated by grep + Rails integration markup tests).
- A full visual redesign of /precos beyond fixing pill clipping + column layout.
- INPC support in the chart (IPCA only, matching the existing época tags).
- Any real deploy / domain / infra change.
