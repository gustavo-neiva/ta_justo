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

  # Single source of truth for "which row represents this variant?"
  # (Plan §3.1). Among the variant's rows on a given bulletin, picks the
  # smallest retail pack (feira shoppers buy small, not wholesale bulk).
  # Called by the verdict, controller stats, and the raw-data highlight so
  # the displayed number == the computed number.
  #
  # Returns the Price row, or nil when no usable row exists.
  def representative_price(bulletin:)
    rows = prices.where(bulletin: bulletin)
    return representative_dozen_row(rows) if pricing_mode == "per_dozen"

    if pricing_mode == "per_unit"
      rows = rows.to_a
      direct = rows.select { |p| p.original_unit == "unit" }
      return direct.min_by(&:id) if direct.any?

      usable = rows.select { |p| p.price_per_kg }
      return usable.min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
    end

    usable = rows.where.not(price_per_kg: nil).to_a
    usable.min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
  end

  # Representative rows over time (oldest → newest), optionally windowed.
  # The basis for percentile / market-timing series. One row per bulletin,
  # each chosen by the same smallest-retail-pack rule.
  # Memoized per months-key so repeated calls within one request are free.
  def representative_series(months: nil)
    @representative_series ||= {}
    @representative_series[months] ||= begin
      scope = prices.includes(:bulletin).joins(:bulletin)
      scope = scope.where("bulletins.price_date >= ?", months.months.ago) if months
      if pricing_mode == "per_dozen"
        scope = scope.where(original_unit: "dozen")
      elsif pricing_mode == "per_unit"
        scope = scope.where(original_unit: "unit").or(scope.where.not(price_per_kg: nil))
      else
        scope = scope.where.not(price_per_kg: nil)
      end

      scope.order("bulletins.price_date ASC")
           .group_by(&:bulletin_id)
           .map { |_bulletin_id, rows| pick_representative(rows) }
           .compact
           .sort_by { |price| price.bulletin.price_date }
    end
  end

  # Most recent representative row (latest bulletin with a usable price).
  # Finds only the latest relevant bulletin directly — avoids loading the full series.
  def latest_price
    scope = prices.joins(:bulletin)
    if pricing_mode == "per_dozen"
      scope = scope.where(original_unit: "dozen")
    elsif pricing_mode == "per_unit"
      scope = scope.where(original_unit: "unit").or(scope.where.not(price_per_kg: nil))
    else
      scope = scope.where.not(price_per_kg: nil)
    end

    latest_bulletin_id = scope.order("bulletins.price_date DESC").limit(1).pick("prices.bulletin_id")
    return nil unless latest_bulletin_id

    representative_price(bulletin: Bulletin.find(latest_bulletin_id))
  end

  def latest_price_per_kg
    latest_price&.price_per_kg
  end

  # Single-row representative selection used by representative_price and by
  # surfaces that already have the variant's rows loaded (e.g. /precos).
  def pick_representative(rows)
    case pricing_mode
    when "per_dozen"
      rows.select { |p| p.original_unit == "dozen" }.min_by(&:id)
    when "per_unit"
      direct = rows.select { |p| p.original_unit == "unit" }
      return direct.min_by(&:id) if direct.any?

      rows.select { |p| p.price_per_kg }
          .min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
    else
      rows.select { |p| p.price_per_kg }
          .min_by { |p| [ PackSize.kg(p.raw_unit) || Float::INFINITY, p.id ] }
    end
  end

  private

  # per_dozen rows are all the same box ("Cx 30 dz"); pack-size selection
  # does not apply, so we just take a stable single row.
  def representative_dozen_row(rows)
    rows.where(original_unit: "dozen").order(:id).first
  end

  def generate_slug
    self.slug = name.parameterize
  end
end
