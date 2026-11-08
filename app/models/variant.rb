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

  DOZENS_PER_BOX = 30 # eggs: CEASA quotes "Cx 30 dz"

  # One CEASA row → price in the shopper's unit (R$/kg, R$/dúzia or R$/unidade),
  # or nil when the row can't be converted. Single source for every surface.
  def comparable(price)
    comparable_with_basis(price)&.first
  end

  # [value, how-it-was-derived] — the basis string is shown in the checker's
  # price breakdown so every number on screen can be traced to the bulletin.
  def comparable_with_basis(price)
    return nil unless price&.modal&.positive?

    modal = price.modal.to_f
    case pricing_mode
    when "per_dozen"
      [ modal / DOZENS_PER_BOX, "#{brl(modal)} ÷ 30 dúzias" ]
    when "per_unit"
      # Prefer what CEASA states (piece count, or a per-piece quote) over our
      # avg-weight estimate: "Preg 2 kg/16 unid" × 1.2 kg/head was 9× off.
      if (n = PackSize.count(price.raw_unit))
        [ modal / n, "#{brl(modal)} ÷ #{n} peças" ]
      elsif price.original_unit == "unit" || PackSize.single_unit?(price.raw_unit)
        [ modal, "preço CEASA por peça" ]
      elsif price.price_per_kg && avg_weight_kg&.positive?
        [ price.price_per_kg.to_f * avg_weight_kg.to_f,
          "#{brl(price.price_per_kg)}/kg × peça de ~#{(avg_weight_kg.to_f * 1000).round} g (peso estimado)" ]
      end
    else
      return nil unless price.price_per_kg&.positive?
      kg = PackSize.kg(price.raw_unit)
      [ price.price_per_kg.to_f, kg && kg != 1 ? "#{brl(modal)} ÷ #{kg.to_s.sub(/\.0\z/, "").tr(".", ",")} kg" : "preço CEASA por kg" ]
    end
  end

  def unit_label
    { "per_dozen" => "dúzia", "per_unit" => "unidade" }.fetch(pricing_mode, "kg")
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

  # "R$ 1.234,50" — how prices are written on Brazilian signs.
  def self.brl(value)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
  end

  private

  def brl(value) = self.class.brl(value)

  # per_dozen rows are all the same box ("Cx 30 dz"); pack-size selection
  # does not apply, so we just take a stable single row.
  def representative_dozen_row(rows)
    rows.where(original_unit: "dozen").order(:id).first
  end

  def generate_slug
    self.slug = name.parameterize
  end
end
