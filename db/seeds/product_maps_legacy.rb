# Legacy ProductMap Seeds — CEASA-RJ 2022-01 to 2023-02 era
# Built from dry-ingesting 3 legacy fixtures (2022-01-25, 2022-12-30, 2023-01-02).
# Maps only the 33 CORE-BASKET unmapped rows (validate_mapping gate).
# Long-tail (ALFACE CRESPA, TOMATE LONGA VIDA, CEBOLA, BANANA variants, etc.)
# route to pending_matches — acceptable per plan §L3.4.
# Idempotent: find_or_create_by! on natural key.

puts "Seeding legacy product maps..."

def legacy_map(section, raw_product, raw_tipo, product_slug, variant_name)
  product = Product.find_by!(slug: product_slug)
  variant = product.variants.find_by!(name: variant_name)
  ProductMap.find_or_create_by!(
    market:      "ceasa-rj",
    section:     section,
    raw_product: raw_product,
    raw_tipo:    raw_tipo.to_s
  ) do |pm|
    pm.product = product
    pm.variant = variant
  end
end

# ── Section 1: Frutas Nacionais ──────────────────────────────────────────────

# MAMÃO — children have own parens with their tipo embedded
# Raw: (1, "MAMÃO", "formosa/comum /comprido") and (1, "MAMÃO", "PAPAYA / HAVAI")
legacy_map(1, "MAMÃO", "formosa/comum /comprido", "mamao", "Formosa")
legacy_map(1, "MAMÃO", "PAPAYA / HAVAI",           "mamao", "Papaya/Havai")

# MANGA — extra varieties not in modern map; map to closest existing variant
# Modern has: Espada, Palmer, Tommy Atkins
legacy_map(1, "MANGA", "Keit",       "manga", "Tommy Atkins")
legacy_map(1, "MANGA", "Carlotinha", "manga", "Tommy Atkins")
legacy_map(1, "MANGA", "Haden",      "manga", "Tommy Atkins")
legacy_map(1, "MANGA", "Rosa",       "manga", "Espada")

# MAÇÃ NACIONAL — tipos are variety names (casing differs from modern "NACIONAL Fuji")
legacy_map(1, "MAÇÃ", "Fuji", "maca", "Nacional Fuji")
legacy_map(1, "MAÇÃ", "Gala", "maca", "Nacional Gala")

# MORANGO — extra tipo "Especial" maps to Extra; "Nectarina" is a misplaced fruit
legacy_map(1, "MORANGO", "Especial",  "morango",   "Extra")
legacy_map(1, "MORANGO", "Nectarina", "nectarina", "Nacional")  # placed under MORANGO in legacy PDF

# ── Section 2: Frutas Importadas ─────────────────────────────────────────────

# MAÇÃ IMPORTADA — exact-casing of tipo names differs from modern map
# Some live PDFs compress "Red delicious" → "Reddelicious"; map both variants.
legacy_map(2, "MAÇÃ", "Gala",                    "maca-importada", "Importada Gala")
legacy_map(2, "MAÇÃ", "Grand smith argentina",    "maca-importada", "Importada Grand Smith")
legacy_map(2, "MAÇÃ", "Red delicious argentina",  "maca-importada", "Importada Red Delicious")
legacy_map(2, "MAÇÃ", "Reddelicious argentina",   "maca-importada", "Importada Red Delicious")  # compressed layout
legacy_map(2, "MAÇÃ", "Red delicious americana",  "maca-importada", "Importada Red Delicious")
legacy_map(2, "MAÇÃ", "Reddelicious americana",   "maca-importada", "Importada Red Delicious")  # compressed layout
legacy_map(2, "MAÇÃ", "Red delicious francesa",   "maca-importada", "Importada Red Delicious")
legacy_map(2, "MAÇÃ", "Reddelicious francesa",    "maca-importada", "Importada Red Delicious")  # compressed layout

# UVA IMPORTADA — varieties not in modern map mapped to closest existing variant
# Some live PDFs compress "Red globe" → "Redglobe" due to column layout; map both.
legacy_map(2, "UVA", "Red globe",  "uva-importada", "Red Globe Importada Extra")
legacy_map(2, "UVA", "Redglobe",   "uva-importada", "Red Globe Importada Extra")  # compressed layout variant
legacy_map(2, "UVA", "Thompson",   "uva-importada", "Thompson Importada Extra")
legacy_map(2, "UVA", "Moscatel",   "uva-importada", "Red Globe Importada Extra")
legacy_map(2, "UVA", "Columbian",  "uva-importada", "Red Globe Importada Extra")
legacy_map(2, "UVA", "Almeria",    "uva-importada", "Red Globe Importada Extra")
legacy_map(2, "UVA", "Emperor",    "uva-importada", "Red Globe Importada Extra")

# ── Section 3: Hortaliças Fruto ──────────────────────────────────────────────

# ABÓBORA — types that differ in casing from modern map
# Modern: "MORANGA BABY" / "MORANGA HÍBRIDA"; legacy: "Moranga Baby" / "Moranga híbrida"
legacy_map(3, "ABÓBORA", "Moranga Baby",    "abobora", "Moranga Baby")
legacy_map(3, "ABÓBORA", "Moranga híbrida", "abobora", "Moranga Híbrida")

# Second-quality (Especial) → map to first-quality (Extra) variant
legacy_map(3, "BERINJELA", "Especial", "berinjela", "Extra")
legacy_map(3, "CHUCHU",    "Especial", "chuchu",    "Extra")
legacy_map(3, "QUIABO",    "Especial", "quiabo",    "Extra")

# ── Section 4: Hortaliças Folha/Flor ────────────────────────────────────────

# Mixed-case product names in legacy vs ALL-CAPS in modern map
# "Coentro".upcase = "COENTRO" → detected as core basket; exact map key differs
legacy_map(4, "Coentro", "", "coentro", "Comum")
legacy_map(4, "Rúcula",  "", "rucula",  "Comum")
legacy_map(4, "Salsa",   "", "salsa",   "Comum")

# ── Section 5: Hortaliças Raiz/Bulbo ────────────────────────────────────────

# BETERRABA Especial → Extra (same product, lower grade)
legacy_map(5, "BETERRABA", "Especial", "beterraba", "Extra")

# CENOURA — "Extra A" already covered by modern map (1, "CENOURA", "Extra A")
# Extra (without A) and Especial → both map to Extra A
legacy_map(5, "CENOURA", "Extra",    "cenoura", "Extra A")
legacy_map(5, "CENOURA", "Especial", "cenoura", "Extra A")

# ── Section 7: Pescados ──────────────────────────────────────────────────────

# "Batata" in section 7 is the fish "peixe batata" (not the vegetable)
# All legacy occurrences are Sem cotação; mapped here to avoid core-basket false positive
# (CoreBasket.includes_raw? sees "BATATA" in raw_product and flags it as core basket)
legacy_map(7, "Batata", "", "pescada", "Comum")

puts "✅ Legacy product maps seeded: #{ProductMap.count} total mappings"
