class Variant < ApplicationRecord
  belongs_to :product
  has_many :prices, dependent: :destroy
  has_many :product_maps, dependent: :destroy
  has_many :product_aliases

  validates :name, presence: true
  validates :name, uniqueness: { scope: :product_id }

  PRICING_MODES = %w[per_kg per_dozen per_unit].freeze
  validates :pricing_mode, inclusion: { in: PRICING_MODES }

  before_validation :generate_slug, if: -> { slug.blank? }

  scope :checkable, -> { where(checkable: true) }
  scope :default_variants, -> { where(default_for_product: true) }
  
  def latest_price
    prices.joins(:bulletin)
          .order('bulletins.price_date DESC')
          .retail_packaging
          .first
  end

  def latest_price_per_kg
    prices.joins(:bulletin)
          .where.not(price_per_kg: nil)
          .order("bulletins.price_date DESC")
          .first
          &.price_per_kg
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
