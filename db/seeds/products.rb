# Product & Variant Seeds — idempotent, built from Appendix C (248 tuples)
# Run with: rails db:seed or rails db:seed:replant
#
# Design: find_or_create_by! on natural keys → safe to re-run

puts "Seeding products and variants..."

# Helper to ensure idempotent variant creation
def ensure_variant(product, name, attrs = {})
  variant = Variant.find_or_create_by!(product: product, name: name) do |v|
    v.origin = attrs[:origin]
    v.color = attrs[:color]
    v.grade = attrs[:grade]
    v.species_group = attrs[:species_group]
    v.pricing_mode = attrs[:pricing_mode] || "per_kg"
    v.avg_weight_kg = attrs[:avg_weight_kg]
    v.avg_weight_source = attrs[:avg_weight_source]
    v.checkable = attrs.fetch(:checkable, true)
    v.default_for_product = false
  end
  
  # Update attributes if they've changed
  variant.update!(attrs.except(:default)) if variant.persisted?
  variant
end

# SECTION 1 — Frutas Nacionais (66 tuples → ~35 products)
# Fair-relevant: yes (common fruits)

# Abacate
abacate = Product.find_or_create_by!(slug: "abacate") do |p|
  p.name = "Abacate"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
abacate_comum = ensure_variant(abacate, "Comum", grade: "extra", pricing_mode: "per_unit", avg_weight_kg: 0.400, avg_weight_source: "measured")
abacate.update!(default_variant: abacate_comum)

# Abacaxi
abacaxi = Product.find_or_create_by!(slug: "abacaxi") do |p|
  p.name = "Abacaxi"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
abacaxi_perola = ensure_variant(abacaxi, "Pérola Médio", grade: "médio", pricing_mode: "per_unit", avg_weight_kg: 1.500, avg_weight_source: "measured")
abacaxi_ananas = ensure_variant(abacaxi, "Ananás Grande", grade: "grande", pricing_mode: "per_unit", avg_weight_kg: 2.000, avg_weight_source: "measured")
abacaxi.update!(default_variant: abacaxi_perola)

# Ameixa
ameixa = Product.find_or_create_by!(slug: "ameixa") do |p|
  p.name = "Ameixa"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
ameixa_nacional = ensure_variant(ameixa, "Nacional")
ameixa.update!(default_variant: ameixa_nacional)

# Amora, Atemóia (less common, index-only)
amora = Product.find_or_create_by!(slug: "amora") { |p| p.name = "Amora"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
amora_comum = ensure_variant(amora, "Comum")
amora.update!(default_variant: amora_comum)

atemoia = Product.find_or_create_by!(slug: "atemoia") { |p| p.name = "Atemóia"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
atemoia_comum = ensure_variant(atemoia, "Comum")
atemoia.update!(default_variant: atemoia_comum)

# Banana (staple)
banana = Product.find_or_create_by!(slug: "banana") do |p|
  p.name = "Banana"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
banana_nanica = ensure_variant(banana, "Nanica/D'Água Extra", grade: "extra")
banana_prata = ensure_variant(banana, "Prata Extra", grade: "extra")
banana_maca = ensure_variant(banana, "Maçã Extra", grade: "extra")
banana_ouro = ensure_variant(banana, "Ouro")
banana_terra = ensure_variant(banana, "Da Terra")
banana_figo = ensure_variant(banana, "Figo")
banana_pacovan = ensure_variant(banana, "Pacovan")
banana.update!(default_variant: banana_nanica)

# Cajá, Caju (seasonal)
caja = Product.find_or_create_by!(slug: "caja") { |p| p.name = "Cajá"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
caja_comum = ensure_variant(caja, "Comum")
caja.update!(default_variant: caja_comum)

caju = Product.find_or_create_by!(slug: "caju") { |p| p.name = "Caju"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
caju_comum = ensure_variant(caju, "Comum")
caju.update!(default_variant: caju_comum)

# Caqui
caqui = Product.find_or_create_by!(slug: "caqui") { |p| p.name = "Caqui"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
caqui_fuyu = ensure_variant(caqui, "Fuyu")
caqui_rama_forte = ensure_variant(caqui, "Rama Forte A", grade: "a")
caqui.update!(default_variant: caqui_fuyu)

# Carambola
carambola = Product.find_or_create_by!(slug: "carambola") { |p| p.name = "Carambola"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
carambola_comum = ensure_variant(carambola, "Comum")
carambola.update!(default_variant: carambola_comum)

# Coco
coco = Product.find_or_create_by!(slug: "coco") do |p|
  p.name = "Coco"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
coco_verde = ensure_variant(coco, "Verde", pricing_mode: "per_unit", avg_weight_kg: 1.200, avg_weight_source: "measured")
coco_seco = ensure_variant(coco, "Seco", pricing_mode: "per_unit", avg_weight_kg: 0.800, avg_weight_source: "measured")
coco.update!(default_variant: coco_verde)

# Figo
figo = Product.find_or_create_by!(slug: "figo") { |p| p.name = "Figo"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
figo_verde = ensure_variant(figo, "Verde Tipo 8")
figo.update!(default_variant: figo_verde)

# Fruta de Conde/Pinha
pinha = Product.find_or_create_by!(slug: "pinha") { |p| p.name = "Fruta de Conde/Pinha"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
pinha_tipo4 = ensure_variant(pinha, "Tipo 4")
pinha.update!(default_variant: pinha_tipo4)

# Goiaba
goiaba = Product.find_or_create_by!(slug: "goiaba") { |p| p.name = "Goiaba"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
goiaba_vermelha = ensure_variant(goiaba, "Vermelha Tipo 12", color: "vermelha")
goiaba.update!(default_variant: goiaba_vermelha)

# Graviola, Jaboticaba (rare)
graviola = Product.find_or_create_by!(slug: "graviola") { |p| p.name = "Graviola"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
graviola_comum = ensure_variant(graviola, "Comum")
graviola.update!(default_variant: graviola_comum)

jaboticaba = Product.find_or_create_by!(slug: "jaboticaba") { |p| p.name = "Jaboticaba"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
jaboticaba_comum = ensure_variant(jaboticaba, "Comum")
jaboticaba.update!(default_variant: jaboticaba_comum)

# Kiwi
kiwi = Product.find_or_create_by!(slug: "kiwi") { |p| p.name = "Kiwi"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
kiwi_nacional = ensure_variant(kiwi, "Nacional", origin: "nacional")
kiwi.update!(default_variant: kiwi_nacional)

# Laranja (staple)
laranja = Product.find_or_create_by!(slug: "laranja") do |p|
  p.name = "Laranja"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
laranja_pera = ensure_variant(laranja, "Pêra Grande", grade: "grande")
laranja_bahia = ensure_variant(laranja, "Bahia Grande", grade: "grande")
laranja_natal = ensure_variant(laranja, "Natal Grande", grade: "grande")
laranja_valencia = ensure_variant(laranja, "Valencia Grande", grade: "grande")
laranja_lima = ensure_variant(laranja, "Lima")
laranja_seleta = ensure_variant(laranja, "Seleta Grande", grade: "grande")
laranja.update!(default_variant: laranja_pera)

# Lima da Pérsia
lima = Product.find_or_create_by!(slug: "lima") { |p| p.name = "Lima da Pérsia"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
lima_comum = ensure_variant(lima, "Comum")
lima.update!(default_variant: lima_comum)

# Limão (staple)
limao = Product.find_or_create_by!(slug: "limao") do |p|
  p.name = "Limão"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
limao_taiti = ensure_variant(limao, "Taiti")
limao_siciliano_nacional = ensure_variant(limao, "Siciliano Nacional", origin: "nacional")
limao.update!(default_variant: limao_taiti)

# Lichia
lichia = Product.find_or_create_by!(slug: "lichia") { |p| p.name = "Lichia"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
lichia_comum = ensure_variant(lichia, "Comum")
lichia.update!(default_variant: lichia_comum)

# Mamão (staple)
mamao = Product.find_or_create_by!(slug: "mamao") do |p|
  p.name = "Mamão"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
mamao_formosa = ensure_variant(mamao, "Formosa", pricing_mode: "per_unit", avg_weight_kg: 1.800, avg_weight_source: "measured")
mamao_papaya = ensure_variant(mamao, "Papaya/Havai", pricing_mode: "per_unit", avg_weight_kg: 0.500, avg_weight_source: "measured")
mamao.update!(default_variant: mamao_formosa)

# Manga (staple)
manga = Product.find_or_create_by!(slug: "manga") do |p|
  p.name = "Manga"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
manga_palmer = ensure_variant(manga, "Palmer")
manga_tommy = ensure_variant(manga, "Tommy Atkins")
manga_espada = ensure_variant(manga, "Espada")
manga.update!(default_variant: manga_palmer)

# Maracujá
maracuja = Product.find_or_create_by!(slug: "maracuja") { |p| p.name = "Maracujá"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
maracuja_comum = ensure_variant(maracuja, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.120, avg_weight_source: "measured")
maracuja.update!(default_variant: maracuja_comum)

# Maçã (staple)
maca = Product.find_or_create_by!(slug: "maca") do |p|
  p.name = "Maçã"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
maca_fuji_nacional = ensure_variant(maca, "Nacional Fuji", origin: "nacional")
maca_gala_nacional = ensure_variant(maca, "Nacional Gala", origin: "nacional")
maca.update!(default_variant: maca_fuji_nacional)

# Melancia (staple)
melancia = Product.find_or_create_by!(slug: "melancia") do |p|
  p.name = "Melancia"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
melancia_grande = ensure_variant(melancia, "Grande", grade: "grande", pricing_mode: "per_unit", avg_weight_kg: 8.000, avg_weight_source: "measured")
melancia.update!(default_variant: melancia_grande)

# Melão
melao = Product.find_or_create_by!(slug: "melao") do |p|
  p.name = "Melão"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
melao_amarelo = ensure_variant(melao, "Amarelo Tipo 5", pricing_mode: "per_unit", avg_weight_kg: 1.500, avg_weight_source: "measured")
melao_rede = ensure_variant(melao, "De Rede Tipo 4", pricing_mode: "per_unit", avg_weight_kg: 1.200, avg_weight_source: "measured")
melao_pele_sapo = ensure_variant(melao, "Pele de Sapo Tipo 4", pricing_mode: "per_unit", avg_weight_kg: 2.000, avg_weight_source: "measured")
melao.update!(default_variant: melao_amarelo)

# Morango (staple)
morango = Product.find_or_create_by!(slug: "morango") { |p| p.name = "Morango"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
morango_extra = ensure_variant(morango, "Extra", grade: "extra")
morango.update!(default_variant: morango_extra)

# Nectarina
nectarina = Product.find_or_create_by!(slug: "nectarina") { |p| p.name = "Nectarina"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
nectarina_nacional = ensure_variant(nectarina, "Nacional", origin: "nacional")
nectarina.update!(default_variant: nectarina_nacional)

# Pitaya
pitaya = Product.find_or_create_by!(slug: "pitaya") { |p| p.name = "Pitaya"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
pitaya_comum = ensure_variant(pitaya, "Comum")
pitaya.update!(default_variant: pitaya_comum)

# Pêssego
pessego = Product.find_or_create_by!(slug: "pessego") { |p| p.name = "Pêssego"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
pessego_nacional = ensure_variant(pessego, "Nacional", origin: "nacional")
pessego.update!(default_variant: pessego_nacional)

# Romã, Saputi, Seriguela, Tamarindo (rare)
roma = Product.find_or_create_by!(slug: "roma") { |p| p.name = "Romã"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
roma_comum = ensure_variant(roma, "Comum")
roma.update!(default_variant: roma_comum)

saputi = Product.find_or_create_by!(slug: "saputi") { |p| p.name = "Saputi"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
saputi_comum = ensure_variant(saputi, "Comum")
saputi.update!(default_variant: saputi_comum)

seriguela = Product.find_or_create_by!(slug: "seriguela") { |p| p.name = "Seriguela"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
seriguela_comum = ensure_variant(seriguela, "Comum")
seriguela.update!(default_variant: seriguela_comum)

tamarindo = Product.find_or_create_by!(slug: "tamarindo") { |p| p.name = "Tamarindo"; p.category = "fruta"; p.section = 1; p.fair_relevant = false }
tamarindo_comum = ensure_variant(tamarindo, "Comum")
tamarindo.update!(default_variant: tamarindo_comum)

# Tangerina
tangerina = Product.find_or_create_by!(slug: "tangerina") { |p| p.name = "Tangerina"; p.category = "fruta"; p.section = 1; p.fair_relevant = true }
tangerina_comum = ensure_variant(tangerina, "Comum/Rio Extra", grade: "extra")
tangerina_murcott = ensure_variant(tangerina, "Murcott Extra", grade: "extra")
tangerina_ponkan = ensure_variant(tangerina, "Ponkan Extra", grade: "extra")
tangerina.update!(default_variant: tangerina_ponkan)

# Uva (staple)
uva = Product.find_or_create_by!(slug: "uva") do |p|
  p.name = "Uva"
  p.category = "fruta"
  p.section = 1
  p.fair_relevant = true
end
uva_benitaka = ensure_variant(uva, "Benitaka Extra", grade: "extra")
uva_italia = ensure_variant(uva, "Italia Extra", grade: "extra")
uva_red_globe_nacional = ensure_variant(uva, "Red Globe Nacional", origin: "nacional")
uva_rosada = ensure_variant(uva, "Rosada/Niagara Extra", grade: "extra")
uva_rubi = ensure_variant(uva, "Rubi Extra", grade: "extra")
uva_thompson_nacional = ensure_variant(uva, "Thompson Nacional", origin: "nacional")
uva_vitoria = ensure_variant(uva, "Vitória")
uva.update!(default_variant: uva_italia)


# SECTION 2 — Frutas Importadas (21 tuples → ~10 products)
# Fair-relevant: NO (index-only, rare at street fairs)

# Ameixa Importada
ameixa_imp = Product.find_or_create_by!(slug: "ameixa-importada") { |p| p.name = "Ameixa Importada"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
ameixa_imp_var = ensure_variant(ameixa_imp, "Importada", origin: "importada")
ameixa_imp.update!(default_variant: ameixa_imp_var)

# Cereja Importada
cereja = Product.find_or_create_by!(slug: "cereja") { |p| p.name = "Cereja"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
cereja_imp = ensure_variant(cereja, "Importada", origin: "importada")
cereja.update!(default_variant: cereja_imp)

# Damasco (typo variants: IMPORTADO / IMPORTDAO)
damasco = Product.find_or_create_by!(slug: "damasco") { |p| p.name = "Damasco"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
damasco_imp = ensure_variant(damasco, "Importado", origin: "importada")
damasco.update!(default_variant: damasco_imp)

# Kiwi Importado
kiwi_imp = Product.find_or_create_by!(slug: "kiwi-importado") { |p| p.name = "Kiwi Importado"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
kiwi_imp_var = ensure_variant(kiwi_imp, "Importado", origin: "importada")
kiwi_imp.update!(default_variant: kiwi_imp_var)

# Laranja Kinkan
kinkan = Product.find_or_create_by!(slug: "laranja-kinkan") { |p| p.name = "Laranja Kinkan"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
kinkan_imp = ensure_variant(kinkan, "Importada", origin: "importada")
kinkan.update!(default_variant: kinkan_imp)

# Limão Siciliano Importado
limao_siciliano_imp = Product.find_or_create_by!(slug: "limao-siciliano-importado") { |p| p.name = "Limão Siciliano Importado"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
limao_siciliano_imp_var = ensure_variant(limao_siciliano_imp, "Importado", origin: "importada")
limao_siciliano_imp.update!(default_variant: limao_siciliano_imp_var)

# Maçã Importada
maca_imp = Product.find_or_create_by!(slug: "maca-importada") { |p| p.name = "Maçã Importada"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
maca_fuji_imp = ensure_variant(maca_imp, "Importada Fuji", origin: "importada")
maca_gala_imp = ensure_variant(maca_imp, "Importada Gala", origin: "importada")
maca_red_delicious = ensure_variant(maca_imp, "Importada Red Delicious", origin: "importada")
maca_grand_smith = ensure_variant(maca_imp, "Importada Grand Smith", origin: "importada")
maca_imp.update!(default_variant: maca_fuji_imp)

# Nectarina Importada
nectarina_imp = Product.find_or_create_by!(slug: "nectarina-importada") { |p| p.name = "Nectarina Importada"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
nectarina_imp_var = ensure_variant(nectarina_imp, "Importada", origin: "importada")
nectarina_imp.update!(default_variant: nectarina_imp_var)

# Pitaya Importada
pitaya_imp = Product.find_or_create_by!(slug: "pitaya-importada") { |p| p.name = "Pitaya Importada"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
pitaya_imp_var = ensure_variant(pitaya_imp, "Importada", origin: "importada")
pitaya_imp.update!(default_variant: pitaya_imp_var)

# Pêra Importada
pera = Product.find_or_create_by!(slug: "pera") { |p| p.name = "Pêra"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
pera_danjour = ensure_variant(pera, "Importada D'Anjour", origin: "importada")
pera_pacck_triumph = ensure_variant(pera, "Importada Pacck Triunph", origin: "importada")
pera_portuguesa = ensure_variant(pera, "Importada Portuguesa", origin: "importada")
pera_willians = ensure_variant(pera, "Importada Willians", origin: "importada")
pera_winterbarlett = ensure_variant(pera, "Importada Winterbarlett", origin: "importada")
pera.update!(default_variant: pera_danjour)

# Pêssego Importado
pessego_imp = Product.find_or_create_by!(slug: "pessego-importado") { |p| p.name = "Pêssego Importado"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
pessego_imp_var = ensure_variant(pessego_imp, "Importado", origin: "importada")
pessego_imp.update!(default_variant: pessego_imp_var)

# Uva Importada
uva_imp = Product.find_or_create_by!(slug: "uva-importada") { |p| p.name = "Uva Importada"; p.category = "fruta"; p.section = 2; p.fair_relevant = false }
uva_red_globe_imp = ensure_variant(uva_imp, "Red Globe Importada Extra", origin: "importada", grade: "extra")
uva_thompson_imp = ensure_variant(uva_imp, "Thompson Importada Extra", origin: "importada", grade: "extra")
uva_imp.update!(default_variant: uva_red_globe_imp)


# SECTION 3 — Hortaliças Fruto (31 tuples → ~15 products)
# Fair-relevant: YES (common vegetables)

# Abobrinha (staple)
abobrinha = Product.find_or_create_by!(slug: "abobrinha") do |p|
  p.name = "Abobrinha"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
abobrinha_italiana = ensure_variant(abobrinha, "Italiana Extra", grade: "extra")
abobrinha_menina = ensure_variant(abobrinha, "Menina Extra", grade: "extra")
abobrinha.update!(default_variant: abobrinha_italiana)

# Abóbora (staple)
abobora = Product.find_or_create_by!(slug: "abobora") do |p|
  p.name = "Abóbora"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
abobora_pescoco = ensure_variant(abobora, "Pescoço")
abobora_baiana = ensure_variant(abobora, "Baiana")
abobora_branca = ensure_variant(abobora, "Branca", color: "branca")
abobora_japonesa = ensure_variant(abobora, "Japonesa")
abobora_moranga_baby = ensure_variant(abobora, "Moranga Baby")
abobora_moranga_hibrida = ensure_variant(abobora, "Moranga Híbrida")
abobora_sergipana = ensure_variant(abobora, "Sergipana")
abobora.update!(default_variant: abobora_pescoco)

# Berinjela (staple)
berinjela = Product.find_or_create_by!(slug: "berinjela") do |p|
  p.name = "Berinjela"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
berinjela_extra = ensure_variant(berinjela, "Extra", grade: "extra")
berinjela.update!(default_variant: berinjela_extra)

# Chuchu (staple)
chuchu = Product.find_or_create_by!(slug: "chuchu") do |p|
  p.name = "Chuchu"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
chuchu_extra = ensure_variant(chuchu, "Extra", grade: "extra")
chuchu.update!(default_variant: chuchu_extra)

# Ervilha Vagem
ervilha = Product.find_or_create_by!(slug: "ervilha-vagem") { |p| p.name = "Ervilha Vagem"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
ervilha_extra = ensure_variant(ervilha, "Vagem Extra", grade: "extra")
ervilha.update!(default_variant: ervilha_extra)

# Feijão de Corda
feijao_corda = Product.find_or_create_by!(slug: "feijao-de-corda") { |p| p.name = "Feijão de Corda"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
feijao_corda_var = ensure_variant(feijao_corda, "De Corda")
feijao_corda.update!(default_variant: feijao_corda_var)

# Jiló
jilo = Product.find_or_create_by!(slug: "jilo") { |p| p.name = "Jiló"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
jilo_extra = ensure_variant(jilo, "Extra", grade: "extra")
jilo.update!(default_variant: jilo_extra)

# Maxixe
maxixe = Product.find_or_create_by!(slug: "maxixe") { |p| p.name = "Maxixe"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
maxixe_comum = ensure_variant(maxixe, "Comum")
maxixe.update!(default_variant: maxixe_comum)

# Milho Verde
milho = Product.find_or_create_by!(slug: "milho-verde") { |p| p.name = "Milho Verde"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
milho_verde = ensure_variant(milho, "Verde", pricing_mode: "per_unit", avg_weight_kg: 0.400, avg_weight_source: "measured")
milho.update!(default_variant: milho_verde)

# Pepino (staple)
pepino = Product.find_or_create_by!(slug: "pepino") do |p|
  p.name = "Pepino"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
pepino_comum = ensure_variant(pepino, "Comum Extra", grade: "extra")
pepino_japones = ensure_variant(pepino, "Japonês")
pepino.update!(default_variant: pepino_comum)

# Pimenta
pimenta = Product.find_or_create_by!(slug: "pimenta") { |p| p.name = "Pimenta"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
pimenta_cheiro = ensure_variant(pimenta, "De Cheiro")
pimenta_dedo = ensure_variant(pimenta, "Dedo")
pimenta_malagueta = ensure_variant(pimenta, "Malagueta")
pimenta.update!(default_variant: pimenta_dedo)

# Pimentão (staple)
pimentao = Product.find_or_create_by!(slug: "pimentao") do |p|
  p.name = "Pimentão"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
pimentao_verde = ensure_variant(pimentao, "Verde Extra A", grade: "extra", color: "verde")
pimentao_amarelo = ensure_variant(pimentao, "Amarelo", color: "amarelo")
pimentao_vermelho = ensure_variant(pimentao, "Vermelho", color: "vermelho")
pimentao.update!(default_variant: pimentao_verde)

# Quiabo (staple)
quiabo = Product.find_or_create_by!(slug: "quiabo") do |p|
  p.name = "Quiabo"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
quiabo_extra = ensure_variant(quiabo, "Extra", grade: "extra")
quiabo.update!(default_variant: quiabo_extra)

# Tomate (staple)
tomate = Product.find_or_create_by!(slug: "tomate") do |p|
  p.name = "Tomate"
  p.category = "hortalica"
  p.section = 3
  p.fair_relevant = true
end
tomate_extra_aa = ensure_variant(tomate, "Extra AA", grade: "extra")
tomate_italiano = ensure_variant(tomate, "Italiano")
tomate_cereja = ensure_variant(tomate, "Cereja")
tomate_sweet_grape = ensure_variant(tomate, "Sweet Grape")
tomate.update!(default_variant: tomate_extra_aa)

# Vagem
vagem = Product.find_or_create_by!(slug: "vagem") { |p| p.name = "Vagem"; p.category = "hortalica"; p.section = 3; p.fair_relevant = true }
vagem_macarrao = ensure_variant(vagem, "Macarrão Extra", grade: "extra")
vagem_manteiga = ensure_variant(vagem, "Manteiga Extra", grade: "extra")
vagem.update!(default_variant: vagem_manteiga)


# SECTION 4 — Hortaliças Folha/Flor (37 tuples → ~30 products)
# Fair-relevant: YES (leafy greens)

# Acelga
acelga = Product.find_or_create_by!(slug: "acelga") { |p| p.name = "Acelga"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
acelga_comum = ensure_variant(acelga, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.300, avg_weight_source: "measured")
acelga.update!(default_variant: acelga_comum)

# Agrião
agriao = Product.find_or_create_by!(slug: "agriao") { |p| p.name = "Agrião"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
agriao_comum = ensure_variant(agriao, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.200, avg_weight_source: "measured")
agriao.update!(default_variant: agriao_comum)

# Aipo/Salsão
aipo = Product.find_or_create_by!(slug: "aipo") { |p| p.name = "Aipo/Salsão"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
aipo_comum = ensure_variant(aipo, "Comum")
aipo.update!(default_variant: aipo_comum)

# Alcachofra
alcachofra = Product.find_or_create_by!(slug: "alcachofra") { |p| p.name = "Alcachofra"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
alcachofra_comum = ensure_variant(alcachofra, "Comum")
alcachofra.update!(default_variant: alcachofra_comum)

# Alecrim
alecrim = Product.find_or_create_by!(slug: "alecrim") { |p| p.name = "Alecrim"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
alecrim_comum = ensure_variant(alecrim, "Comum")
alecrim.update!(default_variant: alecrim_comum)

# Alface (staple)
alface = Product.find_or_create_by!(slug: "alface") do |p|
  p.name = "Alface"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
alface_crespa = ensure_variant(alface, "Crespa Extra", grade: "extra", pricing_mode: "per_unit", avg_weight_kg: 0.350, avg_weight_source: "measured")
alface_lisa = ensure_variant(alface, "Lisa Extra", grade: "extra", pricing_mode: "per_unit", avg_weight_kg: 0.350, avg_weight_source: "measured")
alface.update!(default_variant: alface_crespa)

# Alho-Poró
alho_poro = Product.find_or_create_by!(slug: "alho-poro") { |p| p.name = "Alho-Poró"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
alho_poro_comum = ensure_variant(alho_poro, "Comum")
alho_poro.update!(default_variant: alho_poro_comum)

# Almeirão
almeirao = Product.find_or_create_by!(slug: "almeirao") { |p| p.name = "Almeirão"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
almeirao_comum = ensure_variant(almeirao, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.250, avg_weight_source: "measured")
almeirao.update!(default_variant: almeirao_comum)

# Aspargo
aspargo = Product.find_or_create_by!(slug: "aspargo") { |p| p.name = "Aspargo"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
aspargo_comum = ensure_variant(aspargo, "Comum")
aspargo.update!(default_variant: aspargo_comum)

# Bertalha
bertalha = Product.find_or_create_by!(slug: "bertalha") { |p| p.name = "Bertalha"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
bertalha_comum = ensure_variant(bertalha, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.200, avg_weight_source: "measured")
bertalha.update!(default_variant: bertalha_comum)

# Brócolis (staple)
brocolis = Product.find_or_create_by!(slug: "brocolis") do |p|
  p.name = "Brócolis"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
brocolis_comum = ensure_variant(brocolis, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.600, avg_weight_source: "measured")
brocolis_americana = ensure_variant(brocolis, "Americana", pricing_mode: "per_unit", avg_weight_kg: 0.600, avg_weight_source: "measured")
brocolis.update!(default_variant: brocolis_comum)

# Catalonha
catalonha = Product.find_or_create_by!(slug: "catalonha") { |p| p.name = "Catalonha"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
catalonha_comum = ensure_variant(catalonha, "Comum")
catalonha.update!(default_variant: catalonha_comum)

# Cebolinha
cebolinha = Product.find_or_create_by!(slug: "cebolinha") { |p| p.name = "Cebolinha"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
cebolinha_comum = ensure_variant(cebolinha, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.100, avg_weight_source: "measured")
cebolinha.update!(default_variant: cebolinha_comum)

# Cheiro Verde (staple)
cheiro_verde = Product.find_or_create_by!(slug: "cheiro-verde") do |p|
  p.name = "Cheiro Verde"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
cheiro_verde_var = ensure_variant(cheiro_verde, "Verde", pricing_mode: "per_unit", avg_weight_kg: 0.100, avg_weight_source: "measured")
cheiro_verde.update!(default_variant: cheiro_verde_var)

# Chicória
chicoria = Product.find_or_create_by!(slug: "chicoria") { |p| p.name = "Chicória"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
chicoria_comum = ensure_variant(chicoria, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.250, avg_weight_source: "measured")
chicoria.update!(default_variant: chicoria_comum)

# Coentro (staple)
coentro = Product.find_or_create_by!(slug: "coentro") do |p|
  p.name = "Coentro"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
coentro_comum = ensure_variant(coentro, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.100, avg_weight_source: "measured")
coentro.update!(default_variant: coentro_comum)

# Couve (staple)
couve = Product.find_or_create_by!(slug: "couve") do |p|
  p.name = "Couve"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
couve_comum = ensure_variant(couve, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.300, avg_weight_source: "measured")
couve_bruxelas = ensure_variant(couve, "Bruxelas")
couve.update!(default_variant: couve_comum)

# Couve-Flor (staple)
couve_flor = Product.find_or_create_by!(slug: "couve-flor") do |p|
  p.name = "Couve-Flor"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
couve_flor_grande = ensure_variant(couve_flor, "Grande", grade: "grande", pricing_mode: "per_unit", avg_weight_kg: 1.200, avg_weight_source: "measured")
couve_flor_grande2 = ensure_variant(couve_flor, "Grande 2", grade: "grande", pricing_mode: "per_unit", avg_weight_kg: 1.000, avg_weight_source: "measured")
couve_flor.update!(default_variant: couve_flor_grande)

# Endívia
endivia = Product.find_or_create_by!(slug: "endivia") { |p| p.name = "Endívia"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
endivia_comum = ensure_variant(endivia, "Comum")
endivia.update!(default_variant: endivia_comum)

# Erva-Doce/Funcho
erva_doce = Product.find_or_create_by!(slug: "erva-doce") { |p| p.name = "Erva-Doce/Funcho"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
erva_doce_comum = ensure_variant(erva_doce, "Comum")
erva_doce.update!(default_variant: erva_doce_comum)

# Espinafre
espinafre = Product.find_or_create_by!(slug: "espinafre") { |p| p.name = "Espinafre"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
espinafre_comum = ensure_variant(espinafre, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.300, avg_weight_source: "measured")
espinafre.update!(default_variant: espinafre_comum)

# Hortelã
hortela = Product.find_or_create_by!(slug: "hortela") { |p| p.name = "Hortelã"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
hortela_comum = ensure_variant(hortela, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.050, avg_weight_source: "measured")
hortela.update!(default_variant: hortela_comum)

# Louro
louro = Product.find_or_create_by!(slug: "louro") { |p| p.name = "Louro"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
louro_comum = ensure_variant(louro, "Comum")
louro.update!(default_variant: louro_comum)

# Manjericão
manjericao = Product.find_or_create_by!(slug: "manjericao") { |p| p.name = "Manjericão"; p.category = "hortalica"; p.section = 4; p.fair_relevant = true }
manjericao_comum = ensure_variant(manjericao, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.050, avg_weight_source: "measured")
manjericao.update!(default_variant: manjericao_comum)

# Mostarda
mostarda = Product.find_or_create_by!(slug: "mostarda") { |p| p.name = "Mostarda"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
mostarda_comum = ensure_variant(mostarda, "Comum")
mostarda.update!(default_variant: mostarda_comum)

# Moyashi
moyashi = Product.find_or_create_by!(slug: "moyashi") { |p| p.name = "Moyashi"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
moyashi_comum = ensure_variant(moyashi, "Comum")
moyashi.update!(default_variant: moyashi_comum)

# Nirá
nira = Product.find_or_create_by!(slug: "nira") { |p| p.name = "Nirá"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
nira_comum = ensure_variant(nira, "Comum")
nira.update!(default_variant: nira_comum)

# Palmito
palmito = Product.find_or_create_by!(slug: "palmito") { |p| p.name = "Palmito"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
palmito_comum = ensure_variant(palmito, "Comum")
palmito.update!(default_variant: palmito_comum)

# Repolho (staple)
repolho = Product.find_or_create_by!(slug: "repolho") do |p|
  p.name = "Repolho"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
repolho_verde = ensure_variant(repolho, "Verde Grande", grade: "grande", color: "verde", pricing_mode: "per_unit", avg_weight_kg: 1.500, avg_weight_source: "measured")
repolho_roxo = ensure_variant(repolho, "Roxo", color: "roxo", pricing_mode: "per_unit", avg_weight_kg: 1.200, avg_weight_source: "measured")
repolho.update!(default_variant: repolho_verde)

# Rúcula (staple)
rucula = Product.find_or_create_by!(slug: "rucula") do |p|
  p.name = "Rúcula"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
rucula_comum = ensure_variant(rucula, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.150, avg_weight_source: "measured")
rucula.update!(default_variant: rucula_comum)

# Salsa (staple)
salsa = Product.find_or_create_by!(slug: "salsa") do |p|
  p.name = "Salsa"
  p.category = "hortalica"
  p.section = 4
  p.fair_relevant = true
end
salsa_comum = ensure_variant(salsa, "Comum", pricing_mode: "per_unit", avg_weight_kg: 0.100, avg_weight_source: "measured")
salsa.update!(default_variant: salsa_comum)

# Taioba
taioba = Product.find_or_create_by!(slug: "taioba") { |p| p.name = "Taioba"; p.category = "hortalica"; p.section = 4; p.fair_relevant = false }
taioba_comum = ensure_variant(taioba, "Comum")
taioba.update!(default_variant: taioba_comum)


# SECTION 5 — Hortaliças Raiz/Bulbo (23 tuples → ~10 products)
# Fair-relevant: YES (root vegetables - staples)

# Aipim/Mandioca (staple)
aipim = Product.find_or_create_by!(slug: "aipim") do |p|
  p.name = "Aipim"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
aipim_comum = ensure_variant(aipim, "Comum")
aipim.update!(default_variant: aipim_comum)

# Alho (staple)
alho = Product.find_or_create_by!(slug: "alho") do |p|
  p.name = "Alho"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
alho_nacional_branco = ensure_variant(alho, "Nacional Branco", origin: "nacional", color: "branco")
alho_nacional_roxo = ensure_variant(alho, "Nacional Roxo", origin: "nacional", color: "roxo")
alho_importado_branco = ensure_variant(alho, "Importado Branco", origin: "importada", color: "branco")
alho_importado_roxo = ensure_variant(alho, "Importado Roxo", origin: "importada", color: "roxo")
alho.update!(default_variant: alho_nacional_branco)

# Batata (staple) — CRITICAL: species split, NEVER blend
batata = Product.find_or_create_by!(slug: "batata") do |p|
  p.name = "Batata"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
batata_comum = ensure_variant(batata, "Comum Especial", grade: "especial", species_group: "potato")
batata_asterix = ensure_variant(batata, "Asterix Especial", grade: "especial", species_group: "potato")
batata_lisa = ensure_variant(batata, "Lisa Especial", grade: "especial", species_group: "potato")
batata_doce = ensure_variant(batata, "Doce Extra", grade: "extra", species_group: "sweet-potato")
batata_baroa = ensure_variant(batata, "Baroa Extra", grade: "extra", species_group: "mandioquinha")
batata_yacon = ensure_variant(batata, "Yacon", species_group: "yacon")
batata.update!(default_variant: batata_comum)

# Beterraba (staple)
beterraba = Product.find_or_create_by!(slug: "beterraba") do |p|
  p.name = "Beterraba"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
beterraba_extra = ensure_variant(beterraba, "Extra", grade: "extra")
beterraba.update!(default_variant: beterraba_extra)

# Cará
cara = Product.find_or_create_by!(slug: "cara") { |p| p.name = "Cará"; p.category = "hortalica"; p.section = 5; p.fair_relevant = false }
cara_comum = ensure_variant(cara, "Comum")
cara.update!(default_variant: cara_comum)

# Cebola (staple)
cebola = Product.find_or_create_by!(slug: "cebola") do |p|
  p.name = "Cebola"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
cebola_nacional_branca = ensure_variant(cebola, "Nacional Branca", origin: "nacional", color: "branca")
cebola_nacional_roxa = ensure_variant(cebola, "Nacional Roxa", origin: "nacional", color: "roxa")
cebola_importada_branca = ensure_variant(cebola, "Importada Branca", origin: "importada", color: "branca")
cebola_importada_roxa = ensure_variant(cebola, "Importada Roxa", origin: "importada", color: "roxa")
cebola.update!(default_variant: cebola_nacional_branca)

# Cenoura (staple)
cenoura = Product.find_or_create_by!(slug: "cenoura") do |p|
  p.name = "Cenoura"
  p.category = "hortalica"
  p.section = 5
  p.fair_relevant = true
end
cenoura_extra_a = ensure_variant(cenoura, "Extra A", grade: "extra")
cenoura.update!(default_variant: cenoura_extra_a)

# Gengibre
gengibre = Product.find_or_create_by!(slug: "gengibre") { |p| p.name = "Gengibre"; p.category = "hortalica"; p.section = 5; p.fair_relevant = true }
gengibre_comum = ensure_variant(gengibre, "Comum")
gengibre.update!(default_variant: gengibre_comum)

# Inhame
inhame = Product.find_or_create_by!(slug: "inhame") { |p| p.name = "Inhame"; p.category = "hortalica"; p.section = 5; p.fair_relevant = true }
inhame_chines = ensure_variant(inhame, "Chinês Extra", grade: "extra")
inhame_cabeca = ensure_variant(inhame, "De Cabeça")
inhame.update!(default_variant: inhame_chines)

# Nabo
nabo = Product.find_or_create_by!(slug: "nabo") { |p| p.name = "Nabo"; p.category = "hortalica"; p.section = 5; p.fair_relevant = false }
nabo_extra = ensure_variant(nabo, "Extra", grade: "extra")
nabo.update!(default_variant: nabo_extra)

# Rabanete
rabanete = Product.find_or_create_by!(slug: "rabanete") { |p| p.name = "Rabanete"; p.category = "hortalica"; p.section = 5; p.fair_relevant = true }
rabanete_comum = ensure_variant(rabanete, "Comum")
rabanete.update!(default_variant: rabanete_comum)


# SECTION 6 — Ovos (3 tuples → 2 products)
# Fair-relevant: YES (staple, per-dozen pricing)

# Ovo de Galinha
ovo = Product.find_or_create_by!(slug: "ovo") do |p|
  p.name = "Ovo"
  p.category = "ovo"
  p.section = 6
  p.fair_relevant = true
end
ovo_branco = ensure_variant(ovo, "Branco Extra", grade: "extra", color: "branco", pricing_mode: "per_dozen")
ovo_vermelho = ensure_variant(ovo, "Vermelho Extra", grade: "extra", color: "vermelho", pricing_mode: "per_dozen")
ovo.update!(default_variant: ovo_branco)

# Ovos de Codorna
ovo_codorna = Product.find_or_create_by!(slug: "ovo-codorna") do |p|
  p.name = "Ovos de Codorna"
  p.category = "ovo"
  p.section = 6
  p.fair_relevant = false
end
ovo_codorna_var = ensure_variant(ovo_codorna, "De Codorna", pricing_mode: "per_dozen")
ovo_codorna.update!(default_variant: ovo_codorna_var)


# SECTION 7 — Pescado (67 tuples → ~40 products)
# Fair-relevant: NO (index-only, fish market not fair)
# All per-kg, but kept out of the default checker

fish_names = %w[
  Abrótea Anchova Atum Badejo Bagre Bonito Cação Camarão Camarão-Sete-Barbas
  Camarão-Rosa Cao-de-Pente Cavalinha Cherne Congro-Rosa Corvina Dourado Enchova
  Espada Filhote Garoupa Linguado Lula Manjuba Marlim Merluza Mero Namorado
  Olho-de-Boi Olhete Oveva Pargo Pescada Pescada-Amarela Pescada-Branca Pescadinha
  Pirarucu Pitu Polvo Porco Robalo Salmão Santola Sardinha-Laje Sardinha-Verdadeira
  Savelha Serra Sororoca Tainha Tamboatá Tilápia Trilha Vermelho Xaréu Xerne
].freeze

fish_names.each do |fish_name|
  slug = fish_name.downcase.gsub(/[áàâã]/, 'a').gsub(/[éèê]/, 'e').gsub(/[íì]/, 'i')
                  .gsub(/[óòôõ]/, 'o').gsub(/[úùû]/, 'u').gsub(/ç/, 'c')
                  .gsub(/\s+/, '-').gsub(/[^a-z0-9-]/, '')
  
  product = Product.find_or_create_by!(slug: slug) do |p|
    p.name = fish_name
    p.category = "peixe"
    p.section = 7
    p.fair_relevant = false
  end
  
  variant = ensure_variant(product, "Comum", checkable: false)
  product.update!(default_variant: variant)
end

puts "✅ Products and variants seeded: #{Product.count} products, #{Variant.count} variants"
