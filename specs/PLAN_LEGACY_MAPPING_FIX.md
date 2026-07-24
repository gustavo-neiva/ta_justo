# PLAN — Fix Legacy Mapping Discrepancy (CEASA-RJ pre-March 2023)

**Status:** ✅ COMPLETE · **Created:** 2026-06-21 · **Completed:** 2026-06-21
**Goal:** Get the **core basket** (banana, tomate, alface, batata, cebola, ovo,
abacaxi, manga, uva, laranja, limão, melão, melancia, tangerina, maracujá, abobrinha,
pepino, pimentão, repolho, couve, alho, inhame…) to carry legacy prices back to 2022,
so charts start at **2022-01** instead of **2023-03-01**.

---

## 0. TL;DR

The backfill worked (268 legacy bulletins ingested) but only **37 of 238 variants**
got legacy prices. Reason: `db/seeds/product_maps_legacy.rb` was built from **3
atypical fixtures** and **does not match the real legacy PDF structure**. ~130 of the
~434 legacy `pending_matches` are core-basket rows with no `ProductMap` → no `Price`.

**Fix (3 steps):**
1. Rewrite the legacy mapping seed to match the **actual** legacy `raw_product`/`raw_tipo`
   shapes pulled live from `pending_matches`.
2. Re-seed maps, delete legacy bulletins, re-run the backfill.
3. Verify charts extend to 2022 and modern (≥2023-03-01) data is untouched.

---

## 1. Root cause (verified live, 2026-06-21)

### 1.1 The structural mismatch

Modern PDFs split product and variety into **two** columns; legacy PDFs **fold the
variety into `raw_product`** and put only the size/grade in `raw_tipo`:

| | `raw_product` | `raw_tipo` |
|---|---|---|
| **Modern** | `BANANA` | `NANICA/D'ÁGUA Extra` |
| **Legacy** | `BANANA NANICA/D'ÁGUA` | `Extra` |
| **Modern** | `TOMATE` | `Extra AA` |
| **Legacy** | `TOMATE LONGA VIDA` | `Extra AA` |
| **Modern** | `OVO` | `VERMELHO Extra` |
| **Legacy** | `OVOS VERMELHOS` | `Extra` |

`VariantMatcher#match` does an **exact** `find_by(market, section, raw_product, raw_tipo)`
lookup (`app/services/ceasa_rio/variant_matcher.rb`). The existing legacy seed maps keys
like `(1, "MANGA", "Keit")` that **never appear** in the real data — the real key is
`(1, "MANGA TOMMY ATKINS", "")`. So nearly every core-basket legacy row fell through to
`pending_matches`.

### 1.2 Current state (dev DB)

```
Bulletins total:                 1037
Legacy bulletins (<2023-03-01):   268   ← ingested OK
PendingMatch total:               434
Variants with legacy prices:       37   ← only what the old seed happened to hit
```

### 1.3 Why the old seed "passed" CI

`rake ceasa:validate_mapping` validates against `test/fixtures/files/ceasa/**` — the 3
atypical fixtures the old seed was tuned to. Those fixtures are **not representative** of
the 268 production legacy bulletins. CI green ≠ production mapped.

---

## 2. Scope — core-basket legacy keys to map

Pulled live from `pending_matches` (full list verified). Map every row below. Sizes
(Grande/Média/Pequena, Tipo NN) and grades (Extra/Especial/Primeira/Segunda) collapse to
the single existing canonical variant — history is "looks populated", exact grade is
secondary (per `PLAN_LEGACY_BACKFILL.md` §L3.4).

> Note: `NANICA/D'ÁGUA` uses a **curly apostrophe** (U+2019) in raw data but a **straight**
> one in the variant name — already handled in modern seed; replicate exactly.

### Section 1 — Frutas

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `ABACAXI PÉROLA / CAMPISTA` | `""`, `Pequeno`, `Médio`, `Grande` | abacaxi / Pérola Médio |
| `MANGA TOMMY ATKINS` | `""` | manga / Tommy Atkins |
| `BANANA MAÇÃ` | `especial`, `extra` | banana / Maçã Extra |
| `BANANA NANICA/D'ÁGUA` (U+2019) | `Especial`, `Extra` | banana / Nanica/D'Água Extra |
| `BANANA OURO` | `""` | banana / Ouro |
| `BANANA PACOVAN` | `""` | banana / Pacovan |
| `BANANA PRATA CLIMATIZADA` | `Especal`(sic), `Extra` | banana / Prata Extra |
| `Banana Figo` | `""` | banana / Figo |
| `BANANA da TERRA`, `BANANA daTERRA` | `""` | banana / Da Terra |
| `UVA BENITAKA` | `Extra` | uva / Benitaka Extra |
| `UVA ITALIA` | `Extra`, `Extra – 10x1` | uva / Italia Extra |
| `UVA ITALIA` | `Uva Thompson – Extra 10x1` | uva / Thompson Nacional |
| `Uva Red Globe` | `""` | uva / Red Globe Nacional |
| `Uva Rosada / Niagra – Extra` | `""` | uva / Rosada/Niagara Extra |
| `Uva Rosada / Niagra – Extra 10x1` | `""` | uva / Rosada/Niagara Extra |
| `Uva Rubi – Extra` | `""` | uva / Rubi Extra |
| `LARANJA BAHIA` | `Grande`, `Média`, `Pequena` | laranja / Bahia Grande |
| `LARANJA LIMA` | `Grande`, `Média`, `Pequena` | laranja / Lima |
| `LARANJA NATAL` | `Grande`, `Média`, `Pequena` | laranja / Natal Grande |
| `LARANJA PÊRA` | `Grande`, `Média`, `Pequena` | laranja / Pêra Grande |
| `LARANJA SELETA` | `Grande`, `Média`, `Pequena` | laranja / Seleta Grande |
| `LARANJA VALENCIA` | `Grande`, `Média`, `Pequena` | laranja / Valencia Grande |
| `LARANJA CAMPISTA` | `Grande`, `Média`, `Pequena` | laranja / Pêra Grande (closest) |
| `Laranja Lima da Pérsia` | `""` | lima / Comum |
| `Laranja Kinkan`, `LaranjaKinkan` | `""` | laranja-kinkan / Importada |
| `Limão Siciliano Nac.` | `""` | limao / Siciliano Nacional |
| `Limão Tahiti` | `""` | limao / Taiti |
| `MELANCIA REDONDA` | `Grande`, `Média`, `Pequena` | melancia / Grande |
| `MELÃO AMARELO` | `Tipo 05`–`Tipo 09` | melao / Amarelo Tipo 5 |
| `MELÃO DE REDE` | `Tipo 04`–`Tipo 07`, `00*Tipo 07` | melao / De Rede Tipo 4 |
| `MELÃO PELE DE SAPO` | `Tipo 04`–`Tipo 06` | melao / Pele de Sapo Tipo 4 |
| `Maracujá Azedo` | `""` | maracuja / Comum |
| `TANGERINA COMUM / RIO` | `Extra` | tangerina / Comum/Rio Extra |
| `TANGERINA MANDARIM / MANDARINA` | `Extra` | tangerina / Comum/Rio Extra (closest) |
| `TANGERINA MURCOTT` | `Especial`, `Extra` | tangerina / Murcott Extra |
| `TANGERINA PONKAN` | `Especial`, `Extra` | tangerina / Ponkan Extra |

### Section 2 — Frutas Importadas

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `Limão siciliano` | `""` | limao-siciliano-importado / Importado |
| `MAÇÃ` | `Reddelicious americana/argentina/francesa` | maca-importada / Importada Red Delicious |
| `UVA` | `Redglobe` | uva-importada / Red Globe Importada Extra |

### Section 3 — Hortaliças Fruto

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `TOMATE LONGA VIDA` | `Extra A`, `Extra AA` | tomate / Extra AA |
| `Tomate Cereja` | `""` | tomate / Cereja |
| `ABOBRINHA ITALIANA` | `Especial`, `Extra` | abobrinha / Italiana Extra |
| `ABOBRINHA MENINA` | `Extra` | abobrinha / Menina Extra |
| `PEPINO COMUM` | `Especial`, `Extra` | pepino / Comum Extra |
| `Pepino Japonês` | `""` | pepino / Japonês |
| `PIMENTÃO VERDE` | `Extra`, `Extra A` | pimentao / Verde Extra A |
| `Pimentão Amarelo` | `""` | pimentao / Amarelo |
| `Pimentão Vermelho` | `""` | pimentao / Vermelho |

### Section 4 — Hortaliças Folha/Flor

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `ALFACE CRESPA` | `Especial`, `Extra` | alface / Crespa Extra |
| `ALFACE LISA` | `Especial`, `Extra` | alface / Lisa Extra |
| `REPOLHO VERDE` | `Grande`, `Médio`, `Pequeno` | repolho / Verde Grande |
| `Repolho Roxo` | `""` | repolho / Roxo |
| `Couve Comum` | `""` | couve / Comum |
| `Couve Bruxelas` | `""` | couve / Bruxelas |
| `Brócolis Americana` | `""` | brocolis / Americana |
| `Brócolis Comum` | `""` | brocolis / Comum |
| `Cheiro Verde` | `""` | cheiro-verde / Verde |
| `Alho-poró` | `""` | alho-poro / Comum |
| `COUVE-FLOR` | `Média`, `Pequena`, `Pregado` | couve-flor / Grande |
| `COUVE-FLOR` | `Endívia` (misplaced) | endivia / Comum |

### Section 5 — Hortaliças Raiz/Bulbo

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `ALHO IMPOR.` | `Branco / China` | alho / Importado Branco |
| `ALHO IMPOR.` | `Roxo / Arg`, `Roxo / Chile`, `Roxo / China`, `Roxo / Esp` | alho / Importado Roxo |
| `ALHO NACIONAL` | `Branco` | alho / Nacional Branco |
| `ALHO NACIONAL` | `Roxo Primeira`, `Roxo Segunda` | alho / Nacional Roxo |
| `BATATA BAROA` | `Especial`, `Extra` | batata / Baroa Extra |
| `BATATA DOCE` | `Especial`, `Extra` | batata / Doce Extra |
| `BATATA INGLESA COMUM` | `Especial`, `Primeira S 25`, `Segunda` | batata / Comum Especial |
| `BATATA INGLESA LISA` | `""`, `Especial`, `Primeira`, `Segunda` | batata / Lisa Especial |
| `BATATA YACON` | `""` | batata / Yacon |
| `CEBOLA IMPORTADA` | `Pera / Arg`, `Pera / Hol`, `Pera / Per` | cebola / Importada Branca |
| `CEBOLA NAC. BRANCA` | `Pera / MG/PE/PR/RS/SC/SP` | cebola / Nacional Branca |
| `CEBOLA Nac. Roxa` | `""` | cebola / Nacional Roxa |
| `INHAME CHINÊS` | `Especial`, `Extra` | inhame / Chinês Extra |
| `INHAME CHINÊS` | `Inhame de cabeça` | inhame / De Cabeça |

### Section 6 — Ovos

| raw_product | raw_tipo(s) | → slug / variant |
|---|---|---|
| `OVOS` | `Extra`, `Grande`, `Médio`, `Pequeno` | ovo / Branco Extra |
| `OVOS VERMELHOS` | `Extra`, `Grande`, `Médio`, `Pequeno` | ovo / Vermelho Extra |
| `OVOS DE CODORNA` | `""` | ovo-codorna / De Codorna |

> Section 7 (pescado) already routes correctly; leave as-is.

**Self-check before coding:** the keys above were copied verbatim from `pending_matches`.
Re-run the discovery query (§5.1) at build time and reconcile any new spellings — the
table is the source of truth, not this doc.

---

## 3. Implementation

### 3.1 Rewrite `db/seeds/product_maps_legacy.rb`

Keep the idempotent `legacy_map(section, raw_product, raw_tipo, slug, variant)` helper
(find_or_create_by! on natural key). Replace the body with the §2 tables. Keep the
few **still-valid** existing entries (MAMÃO, MAÇÃ Fuji/Gala, MORANGO, ABÓBORA casing,
section-7 fish-batata) only if they still appear in `pending_matches`; drop the rest.

**Guard rails:**
- `Product.find_by!` / `variants.find_by!` raise on typos → seed fails loud, never
  silently mismaps. Run the seed once to shake out name mismatches before re-ingest.
- Watch the curly-vs-straight apostrophe in `BANANA NANICA/D'ÁGUA`.
- `raw_tipo` empty string must be `""` not `nil` (helper already `.to_s`).

### 3.2 Re-seed + re-ingest

```ruby
# bin/rails runner '...'  (or a one-off rake task)

# 1. Apply the new/updated maps (idempotent)
load Rails.root.join("db/seeds/product_maps_legacy.rb")

# 2. Delete legacy bulletins so the idempotent loader will re-ingest them.
#    Cutover is clean (no modern bulletin < 2023-03-01), so this cannot touch
#    modern data. Prices cascade-delete with their bulletins.
Bulletin.where("price_date < ?", Date.new(2023, 3, 1)).destroy_all

# 3. (Optional) clear stale legacy pending_matches so the re-run leaves only
#    the genuinely-unmapped long tail.
PendingMatch.where(market: "ceasa-rj").where("first_seen < ?", Date.new(2023,3,1)).delete_all

# 4. Re-run the backfill (re-reads archived/served PDFs, re-ingests legacy).
BackfillCeasaRioJob.perform_now
```

> ⚠️ `destroy_all` on bulletins is destructive but safe here: legacy PDFs are archived
> under `storage/ceasa/raw/` and re-fetched by the crawler, and the date cutover
> guarantees no modern rows are in range. **Confirm `Price.where(bulletin: <modern>)`
> counts are unchanged after the run** (§4).

### 3.3 Don't reintroduce the gap

The backfill re-fetches over the network (`sleep 0.8` politeness) — slow but fine.
If re-fetching all 268 is undesirable, prefer re-ingesting from the local archive
(`storage/ceasa/raw/*.pdf`) via `CeasaRio::Loader#ingest` directly instead of the full
crawl. Either path is acceptable; the loader is idempotent.

---

## 4. Verification (acceptance)

```ruby
# Coverage jumped
Bulletin.where("price_date < ?", Date.new(2023,3,1)).count          # ~268 (restored)
Variant.joins(prices: :bulletin)
       .where("bulletins.price_date < ?", Date.new(2023,3,1))
       .distinct.count                                              # ≫ 37 (target ~150+)

# Core basket specifically has 2022 prices
%w[banana tomate alface batata cebola ovo abacaxi manga uva laranja].each do |slug|
  p = Product.find_by(slug: slug)
  n = Price.joins(:bulletin, variant: :product)
           .where(products: { id: p.id })
           .where("bulletins.price_date < ?", Date.new(2023,3,1)).count
  puts "#{slug}: #{n} legacy prices"          # all > 0
end

# Modern data untouched (regression guard)
Bulletin.where("price_date >= ?", Date.new(2023,3,1)).count         # unchanged (769)
```

**Pass criteria:**
1. Each core-basket product has ≥1 legacy price.
2. Earliest chart date for core products is 2022-01-xx.
3. Modern bulletin/price counts unchanged.
4. Remaining legacy `pending_matches` are long-tail only (no core RAW_PRODUCTS).
5. `rake ceasa:validate_mapping` still green.

---

## 5. Appendix — discovery query (source of truth)

### 5.1 List unmapped legacy rows by frequency

```bash
bin/rails runner '
PendingMatch
  .where(market: "ceasa-rj").where.not(section: 7)
  .where("first_seen < ?", Date.new(2023,3,1))
  .order(occurrence_count: :desc)
  .each { |p| puts "s#{p.section} #{p.raw_product.inspect}/#{p.raw_tipo.inspect} (#{p.occurrence_count}x) unit=#{p.raw_unit.inspect}" }
'
```

### 5.2 Filter to core basket only

```bash
bin/rails runner '
core = CoreBasket::RAW_PRODUCTS
PendingMatch.where(market:"ceasa-rj").where.not(section:7)
  .where("first_seen < ?", Date.new(2023,3,1)).order(occurrence_count: :desc)
  .select { |p| up = p.raw_product.to_s.upcase; core.any? { |c| up.include?(c) } }
  .each { |p| puts "s#{p.section} #{p.raw_product.inspect}/#{p.raw_tipo.inspect} (#{p.occurrence_count}x)" }
'
```

---

## 6. Risks & notes

- **Variety collapsing:** Mapping `Média`/`Pequena`/`Especial` to one canonical variant
  blends grades into one series. Acceptable for v1 "looks populated"; a future refinement
  could add grade-specific legacy variants if needed.
- **`LARANJA CAMPISTA` / `TANGERINA MANDARIM`:** no exact modern variant; mapped to the
  closest. Flag in a comment so it's auditable.
- **Long tail stays pending:** abacate varieties, cayenne, figo tipos, goiaba tipos, etc.
  remain in `pending_matches` by design — out of scope.
- **Re-run cost:** ~268 polite fetches (~4 min at 0.8 s). Prefer local-archive re-ingest
  if network re-crawl is unwanted (§3.3).

---

## 7. Completion Summary (2026-06-21)

### Results
- ✅ **268 legacy bulletins** re-ingested (2022-01 to 2023-02)
- ✅ **33,764 legacy prices** loaded (was: 10,987)
- ✅ **107 variants** with legacy prices (was: 37, ↑ from 37)
- ✅ **All 22 core products** have legacy prices starting 2022-01-03
- ✅ **Modern data untouched** (769 bulletins, 151,920 prices)
- ✅ **CI validation still green** (core basket 100% mapped)
- ✅ **No core products in pending_matches** (excluding pescado section 7)

### Key learnings
- The legacy PDF structure differs significantly from modern PDFs (variety folded into raw_product)
- **Curly apostrophe (U+2019)** in `BANANA NANICA/D'ÁGUA` must match exactly in ProductMap
- `pdftotext -layout` compresses two-word names in narrow columns (e.g., "Red delicious" → "Reddelicious")
- "Pescada banana" in section 7 is a fish, not a core fruit (false positive check)

### Files modified
- `db/seeds/product_maps_legacy.rb` — Complete rewrite with 426 mappings from production data

### Verification commands
```ruby
# Check legacy coverage
Bulletin.where("price_date < ?", Date.new(2023,3,1)).count  # => 268
Variant.joins(prices: :bulletin)
  .where("bulletins.price_date < ?", Date.new(2023,3,1)).distinct.count  # => 107

# Verify core basket has 2022 prices
core_slugs = %w[banana tomate alface batata cebola ovo abacaxi manga uva laranja limao melao melancia tangerina maracuja abobrinha pepino pimentao repolho couve alho inhame]
core_slugs.each do |slug|
  p = Product.find_by(slug: slug)
  n = Price.joins(:bulletin, variant: :product)
           .where(products: { id: p.id })
           .where("bulletins.price_date < ?", Date.new(2023,3,1)).count
  puts "#{slug}: #{n} legacy prices"
end
```
