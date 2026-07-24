# ProductMap Seeds — The 100% CEASA-RJ → Product/Variant mapping
# Built from Appendix C (248 tuples verified across 18 Modern PDFs)
# Idempotent: find_or_create_by! on (market, section, raw_product, raw_tipo)

puts "Seeding product maps..."

def map_ceasa(section, raw_product, raw_tipo, product_slug, variant_name)
  product = Product.find_by!(slug: product_slug)
  variant = product.variants.find_by!(name: variant_name)

  ProductMap.find_or_create_by!(
    market: "ceasa-rj",
    section: section,
    raw_product: raw_product,
    raw_tipo: raw_tipo.to_s
  ) do |pm|
    pm.product = product
    pm.variant = variant
  end
end

# SECTION 1 — Frutas Nacionais (66 tuples)
map_ceasa(1, "ABACATE", "", "abacate", "Comum")
map_ceasa(1, "ABACAXI", "ANANÁS Grande", "abacaxi", "Ananás Grande")
map_ceasa(1, "ABACAXI", "PÉROLA Médio", "abacaxi", "Pérola Médio")
map_ceasa(1, "AMEIXA", "NACIONAL", "ameixa", "Nacional")
map_ceasa(1, "AMORA", "", "amora", "Comum")
map_ceasa(1, "ATEMÓIA", "", "atemoia", "Comum")
map_ceasa(1, "BANANA", "DA TERRA", "banana", "Da Terra")
map_ceasa(1, "BANANA", "FIGO", "banana", "Figo")
map_ceasa(1, "BANANA", "MAÇÃ Extra", "banana", "Maçã Extra")
map_ceasa(1, "BANANA", "NANICA/D'ÁGUA Extra", "banana", "Nanica/D'Água Extra")
map_ceasa(1, "BANANA", "NANICA/D’ÁGUA Extra", "banana", "Nanica/D'Água Extra")  # curly apostrophe in raw_tipo (U+2019), straight in variant name
map_ceasa(1, "BANANA", "OURO", "banana", "Ouro")
map_ceasa(1, "BANANA", "PACOVAN", "banana", "Pacovan")
map_ceasa(1, "BANANA", "PRATA Extra", "banana", "Prata Extra")
map_ceasa(1, "CAJÁ", "", "caja", "Comum")
map_ceasa(1, "CAJÚ", "", "caju", "Comum")
map_ceasa(1, "CAQUI", "FUYU", "caqui", "Fuyu")
map_ceasa(1, "CAQUI", "RAMA FORTE A", "caqui", "Rama Forte A")
map_ceasa(1, "CARAMBOLA", "", "carambola", "Comum")
map_ceasa(1, "COCO", "SECO", "coco", "Seco")
map_ceasa(1, "COCO", "VERDE", "coco", "Verde")
map_ceasa(1, "FIGO", "VERDE Tipo 8", "figo", "Verde Tipo 8")
map_ceasa(1, "FRUTA", "DE CONDE/PINHA Tipo 4", "pinha", "Tipo 4")
map_ceasa(1, "GOIABA", "VERMELHA Tipo 12", "goiaba", "Vermelha Tipo 12")
map_ceasa(1, "GRAVIOLA", "", "graviola", "Comum")
map_ceasa(1, "JABOTICABA", "", "jaboticaba", "Comum")
map_ceasa(1, "KIWI", "NACIONAL", "kiwi", "Nacional")
map_ceasa(1, "LARANJA", "BAHIA Grande", "laranja", "Bahia Grande")
map_ceasa(1, "LARANJA", "LIMA", "laranja", "Lima")
map_ceasa(1, "LARANJA", "NATAL Grande", "laranja", "Natal Grande")
map_ceasa(1, "LARANJA", "PÊRA Grande", "laranja", "Pêra Grande")
map_ceasa(1, "LARANJA", "SELETA Grande", "laranja", "Seleta Grande")
map_ceasa(1, "LARANJA", "VALENCIA Grande", "laranja", "Valencia Grande")
map_ceasa(1, "LIMA", "DA PÉRSIA", "lima", "Comum")
map_ceasa(1, "LIMÃO", "SICILIANO NACIONAL", "limao", "Siciliano Nacional")
map_ceasa(1, "LIMÃO", "TAITI", "limao", "Taiti")
map_ceasa(1, "LISCHIA", "", "lichia", "Comum")
map_ceasa(1, "MAMÃO", "FORMOSA", "mamao", "Formosa")
map_ceasa(1, "MAMÃO", "PAPAYA/ HAVAI", "mamao", "Papaya/Havai")
map_ceasa(1, "MANGA", "Espada", "manga", "Espada")
map_ceasa(1, "MANGA", "Palmer", "manga", "Palmer")
map_ceasa(1, "MANGA", "TOMMY ATKINS", "manga", "Tommy Atkins")
map_ceasa(1, "MARACUJÁ", "", "maracuja", "Comum")
map_ceasa(1, "MAÇÃ", "NACIONAL Fuji", "maca", "Nacional Fuji")
map_ceasa(1, "MAÇÃ", "NACIONAL Gala", "maca", "Nacional Gala")
map_ceasa(1, "MELANCIA", "Grande", "melancia", "Grande")
map_ceasa(1, "MELÃO", "AMARELO Tipo 5", "melao", "Amarelo Tipo 5")
map_ceasa(1, "MELÃO", "DE REDE Tipo 4", "melao", "De Rede Tipo 4")
map_ceasa(1, "MELÃO", "PELE DE SAPO Tipo 4", "melao", "Pele de Sapo Tipo 4")
map_ceasa(1, "MORANGO", "Extra", "morango", "Extra")
map_ceasa(1, "NECTARINA", "NACIONAL", "nectarina", "Nacional")
map_ceasa(1, "PITAYA", "", "pitaya", "Comum")
map_ceasa(1, "PÊSSEGO", "NACIONAL", "pessego", "Nacional")
map_ceasa(1, "ROMÃ", "", "roma", "Comum")
map_ceasa(1, "SAPUTI", "", "saputi", "Comum")
map_ceasa(1, "SERIGUELA", "", "seriguela", "Comum")
map_ceasa(1, "TAMARINDO", "", "tamarindo", "Comum")
map_ceasa(1, "TANGERINA", "COMUM / RIO Extra", "tangerina", "Comum/Rio Extra")
map_ceasa(1, "TANGERINA", "MURCOTT Extra", "tangerina", "Murcott Extra")
map_ceasa(1, "TANGERINA", "PONKAN Extra", "tangerina", "Ponkan Extra")
map_ceasa(1, "UVA", "BENITAKA Extra", "uva", "Benitaka Extra")
map_ceasa(1, "UVA", "ITALIA Extra", "uva", "Italia Extra")
map_ceasa(1, "UVA", "RED GLOBE NACIONAL", "uva", "Red Globe Nacional")
map_ceasa(1, "UVA", "ROSADA/NIAGARA Extra", "uva", "Rosada/Niagara Extra")
map_ceasa(1, "UVA", "RUBI Extra", "uva", "Rubi Extra")
map_ceasa(1, "UVA", "THOMPSON NACIONAL", "uva", "Thompson Nacional")
map_ceasa(1, "UVA", "VITÓRIA", "uva", "Vitória")

# SECTION 2 — Frutas Importadas (21 tuples)
map_ceasa(2, "AMEIXA", "IMPORTADA", "ameixa-importada", "Importada")
map_ceasa(2, "CEREJA", "IMPORTADA", "cereja", "Importada")
map_ceasa(2, "DAMASCO", "IMPORTADO", "damasco", "Importado")
map_ceasa(2, "DAMASCO", "IMPORTDAO", "damasco", "Importado")  # typo → same variant
map_ceasa(2, "KIWI", "IMPORTADO", "kiwi-importado", "Importado")
map_ceasa(2, "LARANJA", "KINKAN IMPORTADA", "laranja-kinkan", "Importada")
map_ceasa(2, "LIMÃO", "SICILIANO IMPORTADO", "limao-siciliano-importado", "Importado")
map_ceasa(2, "MAÇÃ", "IMPORTADA Fuji", "maca-importada", "Importada Fuji")
map_ceasa(2, "MAÇÃ", "IMPORTADA Gala", "maca-importada", "Importada Gala")
map_ceasa(2, "MAÇÃ", "IMPORTADA Red Delicious", "maca-importada", "Importada Red Delicious")
map_ceasa(2, "MAÇÃ", "IMPORTDA Grand Smith", "maca-importada", "Importada Grand Smith")  # typo preserved
map_ceasa(2, "NECTARINA", "IMPORTADA", "nectarina-importada", "Importada")
map_ceasa(2, "PITAYA", "IMPORTADA", "pitaya-importada", "Importada")
map_ceasa(2, "PÊRA", "IMPORTADA D´Anjour", "pera", "Importada D'Anjour")
map_ceasa(2, "PÊRA", "IMPORTADA Pacck Triunph", "pera", "Importada Pacck Triunph")
map_ceasa(2, "PÊRA", "IMPORTADA Portuguesa", "pera", "Importada Portuguesa")
map_ceasa(2, "PÊRA", "IMPORTADA Willians", "pera", "Importada Willians")
map_ceasa(2, "PÊRA", "IMPORTADA Winterbarlett", "pera", "Importada Winterbarlett")
map_ceasa(2, "PÊSSEGO", "IMPORTADO", "pessego-importado", "Importado")
map_ceasa(2, "UVA", "RED GLOBE IMPORTADA Extra", "uva-importada", "Red Globe Importada Extra")
map_ceasa(2, "UVA", "THOMPSON IMPORTADA Extra", "uva-importada", "Thompson Importada Extra")

# SECTION 3 — Hortaliças Fruto (31 tuples)
map_ceasa(3, "ABOBRINHA", "ITALIANA Extra", "abobrinha", "Italiana Extra")
map_ceasa(3, "ABOBRINHA", "MENINA Extra", "abobrinha", "Menina Extra")
map_ceasa(3, "ABÓBORA", "Baiana", "abobora", "Baiana")
map_ceasa(3, "ABÓBORA", "Branca", "abobora", "Branca")
map_ceasa(3, "ABÓBORA", "Japonesa", "abobora", "Japonesa")
map_ceasa(3, "ABÓBORA", "MORANGA BABY", "abobora", "Moranga Baby")
map_ceasa(3, "ABÓBORA", "MORANGA HÍBRIDA", "abobora", "Moranga Híbrida")
map_ceasa(3, "ABÓBORA", "Pescoço", "abobora", "Pescoço")
map_ceasa(3, "ABÓBORA", "Sergipana", "abobora", "Sergipana")
map_ceasa(3, "BERINJELA", "Extra", "berinjela", "Extra")
map_ceasa(3, "CHUCHU", "Extra", "chuchu", "Extra")
map_ceasa(3, "ERVILHA", "VAGEM Extra", "ervilha-vagem", "Vagem Extra")
map_ceasa(3, "FEIJÃO", "DE CORDA", "feijao-de-corda", "De Corda")
map_ceasa(3, "JILÓ", "Extra", "jilo", "Extra")
map_ceasa(3, "MAXIXE", "", "maxixe", "Comum")
map_ceasa(3, "MILHO", "VERDE", "milho-verde", "Verde")
map_ceasa(3, "PEPINO", "COMUM Extra", "pepino", "Comum Extra")
map_ceasa(3, "PEPINO", "JAPONÊS", "pepino", "Japonês")
map_ceasa(3, "PIMENTA", "De cheiro", "pimenta", "De Cheiro")
map_ceasa(3, "PIMENTA", "Dedo", "pimenta", "Dedo")
map_ceasa(3, "PIMENTA", "Malagueta", "pimenta", "Malagueta")
map_ceasa(3, "PIMENTÃO", "AMARELO", "pimentao", "Amarelo")
map_ceasa(3, "PIMENTÃO", "VERDE Extra A", "pimentao", "Verde Extra A")
map_ceasa(3, "PIMENTÃO", "VERMELHO", "pimentao", "Vermelho")
map_ceasa(3, "QUIABO", "Extra", "quiabo", "Extra")
map_ceasa(3, "TOMATE", "CEREJA", "tomate", "Cereja")
map_ceasa(3, "TOMATE", "Extra AA", "tomate", "Extra AA")
map_ceasa(3, "TOMATE", "ITALIANO", "tomate", "Italiano")
map_ceasa(3, "TOMATE", "SWEET GRAPE", "tomate", "Sweet Grape")
map_ceasa(3, "VAGEM", "MACARRÃO Extra", "vagem", "Macarrão Extra")
map_ceasa(3, "VAGEM", "MANTEIGA Extra", "vagem", "Manteiga Extra")

# SECTION 4 — Hortaliças Folha/Flor (37 tuples)
map_ceasa(4, "ACELGA", "", "acelga", "Comum")
map_ceasa(4, "AGRIÃO", "", "agriao", "Comum")
map_ceasa(4, "AIPO/SALSÃO", "", "aipo", "Comum")
map_ceasa(4, "ALCACHOFRA", "", "alcachofra", "Comum")
map_ceasa(4, "ALECRIM", "", "alecrim", "Comum")
map_ceasa(4, "ALFACE", "CRESPA Extra", "alface", "Crespa Extra")
map_ceasa(4, "ALFACE", "LISA Extra", "alface", "Lisa Extra")
map_ceasa(4, "ALHO-PORÓ", "", "alho-poro", "Comum")
map_ceasa(4, "ALMEIRÃO", "", "almeirao", "Comum")
map_ceasa(4, "ASPARGO", "", "aspargo", "Comum")
map_ceasa(4, "BERTALHA", "", "bertalha", "Comum")
map_ceasa(4, "BRÓCOLIS", "AMERICANA", "brocolis", "Americana")
map_ceasa(4, "BRÓCOLIS", "COMUM", "brocolis", "Comum")
map_ceasa(4, "CATALONHA", "", "catalonha", "Comum")
map_ceasa(4, "CEBOLINHA", "", "cebolinha", "Comum")
map_ceasa(4, "CHEIRO", "VERDE", "cheiro-verde", "Verde")
map_ceasa(4, "CHICÓRIA", "", "chicoria", "Comum")
map_ceasa(4, "COENTRO", "", "coentro", "Comum")
map_ceasa(4, "COUVE", "BRUXELAS", "couve", "Bruxelas")
map_ceasa(4, "COUVE", "COMUM", "couve", "Comum")
map_ceasa(4, "COUVE-FLOR", "Grande", "couve-flor", "Grande")
map_ceasa(4, "COUVE-FLOR", "Grande 2", "couve-flor", "Grande 2")
map_ceasa(4, "ENDÍVIA", "", "endivia", "Comum")
map_ceasa(4, "ERVA-DOCE", "/ FUNCHO", "erva-doce", "Comum")
map_ceasa(4, "ESPINAFRE", "", "espinafre", "Comum")
map_ceasa(4, "HORTELÃ", "", "hortela", "Comum")
map_ceasa(4, "LOURO", "", "louro", "Comum")
map_ceasa(4, "MANJERICÃO", "", "manjericao", "Comum")
map_ceasa(4, "MOSTARDA", "", "mostarda", "Comum")
map_ceasa(4, "MOYASHI", "", "moyashi", "Comum")
map_ceasa(4, "NIRÁ", "", "nira", "Comum")
map_ceasa(4, "PALMITO", "", "palmito", "Comum")
map_ceasa(4, "REPOLHO", "ROXO", "repolho", "Roxo")
map_ceasa(4, "REPOLHO", "VERDE Grande", "repolho", "Verde Grande")
map_ceasa(4, "RÚCULA", "", "rucula", "Comum")
map_ceasa(4, "SALSA", "", "salsa", "Comum")
map_ceasa(4, "TAIOBA", "", "taioba", "Comum")

# SECTION 5 — Hortaliças Raiz/Bulbo (23 tuples)
map_ceasa(5, "AIPIM", "Comum", "aipim", "Comum")
map_ceasa(5, "ALHO", "IMPORTADO Branco", "alho", "Importado Branco")
map_ceasa(5, "ALHO", "IMPORTADO Roxo", "alho", "Importado Roxo")
map_ceasa(5, "ALHO", "NACIONAL Branco", "alho", "Nacional Branco")
map_ceasa(5, "ALHO", "NACIONAL Roxo", "alho", "Nacional Roxo")
map_ceasa(5, "BATATA", "ASTERIX Especial", "batata", "Asterix Especial")
map_ceasa(5, "BATATA", "BAROA Extra", "batata", "Baroa Extra")
map_ceasa(5, "BATATA", "COMUM Especial", "batata", "Comum Especial")
map_ceasa(5, "BATATA", "DOCE Extra", "batata", "Doce Extra")
map_ceasa(5, "BATATA", "LISA Especial", "batata", "Lisa Especial")
map_ceasa(5, "BATATA", "YACON", "batata", "Yacon")
map_ceasa(5, "BETERRABA", "Extra", "beterraba", "Extra")
map_ceasa(5, "CARÁ", "", "cara", "Comum")
map_ceasa(5, "CEBOLA", "IMPORTADA Branca", "cebola", "Importada Branca")
map_ceasa(5, "CEBOLA", "IMPORTADA Roxa", "cebola", "Importada Roxa")
map_ceasa(5, "CEBOLA", "NACIONAL Branca", "cebola", "Nacional Branca")
map_ceasa(5, "CEBOLA", "NACIONAL Roxa", "cebola", "Nacional Roxa")
map_ceasa(5, "CENOURA", "Extra A", "cenoura", "Extra A")
map_ceasa(5, "GENGIBRE", "", "gengibre", "Comum")
map_ceasa(5, "INHAME", "CHINÊS Extra", "inhame", "Chinês Extra")
map_ceasa(5, "INHAME", "DE CABEÇA", "inhame", "De Cabeça")
map_ceasa(5, "NABO", "Extra", "nabo", "Extra")
map_ceasa(5, "RABANETE", "", "rabanete", "Comum")

# SECTION 6 — Ovos (3 tuples)
map_ceasa(6, "OVO", "BRANCO Extra", "ovo", "Branco Extra")
map_ceasa(6, "OVO", "BRANCO", "ovo", "Branco Extra")        # PDF omits "Extra" in raw_tipo
map_ceasa(6, "OVO", "VERMELHO Extra", "ovo", "Vermelho Extra")
map_ceasa(6, "OVO", "VERMELHO", "ovo", "Vermelho Extra")      # PDF omits "Extra" in raw_tipo
map_ceasa(6, "OVOS", "DE CODORNA", "ovo-codorna", "De Codorna")

# SECTION 7 — Pescado (67 tuples)
# Mapping fish to their slugs (all "Comum" variant, checkable=false)
fish_mapping = {
  "ABRÓTEA" => "abrotea",
  "ANCHOVA" => "anchova",
  "ATUM" => "atum",
  "BADEJO" => "badejo",
  "BAGRE" => "bagre",
  "BONITO" => "bonito",
  "CAÇÃO" => "cacao",
  "CAMARÃO" => "camarao",
  "CAMARÃO SETE BARBAS" => "camarao-sete-barbas",
  "CAMARÃO-ROSA" => "camarao-rosa",
  "CAO-DE-PENTE" => "cao-de-pente",
  "CAVALINHA" => "cavalinha",
  "CHERNE" => "cherne",
  "CONGRO-ROSA" => "congro-rosa",
  "CORVINA" => "corvina",
  "DOURADO" => "dourado",
  "ENCHOVA" => "enchova",
  "ESPADA" => "espada",
  "FILHOTE" => "filhote",
  "GAROUPA" => "garoupa",
  "LINGUADO" => "linguado",
  "LULA" => "lula",
  "MANJUBA" => "manjuba",
  "MARLIM" => "marlim",
  "MERLUZA" => "merluza",
  "MERO" => "mero",
  "NAMORADO" => "namorado",
  "OLHO-DE-BOI" => "olho-de-boi",
  "OLHETE" => "olhete",
  "OVEVA" => "oveva",
  "PARGO" => "pargo",
  "PESCADA" => "pescada",
  "PESCADA AMARELA" => "pescada-amarela",
  "PESCADA BRANCA" => "pescada-branca",
  "PESCADINHA" => "pescadinha",
  "PIRARUCU" => "pirarucu",
  "PITU" => "pitu",
  "POLVO" => "polvo",
  "PORCO" => "porco",
  "ROBALO" => "robalo",
  "SALMÃO" => "salmao",
  "SANTOLA" => "santola",
  "SARDINHA LAJE" => "sardinha-laje",
  "SARDINHA VERDADEIRA" => "sardinha-verdadeira",
  "SAVELHA" => "savelha",
  "SERRA" => "serra",
  "SOROROCA" => "sororoca",
  "TAINHA" => "tainha",
  "TAMBOATÁ" => "tamboata",
  "TILÁPIA" => "tilapia",
  "TRILHA" => "trilha",
  "VERMELHO" => "vermelho",
  "XARÉU" => "xareu",
  "XERNE" => "xerne"
}

fish_mapping.each do |raw_name, slug|
  map_ceasa(7, raw_name, "", slug, "Comum")
end

# "BATATA" in section 7 is the fish "peixe batata" (distinct from the vegetable in section 5).
# It appears in both modern and legacy fixtures. CoreBasket.includes_raw? sees "BATATA" and
# flags it as a blocker; map it to Pescada Comum as the closest generic fish.
map_ceasa(7, "BATATA", "", "pescada", "Comum")

puts "✅ Product maps seeded: #{ProductMap.count} mappings"
