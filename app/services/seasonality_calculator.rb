# Computes monthly "typical price" climatology for a variant.
# - monthly_curve: array of { date: "YYYY-MM-15", price: <median for that month> }
#                  spanning the same date range as the chart, so it overlays cleanly.
# - note: human-readable cheapest/most-expensive month sentence (pt-BR).
class SeasonalityCalculator
  DOZENS_PER_BOX = 30
  MONTHS_PT = %w[janeiro fevereiro março abril maio junho
                 julho agosto setembro outubro novembro dezembro].freeze

  def initialize(variant)
    @variant = variant
  end

  # median price per calendar month (1..12), across all years
  def medians_by_month
    @medians_by_month ||= begin
      buckets = Hash.new { |h, k| h[k] = [] }
      each_value_with_date { |month, value| buckets[month] << value }
      buckets.transform_values { |vals| median(vals) }
    end
  end

  # Curve aligned to the actual data's date span, one point mid-month.
  def monthly_curve
    span = date_span
    return [] unless span

    medians = medians_by_month
    return [] if medians.empty?

    points = []
    cursor = Date.new(span.first.year, span.first.month, 15)
    last   = Date.new(span.last.year, span.last.month, 15)
    while cursor <= last
      m = medians[cursor.month]
      points << { date: cursor.iso8601, price: m.round(2) } if m
      cursor = cursor.next_month
    end
    points
  end

  def note
    medians = medians_by_month
    return nil if medians.size < 6 # need most of the year to be meaningful

    cheapest  = medians.min_by { |_m, v| v }&.first
    priciest  = medians.max_by { |_m, v| v }&.first
    return nil unless cheapest && priciest

    "#{@variant.product.name} costuma ser mais barato em #{MONTHS_PT[cheapest - 1]} " \
    "e mais caro em #{MONTHS_PT[priciest - 1]}."
  end

  private

  def each_value_with_date
    rows.find_each do |price|
      value = value_for(price)
      next unless value&.positive?
      yield price.bulletin.price_date.month, value
    end
  end

  def rows
    case @variant.pricing_mode
    when "per_dozen"
      @variant.prices.where(original_unit: "dozen").where.not(modal: nil).joins(:bulletin)
    else
      @variant.prices.where.not(price_per_kg: nil).joins(:bulletin)
    end
  end

  def value_for(price)
    case @variant.pricing_mode
    when "per_dozen" then price.modal.to_f / DOZENS_PER_BOX
    when "per_unit"  then price.price_per_kg.to_f * @variant.avg_weight_kg.to_f
    else                  price.price_per_kg.to_f
    end
  end

  def date_span
    dates = rows.minimum("bulletins.price_date")
    max   = rows.maximum("bulletins.price_date")
    return nil unless dates && max
    [dates, max]
  end

  def median(arr)
    return nil if arr.empty?
    sorted = arr.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
