class ProductAlias < ApplicationRecord
  belongs_to :product
  belongs_to :variant, optional: true

  validates :alias_name, :normalized_name, presence: true

  before_validation :set_normalized_name, if: -> { normalized_name.blank? }

  # Normalize a name (diacritic-strip + uppercase) - adapted from CropAlias
  def self.normalize(name)
    name.to_s.strip.unicode_normalize(:nfkd)
      .encode('ASCII', invalid: :replace, undef: :replace, replace: '')
      .gsub(/\s+/, ' ')
      .upcase
  end

  # Resolve a free-text search term → Product, via any alias
  def self.resolve(term, market: nil)
    normalized = normalize(term)
    query = where(normalized_name: normalized)
    query = query.where(market: market) if market  # prefer market-specific
    query.first&.product
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize(alias_name)
  end
end
