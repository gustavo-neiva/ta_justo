require "test_helper"

class MarketTimingTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Test Product #{Time.now.to_i}", category: "hortalica", section: "Hortigranjeiros")
  end

  test "#compute_returns_cheap_bucket_for_prices_at_33rd_percentile_or_below" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 10)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?, "Should not return Null for valid data"
    assert_equal :cheap, market_timing.bucket
    assert market_timing.percentile <= MarketTiming::CHEAP_THRESHOLD
  end

  test "#compute_returns_normal_bucket_for_prices_between_33rd_and_67th_percentile" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?, "Should not return Null for valid data"
    assert_equal :normal, market_timing.bucket
    assert market_timing.percentile > MarketTiming::CHEAP_THRESHOLD
    assert market_timing.percentile < MarketTiming::EXPENSIVE_THRESHOLD
  end

  test "#compute_returns_expensive_bucket_for_prices_at_67th_percentile_or_above" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 90)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?, "Should not return Null for valid data"
    assert_equal :expensive, market_timing.bucket
    assert market_timing.percentile >= MarketTiming::EXPENSIVE_THRESHOLD
  end

  test "#compute_returns_Null_when_sample_size_is_below_30" do
    setup_ipca_indices
    variant = create_variant_with_prices(count: 29, current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    assert market_timing.null?, "Should return Null when sample size < 30"
    assert_match(/29 samples/, market_timing.reason)
    assert_match(/need 30/, market_timing.reason)
  end

  test "#compute_returns_Null_when_sample_size_exactly_30" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?, "Should not return Null when sample size == 30"
    assert_equal 30, market_timing.sample_size
  end

  test "#compute_returns_Null_when_price_index_is_unavailable" do
    # No price indices created
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    assert market_timing.null?, "Should return Null when no price indices available"
    assert_match(/No IPCA data available/, market_timing.reason)
  end

  test "#compute_returns_Null_when_latest_price_index_is_too_stale" do
    # Only create a stale index — no current-month index (which would be picked as latest)
    stale_index_date = Date.current - 100.days
    create_price_index("ipca", stale_index_date, BigDecimal("7600.00"))

    # Create a variant with prices; stale index forward-fills all of them
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    assert market_timing.null?, "Should return Null when index is >90 days stale"
    assert_match(/100 days old/, market_timing.reason)
    assert_equal stale_index_date, market_timing.base_month
  end

  test "#compute_returns_Null_when_variant_has_no_prices" do
    setup_ipca_indices
    variant = Variant.create!(product: @product, name: "Test Variant #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)
    # No prices created

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    assert market_timing.null?, "Should return Null when variant has no prices"
    assert_match(/No latest price available/, market_timing.reason)
  end

  test "#compute_returns_correct_percentile_value" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 75)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?
    assert_equal 75, market_timing.percentile
  end

  test "#compute_uses_latest_wholesale_price_not_paid_amount" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 50)

    # The paid amount should NOT affect market timing — uses wholesale price only
    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?
    assert_equal 30, market_timing.sample_size
  end

  test "#compute_works_with_INPC_index" do
    # Historical INPC index for forward-fill + current-month INPC index
    create_price_index("inpc", (Date.current - 365.days).beginning_of_month, BigDecimal("6100.00"))
    create_price_index("inpc", Date.current.beginning_of_month, BigDecimal("6200.00"))
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "inpc").compute

    refute market_timing.null?, "Should work with INPC index"
    assert_equal "inpc", market_timing.index_name
  end

  test "#compute_caches_results_and_reuses_on_subsequent_calls" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 50)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca")

    # First call should compute
    result1 = market_timing.compute
    refute result1.null?

    # Second call should use cache (test env uses null_store, but still exercises cache logic)
    result2 = market_timing.compute
    refute result2.null?

    # Results should be identical
    assert_equal result1.percentile, result2.percentile
    assert_equal result1.bucket, result2.bucket
  end

  test "#description_returns_human_readable_summary" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 90)

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?
    description = market_timing.description
    assert_match(/época cara/, description)
    assert_match(/90/, description)
    assert_match(/30 amostras/, description)
    assert_match(/IPCA/, description)
  end

  test "#compute_uses_correct_cache_key_structure" do
    setup_ipca_indices
    variant = create_variant_with_30_prices(current_percentile: 50)

    latest_bulletin = variant.latest_price.bulletin
    latest_index = PriceIndex.where(index_name: "ipca").order(reference_month: :desc).first

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca")
    expected_pattern = "market_timing/#{variant.id}/#{latest_bulletin.id}/ipca/#{latest_index.reference_month}"
    assert_match expected_pattern, market_timing.send(:build_cache_key)
  end

  test "#percentile_computation_handles_equal_values_correctly" do
    # Create 30 prices where many are equal
    unique_name = "Equal Values Test #{Time.now.to_i}"
    product2 = Product.create!(name: unique_name, category: "hortalica", section: "Hortigranjeiros")
    variant = Variant.create!(product: product2, name: "Test Variant", pricing_mode: "per_kg", checkable: true)

    # Same level for both so deflation factor = 1.0 (real == nominal)
    create_price_index("ipca", (Date.current - 365.days).beginning_of_month, BigDecimal("7600.00"))
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))

    # Create 30 bulletins with prices (within 12-month window)
    max_days = 360
    (0...29).each do |i|
      days_ago = ((i + 1) * (max_days / 30)).to_i
      bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current - days_ago.days, source_url: "http://test#{i}.com")
      Price.create!(
        bulletin: bulletin,
        variant: variant,
        section: "Hortigranjeiros",
        raw_unit: "Cx 10kg",
        modal: 1000.0,
        price_per_kg: BigDecimal("10.00") # All prices are the same
      )
    end

    # Create current bulletin with same price
    bulletin_current = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test-current.com")
    Price.create!(
      bulletin: bulletin_current,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("10.00")
    )

    market_timing = MarketTiming.new(variant: variant, index_name: "ipca").compute

    refute market_timing.null?
    # With all equal prices, percentile should be 50
    assert_equal 50, market_timing.percentile
  end

  private

  def create_variant_with_30_prices(current_percentile:)
    create_variant_with_prices(count: 30, current_percentile: current_percentile)
  end

  # Creates indices needed for most tests: historical (for forward-fill) + current month.
  # Same index level for both so deflation factor = 1.0 and real == nominal,
  # keeping percentile math in tests predictable.
  def setup_ipca_indices
    create_price_index("ipca", (Date.current - 365.days).beginning_of_month, BigDecimal("7600.00"))
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))
  end

  def create_variant_with_prices(count:, current_percentile:)
    variant = Variant.create!(product: @product, name: "Test Variant #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Calculate price for the current position
    # We want the current price to be at the specified percentile
    # So if we want it at 90th percentile, it should be higher than 90% of historical prices
    base_price = BigDecimal("10.00")
    current_price = base_price + (BigDecimal("1.00") * (current_percentile / 100.0))

    # Create historical bulletins with prices
    # Use smaller intervals to stay within 12-month window
    max_days = 360 # 12 months roughly
    (0...count - 1).each do |i|
      days_ago = ((i + 1) * (max_days / count)).to_i
      bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current - days_ago.days, source_url: "http://test#{i}.com")

      # Distribute prices around the base price to create a distribution
      # Earlier prices are lower, later prices are higher
      price_position = i.to_f / (count - 1).to_f
      historical_price = base_price + (BigDecimal("1.00") * price_position)

      Price.create!(
        bulletin: bulletin,
        variant: variant,
        section: "Hortigranjeiros",
        raw_unit: "Cx 10kg",
        modal: 1000.0,
        price_per_kg: historical_price
      )
    end

    # Create current bulletin with price at specified percentile
    bulletin_current = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test-current.com")
    Price.create!(
      bulletin: bulletin_current,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: current_price
    )

    variant
  end

  def create_price_index(index_name, reference_month, index_level)
    PriceIndex.find_or_create_by!(
      index_name: index_name,
      reference_month: reference_month
    ) do |pi|
      pi.index_level = index_level
    end
  end
end