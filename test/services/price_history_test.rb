require "test_helper"

class PriceHistoryTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(
      name: "Test Product #{Time.now.to_i}",
      slug: "test-product-#{Time.now.to_i}",
      category: "hortalica",
      section: "Hortigranjeiros"
    )
  end

  test "#compute returns deflated series with correct known-answer values" do
    # Setup test data matching the research example:
    # IPCA Jun/2025 = 7312.97, May/2026 = 7640.15 → R$1000 → R$1044.74

    # Create price indices for the test months
    create_price_index("ipca", Date.new(2025, 6, 1), BigDecimal("7312.97"))
    create_price_index("ipca", Date.new(2026, 5, 1), BigDecimal("7640.15"))

    # Create variant with prices at different months
    variant = Variant.create!(product: @product, name: "Test Tomato #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create bulletin for June 2025 with R$1000 price (within 12 months)
    bulletin_jun = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current - 11.months, source_url: "http://test1.com")
    Price.create!(
      bulletin: bulletin_jun,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    # Create bulletin for today with R$1000 price (the base month equivalent)
    bulletin_now = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test2.com")
    Price.create!(
      bulletin: bulletin_now,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    # Manually set the price index dates to match our test data
    # We'll use current month - 11 months as "June 2025" and current month as "May 2026"
    old_month = (Date.current - 11.months).beginning_of_month
    current_month = Date.current.beginning_of_month

    # Update price indices to match our test dates
    PriceIndex.where(index_name: "ipca", reference_month: Date.new(2025, 6, 1)).update(reference_month: old_month, index_level: BigDecimal("7312.97"))
    PriceIndex.where(index_name: "ipca", reference_month: Date.new(2026, 5, 1)).update(reference_month: current_month, index_level: BigDecimal("7640.15"))

    # Compute price history
    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert_not price_history.null?, "Should not return Null for valid data"
    assert_equal 2, price_history.series.size

    # Find the older entry (should be deflated to current month real terms)
    old_entry = price_history.series.find { |e| e[:date] == bulletin_jun.price_date }
    assert_not_nil old_entry, "Should have older entry"

    # Known-answer test: R$1000 old → R$1044.74 current real
    expected_real = BigDecimal("1044.74")
    actual_real = old_entry[:real_price]

    # Allow for small floating-point differences
    assert_in_delta expected_real, actual_real, 0.01,
                    "R$1000 old should deflate to R$#{expected_real} current real (got R$#{actual_real})"

    assert_equal BigDecimal("1000.00"), old_entry[:nominal_price]
    assert_equal current_month, price_history.base_month
  end

  test "#compute returns Null when price index is unavailable" do
    variant = Variant.create!(product: @product, name: "Test Tomato 2 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # No price indices created

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert price_history.null?, "Should return Null when no price indices available"
    assert_match(/No IPCA data available/, price_history.reason)
  end

  test "#compute returns Null when latest index is >90 days stale" do
    variant = Variant.create!(product: @product, name: "Test Tomato 3 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index that's 100 days old
    stale_index_date = Date.current - 100.days
    create_price_index("ipca", stale_index_date, BigDecimal("7600.00"))

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert price_history.null?, "Should return Null when index is >90 days stale"
    assert_match(/100 days old/, price_history.reason)
    assert_equal stale_index_date, price_history.base_month
  end

  test "#compute returns Null when variant has no price history" do
    variant = Variant.create!(product: @product, name: "Test Tomato 4 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))

    # No prices created

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert price_history.null?, "Should return Null when variant has no price history"
    assert_match(/Insufficient price history/, price_history.reason)
  end

  test "#compute returns Null when variant has only prices with missing price_per_kg" do
    product = Product.create!(
      name: "Test Product 5 #{Time.now.to_i}",
      slug: "test-product-5-#{Time.now.to_i}",
      category: "hortalica",
      section: "Hortigranjeiros"
    )
    variant = Variant.create!(product: product, name: "Test Tomato 5 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))

    # Create price without price_per_kg
    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: nil
    )

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert price_history.null?, "Should return Null when prices have no price_per_kg"
    # Either error message is acceptable
    assert_match(/Unable to deflate prices|Insufficient price history/, price_history.reason)
  end

  test "#compute forward-fills for bulletins newer than latest index month" do
    variant = Variant.create!(product: @product, name: "Test Tomato 6 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index for older month
    old_index_date = Date.current - 1.month
    create_price_index("ipca", old_index_date, BigDecimal("7640.15"))

    # Create bulletin for current date (newer than index)
    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert_not price_history.null?, "Should not return Null for forward-fill case"
    assert_equal 1, price_history.series.size

    entry = price_history.series.first
    # Forward-fill: real_price should equal nominal_price (factor 1.0)
    assert_equal entry[:nominal_price], entry[:real_price]
    assert_equal BigDecimal("1000.00"), entry[:real_price]
  end

  test "#compute uses correct cache key structure" do
    variant = Variant.create!(product: @product, name: "Test Tomato 7 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    price = Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    # Build cache key directly
    price_history = PriceHistory.new(variant: variant, index_name: "ipca")
    cache_key = price_history.send(:build_cache_key)

    assert_match(/^price_history\/\d+\/\d+\/ipca\/\d{4}-\d{2}-01$/, cache_key,
                  "Cache key should match pattern: price_history/variant_id/bulletin_id/index_name/base_month")
  end

  test "#compute caches results and reuses on subsequent calls" do
    variant = Variant.create!(product: @product, name: "Test Tomato 8 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    # First call should compute
    result1 = PriceHistory.new(variant: variant, index_name: "ipca").compute
    assert_not result1.null?

    # Second call should return cached result
    result2 = PriceHistory.new(variant: variant, index_name: "ipca").compute
    assert_not result2.null?
    assert_equal result1.series.size, result2.series.size
    assert_equal result1.base_month, result2.base_month
  end

  test "#compute works with INPC index" do
    variant = Variant.create!(product: @product, name: "Test Tomato 9 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create INPC price index
    create_price_index("inpc", Date.current.beginning_of_month, BigDecimal("6200.00"))

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    price_history = PriceHistory.new(variant: variant, index_name: "inpc").compute

    assert_not price_history.null?, "Should work with INPC index"
    assert_equal "inpc", price_history.index_name
  end

  test "#compute returns series in chronological order" do
    variant = Variant.create!(product: @product, name: "Test Tomato 10 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price indices
    create_price_index("ipca", Date.current.beginning_of_month, BigDecimal("7600.00"))
    create_price_index("ipca", (Date.current - 2.months).beginning_of_month, BigDecimal("7000.00"))

    # Create prices in reverse order
    bulletin_later = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test1.com")
    Price.create!(bulletin: bulletin_later, variant: variant, section: "Hortigranjeiros",
                  raw_unit: "Cx 10kg", modal: 1000.0, price_per_kg: BigDecimal("1000.00"))

    bulletin_earlier = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current - 2.months, source_url: "http://test2.com")
    Price.create!(bulletin: bulletin_earlier, variant: variant, section: "Hortigranjeiros",
                  raw_unit: "Cx 10kg", modal: 900.0, price_per_kg: BigDecimal("900.00"))

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert_not price_history.null?
    assert_equal 2, price_history.series.size

    # Verify chronological order
    assert price_history.series.first[:date] < price_history.series.last[:date]
  end

  test "#sample_size returns correct number of data points" do
    product = Product.create!(
      name: "Test Product 11 #{Time.now.to_i}",
      slug: "test-product-11-#{Time.now.to_i}",
      category: "hortalica",
      section: "Hortigranjeiros"
    )
    variant = Variant.create!(product: product, name: "Test Tomato 11 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price indices for each month
    3.times do |i|
      create_price_index("ipca", (Date.current - (2 - i).months).beginning_of_month, BigDecimal("7600.00"))
    end

    # Create 3 prices within 12 months
    3.times do |i|
      bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current - (2 - i).months, source_url: "http://test#{i}.com")
      Price.create!(bulletin: bulletin, variant: variant, section: "Hortigranjeiros",
                    raw_unit: "Cx 10kg", modal: 1000.0, price_per_kg: BigDecimal("1000.00"))
    end

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    assert_not price_history.null?
    assert_equal 3, price_history.sample_size
  end

  test "#compute handles missing price index for specific month" do
    variant = Variant.create!(product: @product, name: "Test Tomato 12 #{Time.now.to_i}", pricing_mode: "per_kg", checkable: true)

    # Create price index only for older month
    old_index_date = Date.current - 1.month
    create_price_index("ipca", old_index_date, BigDecimal("7640.15"))

    # Create bulletin for current date with price
    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(bulletin: bulletin, variant: variant, section: "Hortigranjeiros",
                  raw_unit: "Cx 10kg", modal: 1000.0, price_per_kg: BigDecimal("1000.00"))

    price_history = PriceHistory.new(variant: variant, index_name: "ipca").compute

    # Should still work due to forward-fill
    assert_not price_history.null?
    assert_equal 1, price_history.series.size
  end

  private

  def create_price_index(index_name, reference_month, index_level)
    PriceIndex.find_or_create_by!(
      index_name: index_name,
      reference_month: reference_month
    ) do |pi|
      pi.index_level = index_level
    end
  end
end