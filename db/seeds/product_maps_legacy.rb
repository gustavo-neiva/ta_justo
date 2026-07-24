# Legacy ProductMap Seeds — CEASA-RJ 2022-01 to 2023-02 era
# Built from actual production legacy pending_matches (268 bulletins).
# Maps CORE-BASKET products only; long-tail stays in pending_matches.
# Legacy PDFs fold variety into raw_product and put only size/grade in raw_tipo.
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

# ABACAXI — sizes collapse to single variant
legacy_map(1, "ABACAXI PÉROLA / CAMPISTA", "",          "abacaxi", "Pérola Médio")
legacy_map(1, "ABACAXI PÉROLA / CAMPISTA", "Grande",    "abacaxi", "Pérola Médio")
legacy_map(1, "ABACAXI PÉROLA / CAMPISTA", "Médio",     "abacaxi", "Pérola Médio")
legacy_map(1, "ABACAXI PÉROLA / CAMPISTA", "Pequeno",   "abacaxi", "Pérola Médio")

# MANGA — only Tommy Atkins appears in legacy
legacy_map(1, "MANGA TOMMY ATKINS", "", "manga", "Tommy Atkins")

# BANANA — all variants, sizes/grades collapse to single variant each
legacy_map(1, "BANANA MAÇÃ", "especial", "banana", "Maçã Extra")
legacy_map(1, "BANANA MAÇÃ", "extra",     "banana", "Maçã Extra")
# NOTE: raw_product uses curly apostrophe (U+2019); variant uses straight (U+0027)
legacy_map(1, "BANANA NANICA/D'''ÁGUA", "Especial", "banana", "Nanica/D'Água Extra")
legacy_map(1, "BANANA NANICA/D'''ÁGUA", "Extra",     "banana", "Nanica/D'Água Extra")
legacy_map(1, "BANANA OURO", "", "banana", "Ouro")
legacy_map(1, "BANANA PACOVAN", "", "banana", "Pacovan")
legacy_map(1, "BANANA PRATA CLIMATIZADA", "Especal", "banana", "Prata Extra")  # typo in PDF
legacy_map(1, "BANANA PRATA CLIMATIZADA", "Extra",    "banana", "Prata Extra")
legacy_map(1, "Banana Figo", "", "banana", "Figo")
legacy_map(1, "BANANA da TERRA", "", "banana", "Da Terra")
legacy_map(1, "BANANA daTERRA", "",  "banana", "Da Terra")  # alternate spacing

# UVA — sizes collapse to single variant each
legacy_map(1, "UVA BENITAKA", "Extra", "uva", "Benitaka Extra")
legacy_map(1, "UVA ITALIA", "Extra",          "uva", "Italia Extra")
legacy_map(1, "UVA ITALIA", "Extra – 10x1",   "uva", "Italia Extra")
legacy_map(1, "UVA ITALIA", "Uva Thompson – Extra 10x1", "uva", "Thompson Nacional")
legacy_map(1, "Uva Red Globe", "", "uva", "Red Globe Nacional")
legacy_map(1, "Uva Rosada / Niagra – Extra",       "", "uva", "Rosada/Niagara Extra")
legacy_map(1, "Uva Rosada / Niagra – Extra 10x1", "", "uva", "Rosada/Niagara Extra")
legacy_map(1, "Uva Rubi – Extra", "", "uva", "Rubi Extra")

# LARANJA — sizes collapse to single variant each
legacy_map(1, "LARANJA BAHIA", "Grande",  "laranja", "Bahia Grande")
legacy_map(1, "LARANJA BAHIA", "Média",   "laranja", "Bahia Grande")
legacy_map(1, "LARANJA BAHIA", "Pequena", "laranja", "Bahia Grande")

legacy_map(1, "LARANJA LIMA", "Grande",  "laranja", "Lima")
legacy_map(1, "LARANJA LIMA", "Média",   "laranja", "Lima")
legacy_map(1, "LARANJA LIMA", "Pequena", "laranja", "Lima")

legacy_map(1, "LARANJA NATAL", "Grande",  "laranja", "Natal Grande")
legacy_map(1, "LARANJA NATAL", "Média",   "laranja", "Natal Grande")
legacy_map(1, "LARANJA NATAL", "Pequena", "laranja", "Natal Grande")

legacy_map(1, "LARANJA PÊRA", "Grande",  "laranja", "Pêra Grande")
legacy_map(1, "LARANJA PÊRA", "Média",   "laranja", "Pêra Grande")
legacy_map(1, "LARANJA PÊRA", "Pequena", "laranja", "Pêra Grande")

legacy_map(1, "LARANJA SELETA", "Grande",  "laranja", "Seleta Grande")
legacy_map(1, "LARANJA SELETA", "Média",   "laranja", "Seleta Grande")
legacy_map(1, "LARANJA SELETA", "Pequena", "laranja", "Seleta Grande")

legacy_map(1, "LARANJA VALENCIA", "Grande",  "laranja", "Valencia Grande")
legacy_map(1, "LARANJA VALENCIA", "Média",   "laranja", "Valencia Grande")
legacy_map(1, "LARANJA VALENCIA", "Pequena", "laranja", "Valencia Grande")

# LARANJA CAMPISTA — no exact modern variant; map to closest (Pêra Grande)
legacy_map(1, "LARANJA CAMPISTA", "Grande",  "laranja", "Pêra Grande")
legacy_map(1, "LARANJA CAMPISTA", "Média",   "laranja", "Pêra Grande")
legacy_map(1, "LARANJA CAMPISTA", "Pequena", "laranja", "Pêra Grande")

# Laranja Lima da Pérsia (actually a lime, not orange)
legacy_map(1, "Laranja Lima da Pérsia", "", "lima", "Comum")

# Laranja Kinkan (kumquat)
legacy_map(1, "Laranja Kinkan", "", "laranja-kinkan", "Importada")
legacy_map(1, "LaranjaKinkan", "",  "laranja-kinkan", "Importada")  # no-space variant

# LIMÃO
legacy_map(1, "Limão Siciliano Nac.", "", "limao", "Siciliano Nacional")
legacy_map(1, "Limão Tahiti", "", "limao", "Taiti")

# MELANCIA — sizes collapse to single variant
legacy_map(1, "MELANCIA REDONDA", "Grande",  "melancia", "Grande")
legacy_map(1, "MELANCIA REDONDA", "Média",   "melancia", "Grande")
legacy_map(1, "MELANCIA REDONDA", "Pequena", "melancia", "Grande")

# MELÃO — tipos collapse to single variant each (use middle tipo as canonical)
legacy_map(1, "MELÃO AMARELO", "Tipo 05", "melao", "Amarelo Tipo 5")
legacy_map(1, "MELÃO AMARELO", "Tipo 06", "melao", "Amarelo Tipo 5")
legacy_map(1, "MELÃO AMARELO", "Tipo 07", "melao", "Amarelo Tipo 5")
legacy_map(1, "MELÃO AMARELO", "Tipo 08", "melao", "Amarelo Tipo 5")
legacy_map(1, "MELÃO AMARELO", "Tipo 09", "melao", "Amarelo Tipo 5")

legacy_map(1, "MELÃO DE REDE", "Tipo 04",       "melao", "De Rede Tipo 4")
legacy_map(1, "MELÃO DE REDE", "Tipo 05",       "melao", "De Rede Tipo 4")
legacy_map(1, "MELÃO DE REDE", "Tipo 06",       "melao", "De Rede Tipo 4")
legacy_map(1, "MELÃO DE REDE", "Tipo 07",       "melao", "De Rede Tipo 4")
legacy_map(1, "MELÃO DE REDE", "00*Tipo 07",    "melao", "De Rede Tipo 4")  # formatting quirk

legacy_map(1, "MELÃO PELE DE SAPO", "Tipo 04", "melao", "Pele de Sapo Tipo 4")
legacy_map(1, "MELÃO PELE DE SAPO", "Tipo 05", "melao", "Pele de Sapo Tipo 4")
legacy_map(1, "MELÃO PELE DE SAPO", "Tipo 06", "melao", "Pele de Sapo Tipo 4")

# MARACUJÁ
legacy_map(1, "Maracujá Azedo", "", "maracuja", "Comum")

# TANGERINA — grades collapse to single variant each
legacy_map(1, "TANGERINA COMUM / RIO", "Extra", "tangerina", "Comum/Rio Extra")
legacy_map(1, "TANGERINA MANDARIM / MANDARINA", "Extra", "tangerina", "Comum/Rio Extra")  # closest variant
legacy_map(1, "TANGERINA MURCOTT", "Especial", "tangerina", "Murcott Extra")
legacy_map(1, "TANGERINA MURCOTT", "Extra",     "tangerina", "Murcott Extra")
legacy_map(1, "TANGERINA PONKAN", "Especial", "tangerina", "Ponkan Extra")
legacy_map(1, "TANGERINA PONKAN", "Extra",     "tangerina", "Ponkan Extra")

# ── Section 2: Frutas Importadas ─────────────────────────────────────────────

# LIMÃO SICILIANO IMPORTADO
legacy_map(2, "Limão siciliano", "", "limao-siciliano-importado", "Importado")

# MAÇÃ IMPORTADA — compressed layout "Reddelicious" variant
legacy_map(2, "MAÇÃ", "Reddelicious americana/argentina/francesa", "maca-importada", "Importada Red Delicious")

# UVA IMPORTADA — compressed layout "Redglobe" variant
legacy_map(2, "UVA", "Redglobe", "uva-importada", "Red Globe Importada Extra")

# ── Section 3: Hortaliças Fruto ──────────────────────────────────────────────

# TOMATE
legacy_map(3, "TOMATE LONGA VIDA", "Extra A",  "tomate", "Extra AA")
legacy_map(3, "TOMATE LONGA VIDA", "Extra AA", "tomate", "Extra AA")
legacy_map(3, "Tomate Cereja", "", "tomate", "Cereja")

# ABOBRINHA
legacy_map(3, "ABOBRINHA ITALIANA", "Especial", "abobrinha", "Italiana Extra")
legacy_map(3, "ABOBRINHA ITALIANA", "Extra",     "abobrinha", "Italiana Extra")
legacy_map(3, "ABOBRINHA MENINA", "Extra",       "abobrinha", "Menina Extra")

# PEPINO
legacy_map(3, "PEPINO COMUM", "Especial", "pepino", "Comum Extra")
legacy_map(3, "PEPINO COMUM", "Extra",     "pepino", "Comum Extra")
legacy_map(3, "Pepino Japonês", "", "pepino", "Japonês")

# PIMENTÃO
legacy_map(3, "PIMENTÃO VERDE", "Extra",  "pimentao", "Verde Extra A")
legacy_map(3, "PIMENTÃO VERDE", "Extra A", "pimentao", "Verde Extra A")
legacy_map(3, "Pimentão Amarelo", "", "pimentao", "Amarelo")
legacy_map(3, "Pimentão Vermelho", "", "pimentao", "Vermelho")

# ── Section 4: Hortaliças Folha/Flor ────────────────────────────────────────

# ALFACE
legacy_map(4, "ALFACE CRESPA", "Especial", "alface", "Crespa Extra")
legacy_map(4, "ALFACE CRESPA", "Extra",     "alface", "Crespa Extra")
legacy_map(4, "ALFACE LISA", "Especial", "alface", "Lisa Extra")
legacy_map(4, "ALFACE LISA", "Extra",     "alface", "Lisa Extra")

# REPOLHO
legacy_map(4, "REPOLHO VERDE", "Grande",  "repolho", "Verde Grande")
legacy_map(4, "REPOLHO VERDE", "Médio",   "repolho", "Verde Grande")
legacy_map(4, "REPOLHO VERDE", "Pequeno", "repolho", "Verde Grande")
legacy_map(4, "Repolho Roxo", "", "repolho", "Roxo")

# COUVE
legacy_map(4, "Couve Comum", "", "couve", "Comum")
legacy_map(4, "Couve Bruxelas", "", "couve", "Bruxelas")

# BRÓCOLIS (not in core basket list but present in pending_matches)
legacy_map(4, "Brócolis Americana", "", "brocolis", "Americana")
legacy_map(4, "Brócolis Comum", "", "brocolis", "Comum")

# CHEIRO VERDE (not in core basket list but present in pending_matches)
legacy_map(4, "Cheiro Verde", "", "cheiro-verde", "Verde")

# ALHO-PORÓ (not in core basket list but present in pending_matches)
legacy_map(4, "Alho-poró", "", "alho-poro", "Comum")

# COUVE-FLOR — sizes collapse to single variant; "Endívia" is a misplaced entry
legacy_map(4, "COUVE-FLOR", "Média",    "couve-flor", "Grande")
legacy_map(4, "COUVE-FLOR", "Pequena",  "couve-flor", "Grande")
legacy_map(4, "COUVE-FLOR", "Pregado",  "couve-flor", "Grande")
legacy_map(4, "COUVE-FLOR", "Endívia",  "endivia", "Comum")  # mislabeled in PDF

# ── Section 5: Hortaliças Raiz/Bulbo ────────────────────────────────────────

# ALHO
legacy_map(5, "ALHO IMPOR.", "Branco / China", "alho", "Importado Branco")
legacy_map(5, "ALHO IMPOR.", "Roxo / Arg",     "alho", "Importado Roxo")
legacy_map(5, "ALHO IMPOR.", "Roxo / Chile",   "alho", "Importado Roxo")
legacy_map(5, "ALHO IMPOR.", "Roxo / China",   "alho", "Importado Roxo")
legacy_map(5, "ALHO IMPOR.", "Roxo / Esp",     "alho", "Importado Roxo")
legacy_map(5, "ALHO NACIONAL", "Branco",        "alho", "Nacional Branco")
legacy_map(5, "ALHO NACIONAL", "Roxo Primeira", "alho", "Nacional Roxo")
legacy_map(5, "ALHO NACIONAL", "Roxo Segunda",  "alho", "Nacional Roxo")

# BATATA
legacy_map(5, "BATATA BAROA", "Especial", "batata", "Baroa Extra")
legacy_map(5, "BATATA BAROA", "Extra",     "batata", "Baroa Extra")
legacy_map(5, "BATATA DOCE", "Especial", "batata", "Doce Extra")
legacy_map(5, "BATATA DOCE", "Extra",     "batata", "Doce Extra")
legacy_map(5, "BATATA INGLESA COMUM", "Especial",     "batata", "Comum Especial")
legacy_map(5, "BATATA INGLESA COMUM", "Primeira S 25", "batata", "Comum Especial")
legacy_map(5, "BATATA INGLESA COMUM", "Segunda",       "batata", "Comum Especial")
legacy_map(5, "BATATA INGLESA LISA", "",        "batata", "Lisa Especial")
legacy_map(5, "BATATA INGLESA LISA", "Especial", "batata", "Lisa Especial")
legacy_map(5, "BATATA INGLESA LISA", "Primeira", "batata", "Lisa Especial")
legacy_map(5, "BATATA INGLESA LISA", "Segunda",  "batata", "Lisa Especial")
legacy_map(5, "BATATA YACON", "", "batata", "Yacon")

# CEBOLA — origins collapse to single variant each
legacy_map(5, "CEBOLA IMPORTADA", "Pera / Arg", "cebola", "Importada Branca")
legacy_map(5, "CEBOLA IMPORTADA", "Pera / Hol", "cebola", "Importada Branca")
legacy_map(5, "CEBOLA IMPORTADA", "Pera / Per", "cebola", "Importada Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / MG", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / PE", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / PR", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / RS", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / SC", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA NAC. BRANCA", "Pera / SP", "cebola", "Nacional Branca")
legacy_map(5, "CEBOLA Nac. Roxa", "", "cebola", "Nacional Roxa")

# INHAME
legacy_map(5, "INHAME CHINÊS", "Especial",      "inhame", "Chinês Extra")
legacy_map(5, "INHAME CHINÊS", "Extra",          "inhame", "Chinês Extra")
legacy_map(5, "INHAME CHINÊS", "Inhame de cabeça", "inhame", "De Cabeça")

# ── Section 6: Ovos ──────────────────────────────────────────────────────────

# OVOS — sizes collapse to single variant each
legacy_map(6, "OVOS", "Extra", "ovo", "Branco Extra")
legacy_map(6, "OVOS", "Grande", "ovo", "Branco Extra")
legacy_map(6, "OVOS", "Médio", "ovo", "Branco Extra")
legacy_map(6, "OVOS", "Pequeno", "ovo", "Branco Extra")
legacy_map(6, "OVOS VERMELHOS", "Extra", "ovo", "Vermelho Extra")
legacy_map(6, "OVOS VERMELHOS", "Grande", "ovo", "Vermelho Extra")
legacy_map(6, "OVOS VERMELHOS", "Médio", "ovo", "Vermelho Extra")
legacy_map(6, "OVOS VERMELHOS", "Pequeno", "ovo", "Vermelho Extra")
legacy_map(6, "OVOS DE CODORNA", "", "ovo-codorna", "De Codorna")

# ── Section 7: Pescados ──────────────────────────────────────────────────────

# "Batata" in section 7 is the fish "peixe batata" (not the vegetable)
# All legacy occurrences are Sem cotação; mapped here to avoid core-basket false positive
# (CoreBasket.includes_raw? sees "BATATA" in raw_product and flags it as core basket)
legacy_map(7, "Batata", "", "pescada", "Comum")

puts "✅ Legacy product maps seeded: #{ProductMap.count} total mappings"
