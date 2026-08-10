# Core Basket — The ~30-40 most-checked feira staples
# These products MUST have 100% mapping coverage (hard CI gate in rake ceasa:validate_mapping)

# This module provides the authoritative list of core basket products
module CoreBasket
  # Product slugs in the core basket (the checkable staples)
  SLUGS = %w[
    tomate
    batata
    cebola
    alho
    cenoura
    beterraba
    aipim
    inhame
    pimentao
    pepino
    abobrinha
    abobora
    berinjela
    chuchu
    quiabo
    alface
    couve
    repolho
    brocolis
    cheiro-verde
    salsa
    coentro
    rucula
    banana
    laranja
    limao
    mamao
    manga
    maca
    melancia
    melao
    abacaxi
    maracuja
    uva
    morango
    tangerina
    ovo
  ].freeze

  # Raw product names that map to core basket (for validation)
  RAW_PRODUCTS = %w[
    TOMATE
    BATATA
    CEBOLA
    ALHO
    CENOURA
    BETERRABA
    AIPIM
    INHAME
    PIMENTÃO
    PEPINO
    ABOBRINHA
    ABÓBORA
    BERINJELA
    CHUCHU
    QUIABO
    ALFACE
    COUVE
    REPOLHO
    BRÓCOLIS
    CHEIRO
    SALSA
    COENTRO
    RÚCULA
    BANANA
    LARANJA
    LIMÃO
    MAMÃO
    MANGA
    MAÇÃ
    MELANCIA
    MELÃO
    ABACAXI
    MARACUJÁ
    UVA
    MORANGO
    TANGERINA
    OVO
  ].freeze

  def self.includes_slug?(slug)
    SLUGS.include?(slug.to_s)
  end

  def self.includes_raw?(parsed_row)
    RAW_PRODUCTS.include?(parsed_row.raw_product.to_s.upcase)
  end

  def self.all_products
    Product.where(slug: SLUGS).order(:name)
  end

  def self.checkable_list
    # Returns array of {slug, name, default_variant_name} for the checker dropdown
    all_products.includes(:default_variant).map do |p|
      {
        slug: p.slug,
        name: p.name,
        default_variant: p.default_variant&.name
      }
    end
  end

  def self.search_index
    # JSON-encodable index for the live product search (product + variant names)
    all_products.includes(:variants).order(:name).map do |product|
      {
        slug: product.slug,
        name: product.name,
        variants: product.variants.order(:name).map { |variant| { id: variant.id, name: variant.name } }
      }
    end
  end
end

puts "✅ Core basket defined: #{CoreBasket::SLUGS.count} products"
