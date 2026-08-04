# Builds the price time-series for a variant's detail chart.
# Returns an array of { date: "YYYY-MM-DD", price: <Float, in the variant's pricing unit> }.
class ChartSeries
  PERIOD_DAYS = { "90" => 90, "365" => 365 }.freeze
  DOZENS_PER_BOX = 30

  def initialize(variant, period: "365", deflated: false)
    @variant  = variant
    @period   = period
    @deflated = deflated
  end

  def points
    rows = base_scope
    rows = rows.where("bulletins.price_date >= ?", days_back.days.ago) if days_back
    rows.order("bulletins.price_date ASC")
        .map { |p| point_for(p) }
        .compact
  end

  private

  def days_back
    PERIOD_DAYS[@period] # nil for "all"
  end

  def base_scope
    case @variant.pricing_mode
    when "per_dozen"
      @variant.prices.where(original_unit: "dozen").where.not(modal: nil).includes(:bulletin).joins(:bulletin)
    else
      @variant.prices.where.not(price_per_kg: nil).includes(:bulletin).joins(:bulletin)
    end
  end

  def point_for(price)
    value =
      case @variant.pricing_mode
      when "per_dozen" then price.modal.to_f / DOZENS_PER_BOX
      when "per_unit"  then price.price_per_kg.to_f * @variant.avg_weight_kg.to_f
      else                  price.price_per_kg.to_f
      end
    return nil unless value.positive?

    value *= deflation_factor(price.bulletin.price_date) if @deflated

    { date: price.bulletin.price_date.iso8601, price: value.round(2) }
  end

  def deflation_factor(date)
    load_index
    return 1.0 unless @index_fresh

    level = level_for(date)
    return 1.0 if level.nil? || level.zero?

    @base_level / level
  end

  def load_index
    return if @index_loaded

    latest = PriceIndex.where(index_name: "ipca").order(reference_month: :desc).first
    if latest
      @base_level = latest.index_level
      @base_month = latest.reference_month
      @index_levels = PriceIndex.where(index_name: "ipca")
                                .order(:reference_month)
                                .pluck(:reference_month, :index_level)
                                .to_h
      @index_fresh = (Date.current - @base_month).to_i <= PriceHistory::STALE_THRESHOLD_DAYS
    end
    @index_loaded = true
  end

  def level_for(date)
    month = date.beginning_of_month
    @index_levels.select { |m, _| m <= month }.values.last
  end
end
