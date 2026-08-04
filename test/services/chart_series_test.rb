require "test_helper"

class ChartSeriesTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(
      name: "Chart Series Product #{Time.now.to_i}",
      slug: "chart-series-product-#{Time.now.to_i}",
      category: "hortalica",
      section: "Hortigranjeiros"
    )
  end

  test "#points deflates past prices when fresh IPCA data exists" do
    old_month = (Date.current - 11.months).beginning_of_month
    current_month = Date.current.beginning_of_month

    create_price_index("ipca", old_month, BigDecimal("7312.97"))
    create_price_index("ipca", current_month, BigDecimal("7640.15"))

    variant = Variant.create!(
      product: @product,
      name: "Chart Tomato #{Time.now.to_i}",
      pricing_mode: "per_kg",
      checkable: true
    )

    bulletin_old = Bulletin.create!(market: "CEASA-RJ", price_date: old_month, source_url: "http://test-old.com")
    Price.create!(
      bulletin: bulletin_old,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    bulletin_current = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test-current.com")
    Price.create!(
      bulletin: bulletin_current,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 1000.0,
      price_per_kg: BigDecimal("1000.00")
    )

    nominal = ChartSeries.new(variant, deflated: false).points
    deflated = ChartSeries.new(variant, deflated: true).points

    assert_equal 2, nominal.size
    assert_equal 2, deflated.size

    current_nominal = nominal.find { |p| p[:date] == bulletin_current.price_date.iso8601 }[:price]
    current_real = deflated.find { |p| p[:date] == bulletin_current.price_date.iso8601 }[:price]
    assert_in_delta current_nominal, current_real, 0.01

    old_real = deflated.find { |p| p[:date] == bulletin_old.price_date.iso8601 }[:price]
    assert_in_delta BigDecimal("1044.74"), old_real, 0.01
  end

  test "#points returns nominal series when no IPCA data exists" do
    variant = Variant.create!(
      product: @product,
      name: "Chart Tomato No Index #{Time.now.to_i}",
      pricing_mode: "per_kg",
      checkable: true
    )

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 500.0,
      price_per_kg: BigDecimal("500.00")
    )

    points = ChartSeries.new(variant, deflated: true).points

    assert_equal 1, points.size
    assert_in_delta 500.0, points.first[:price], 0.01
  end

  test "#points returns nominal series when IPCA index is stale" do
    stale_month = (Date.current - 100.days).beginning_of_month
    create_price_index("ipca", stale_month, BigDecimal("7600.00"))

    variant = Variant.create!(
      product: @product,
      name: "Chart Tomato Stale #{Time.now.to_i}",
      pricing_mode: "per_kg",
      checkable: true
    )

    bulletin = Bulletin.create!(market: "CEASA-RJ", price_date: Date.current, source_url: "http://test.com")
    Price.create!(
      bulletin: bulletin,
      variant: variant,
      section: "Hortigranjeiros",
      raw_unit: "Cx 10kg",
      modal: 800.0,
      price_per_kg: BigDecimal("800.00")
    )

    points = ChartSeries.new(variant, deflated: true).points

    assert_equal 1, points.size
    assert_in_delta 800.0, points.first[:price], 0.01
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
