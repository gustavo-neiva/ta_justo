# MarketTiming — value object for judging commodity market timing
#
# Computes where today's wholesale price sits in its own deflated 12-month
# distribution, independent of what a shopper pays.
#
# From plan §3.2:
# - Buckets: ≤33rd pct = época barata, 33-67 = preço normal, ≥67th = época cara
# - Sample guard: ≥30 points required; below that → Null
# - Paid-independent: uses wholesale prices only, not shopper paid amount
#
# @attr_reader [Variant] variant The variant to analyze
# @attr_reader [String] index_name Price index name ('ipca' or 'inpc')
# @attr_reader [Integer] percentile Percentile rank (0-100)
# @attr_reader [Symbol] bucket One of :cheap, :normal, :expensive
# @attr_reader [Date] base_month The base month for deflation
# @attr_reader [Integer] sample Sample size used for percentile computation
class MarketTiming
  CHEAP_THRESHOLD = 33
  EXPENSIVE_THRESHOLD = 67
  MINIMUM_SAMPLE_SIZE = 30

  BUCKETS = {
    cheap: "época barata",
    normal: "preço normal",
    expensive: "época cara"
  }.freeze

  attr_reader :variant, :index_name, :percentile, :bucket, :base_month, :sample_size

  def initialize(variant:, index_name: "ipca")
    @variant = variant
    @index_name = index_name
    @percentile = nil
    @bucket = nil
    @base_month = nil
    @sample_size = 0
  end

  # Compute market timing for the variant
  #
  # @return [MarketTiming, MarketTiming::Null] Returns self or Null if computation fails
  def compute
    cache_key = build_cache_key

    result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      perform_computation
    end

    return result if result.is_a?(MarketTiming::Null)

    @percentile = result.percentile
    @bucket = result.bucket
    @base_month = result.base_month
    @sample_size = result.sample_size
    self
  rescue => e
    Rails.logger.error("MarketTiming computation failed: #{e.message}")
    MarketTiming::Null.new(variant: @variant, index_name: @index_name, base_month: nil, reason: e.message)
  end

  # Null check
  def null?
    false
  end

  # Human-readable description
  def description
    return nil if null?
    "#{BUCKETS[@bucket]} (#{@percentile}º percentil, #{@sample_size} amostras, base #{@index_name.upcase} #{@base_month&.strftime('%b/%Y')})"
  end

  private

  def perform_computation
    # Check if variant has any prices at all before computing history
    latest_price = @variant.latest_price
    unless latest_price
      return MarketTiming::Null.new(
        variant: @variant,
        index_name: @index_name,
        base_month: nil,
        reason: "No latest price available"
      )
    end

    # Get deflated 12-month series
    price_history = PriceHistory.new(variant: @variant, index_name: @index_name).compute

    # If PriceHistory is null, propagate the null
    if price_history.null?
      return MarketTiming::Null.new(
        variant: @variant,
        index_name: @index_name,
        base_month: price_history.base_month,
        reason: price_history.reason
      )
    end

    # Sample size guard: need at least 30 samples
    if price_history.sample_size < MINIMUM_SAMPLE_SIZE
      return MarketTiming::Null.new(
        variant: @variant,
        index_name: @index_name,
        base_month: price_history.base_month,
        reason: "Insufficient price history (#{price_history.sample_size} samples, need #{MINIMUM_SAMPLE_SIZE})"
      )
    end

    # Get the deflated version of the current price (latest entry in real-terms series)
    latest_real_price = price_history.series.last&.dig(:real_price)
    unless latest_real_price
      return MarketTiming::Null.new(
        variant: @variant,
        index_name: @index_name,
        base_month: price_history.base_month,
        reason: "No deflated price available"
      )
    end

    # Extract real prices from the historical series
    real_prices = price_history.series.map { |entry| entry[:real_price] }

    # Compute percentile rank of current price against historical distribution
    percentile = compute_percentile(latest_real_price, real_prices)
    bucket = determine_bucket(percentile)

    Result.new(
      percentile: percentile,
      bucket: bucket,
      base_month: price_history.base_month,
      sample_size: price_history.sample_size
    )
  end

  # Compute percentile rank
  #
  # @param value [BigDecimal] The value to rank
  # @param distribution [Array<BigDecimal>] The distribution to rank against
  # @return [Integer] Percentile rank (0-100)
  def compute_percentile(value, distribution)
    return 0 if distribution.empty?

    # Count how many values are less than the target value
    less_than = distribution.count { |v| v < value }

    # Count how many values are equal to the target value
    equal_to = distribution.count { |v| v == value }

    # Percentile formula: (number of values less than + half of equal values) / total * 100
    ((less_than + (equal_to / 2.0)) / distribution.size * 100).round
  end

  # Determine bucket from percentile
  #
  # @param percentile [Integer] Percentile rank (0-100)
  # @return [Symbol] One of :cheap, :normal, :expensive
  def determine_bucket(percentile)
    return :cheap if percentile <= CHEAP_THRESHOLD
    return :expensive if percentile >= EXPENSIVE_THRESHOLD
    :normal
  end

  # Build cache key per plan §3.6
  #
  # @return [String] Cache key
  def build_cache_key
    latest_bulletin = @variant.latest_price&.bulletin
    return "market_timing/null" unless latest_bulletin

    latest_index = PriceIndex.where(index_name: @index_name).order(reference_month: :desc).first
    return "market_timing/null" unless latest_index

    "market_timing/#{@variant.id}/#{latest_bulletin.id}/#{@index_name}/#{latest_index.reference_month}"
  end

  # Result object containing market timing data
  class Result
    attr_reader :percentile, :bucket, :base_month, :sample_size

    def initialize(percentile:, bucket:, base_month:, sample_size:)
      @percentile = percentile
      @bucket = bucket
      @base_month = base_month
      @sample_size = sample_size
    end
  end

  # Null result for when computation fails
  class Null
    attr_reader :variant, :index_name, :base_month, :reason

    def initialize(variant:, index_name:, base_month:, reason:)
      @variant = variant
      @index_name = index_name
      @base_month = base_month
      @reason = reason
    end

    def null?
      true
    end

    def percentile
      nil
    end

    def bucket
      nil
    end

    def sample_size
      0
    end

    def description
      nil
    end
  end
end
