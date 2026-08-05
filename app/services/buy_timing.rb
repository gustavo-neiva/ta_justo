# BuyTiming — resolves the best available buy-timing signal for a variant.
#
# Tiering ladder (best signal first):
#   1. MarketTiming (≥30 deflated samples) → truest signal, exact percentile
#   2. SeasonalityCalculator (≥6 months)   → historical pattern (seasonal, nominal)
#   3. nil                                  → no tag shown
#
# Results are cached 24 h keyed on variant + latest bulletin.
class BuyTiming
  Result = Struct.new(:bucket, :source, :label, keyword_init: true)

  LABELS = {
    cheap:     "em época",
    normal:    "preço normal",
    expensive: "fora de época"
  }.freeze

  def self.resolve(variant)
    new(variant).resolve
  end

  def initialize(variant)
    @variant = variant
  end

  def resolve
    Rails.cache.fetch(cache_key, expires_in: 24.hours) { compute }
  end

  private

  def compute
    timing = MarketTiming.new(variant: @variant).compute
    unless timing.null?
      return Result.new(
        bucket:    timing.bucket,
        source:    :timing,
        label:     LABELS[timing.bucket]
      )
    end

    bucket = seasonality_bucket
    return nil unless bucket

    Result.new(
      bucket:    bucket,
      source:    :seasonality,
      label:     LABELS[bucket]
    )
  end

  def seasonality_bucket
    calc    = SeasonalityCalculator.new(@variant)
    medians = calc.medians_by_month
    return nil if medians.size < 6

    current = medians[Date.current.month]
    return nil unless current

    sorted  = medians.values.sort
    count   = sorted.size
    below   = sorted.count { |v| v < current }
    equal   = sorted.count { |v| v == current }
    pct     = ((below + equal / 2.0) / count * 100).round

    if pct <= 33
      :cheap
    elsif pct >= 67
      :expensive
    else
      :normal
    end
  end

  def cache_key
    latest_id = @variant.prices
                        .joins(:bulletin)
                        .order("bulletins.price_date DESC")
                        .limit(1)
                        .pick("bulletins.id")
    "buy_timing/#{@variant.id}/#{latest_id || 'none'}"
  end
end
