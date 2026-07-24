# PriceHistory — deflated 12-month real-terms series for a variant
#
# Computes the trailing-12-month series of representative prices,
# deflated to the latest published index month for real-terms comparison.
#
# From plan §3.3:
# - Official IBGE formula: real = nominal × (índice_base / índice_data)
# - Base = latest published index month, forward-filled
# - Bulletins newer than the last published month use factor 1.0
# - >90d-stale latest index ⇒ Null
#
class PriceHistory
  STALE_THRESHOLD_DAYS = 90

  attr_reader :variant, :index_name, :base_month, :series, :sample_size, :reason

  def initialize(variant:, index_name: "ipca")
    @variant = variant
    @index_name = index_name
    @base_month = nil
    @series = []
    @sample_size = 0
    @reason = nil
  end

  # Compute deflated 12-month series
  #
  # @return [PriceHistory, PriceHistory::Null] Returns self or Null if computation fails
  def compute
    cache_key = build_cache_key

    result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      perform_computation
    end

    return result if result.is_a?(PriceHistory::Null)

    @base_month = result.base_month
    @series = result.series
    @sample_size = result.sample_size
    self
  rescue => e
    Rails.logger.error("PriceHistory computation failed: #{e.message}")
    PriceHistory::Null.new(variant: @variant, index_name: @index_name, base_month: nil, reason: e.message)
  end

  # Null check
  def null?
    false
  end

  # Result object containing deflated series data
  class Result
    attr_reader :series, :base_month, :sample_size

    def initialize(series, base_month, sample_size)
      @series = series
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

    def series
      []
    end

    def sample_size
      0
    end
  end

  private

  def perform_computation
    latest_index = PriceIndex.where(index_name: @index_name).order(reference_month: :desc).first

    base_month_for_null = latest_index&.reference_month

    # Guard: No index data available
    return Null.new(
      variant: @variant,
      index_name: @index_name,
      base_month: base_month_for_null,
      reason: "No #{@index_name.upcase} data available"
    ) unless latest_index

    # Guard: Index is too stale (>90 days old)
    latest_index_month = latest_index.reference_month
    staleness_days = (Date.current - latest_index_month).to_i
    if staleness_days > STALE_THRESHOLD_DAYS
      return Null.new(
        variant: @variant,
        index_name: @index_name,
        base_month: base_month_for_null,
        reason: "Latest #{@index_name.upcase} index is #{staleness_days} days old (>90 day threshold)"
      )
    end

    # Get representative prices for the last 12 months
    price_series = @variant.representative_series(months: 12)

    if price_series.empty?
      # Distinguish: no prices at all vs. prices exist but all have nil price_per_kg
      raw_count = @variant.prices.joins(:bulletin)
        .where("bulletins.price_date >= ?", 12.months.ago)
        .count
      reason = raw_count > 0 ? "Unable to deflate prices (missing price_per_kg)" : "Insufficient price history"
      return Null.new(variant: @variant, index_name: @index_name, base_month: latest_index_month, reason: reason)
    end

    # Build deflated series
    deflated_series = price_series.filter_map do |price|
      bulletin_date = price.bulletin.price_date

      # Skip if price_per_kg is missing
      next unless price.price_per_kg.present?

      # Find the index for the bulletin month (or latest available)
      index = find_index_for_month(bulletin_date, @index_name)

      # Skip if no index available for this month
      next unless index

      deflated_price = deflate(price.price_per_kg, index.index_level, latest_index.index_level)

      {
        date: bulletin_date,
        nominal_price: price.price_per_kg,
        real_price: deflated_price
      }
    end

    # Guard: All prices failed to deflate
    return Null.new(
      variant: @variant,
      index_name: @index_name,
      base_month: latest_index_month,
      reason: "Unable to deflate prices (missing index data)"
    ) if deflated_series.empty?

    Result.new(deflated_series, latest_index_month, deflated_series.size)
  end

  # Apply IBGE deflation formula: real = nominal × (índice_base / índice_data)
  #
  # @param nominal_price [BigDecimal] Nominal price
  # @param index_data [BigDecimal] Index level at the price date
  # @param index_base [BigDecimal] Index level at the base month
  # @return [BigDecimal] Deflated (real) price
  def deflate(nominal_price, index_data, index_base)
    return nominal_price if index_data.nil? || index_data.zero?

    nominal_price * (index_base / index_data)
  end

  # Find price index for a specific month
  # Uses forward-fill: returns the latest available index if exact month not found
  #
  # @param date [Date] The date to find index for
  # @param index_name [String] Price index name ('ipca' or 'inpc')
  # @return [PriceIndex, nil] The price index or nil
  def find_index_for_month(date, index_name)
    month_start = date.beginning_of_month

    # Try to find exact month match
    index = PriceIndex.where(index_name: index_name, reference_month: month_start).first
    return index if index

    # Forward-fill: find the latest index before or at this date
    PriceIndex.where(index_name: index_name)
      .where("reference_month <= ?", month_start)
      .order(reference_month: :desc)
      .first
  end

  # Build cache key per plan §3.6
  #
  # @return [String] Cache key
  def build_cache_key
    latest_bulletin = @variant.latest_price&.bulletin
    return "price_history/null" unless latest_bulletin

    latest_index = PriceIndex.where(index_name: @index_name).order(reference_month: :desc).first
    return "price_history/null" unless latest_index

    "price_history/#{@variant.id}/#{latest_bulletin.id}/#{@index_name}/#{latest_index.reference_month}"
  end
end
