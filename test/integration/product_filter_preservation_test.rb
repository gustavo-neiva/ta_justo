require "test_helper"
require "uri"

class ProductFilterPreservationTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Filtro Manga", category: "fruta", section: 1)
    @variant = Variant.create!(
      product: @product, name: "Tommy", pricing_mode: "per_kg", default_for_product: true
    )
    @variant2 = Variant.create!(
      product: @product, name: "Palmer", pricing_mode: "per_kg", default_for_product: false
    )
    @product.update!(default_variant: @variant)

    @bulletin = Bulletin.create!(
      market: "ceasa-rj", price_date: 1.day.ago.to_date,
      source_url: "https://ex.test/filter.pdf"
    )

    5.times do |i|
      Price.create!(
        bulletin: @bulletin, variant: @variant, section: 1,
        raw_unit: "Cx #{i + 1} kg", original_unit: "kg",
        modal: 100 + i, price_per_kg: 5.0 + i
      )
    end

    Price.create!(
      bulletin: @bulletin, variant: @variant2, section: 1,
      raw_unit: "Cx 1 kg", original_unit: "kg",
      modal: 120, price_per_kg: 7.0
    )
  end

  test "period pills preserve variant, period and check_price params" do
    get product_path(@product.slug, variant: @variant.id, period: "90", check_price: "8.50")
    assert_response :success

    period_values = %w[90 365 all]
    hrefs = css_select("a.pill-option[href]").map { |el| el["href"] }
    assert_equal 3, hrefs.size

    hrefs.each do |href|
      query = URI.decode_www_form(URI.parse(href).query).to_h
      assert_equal @variant.id.to_s, query["variant"]
      assert_equal "8.50", query["check_price"]
      assert_includes period_values, query["period"]
      period_values.delete(query["period"])
    end
  end

  test "variant links preserve variant, period and check_price params" do
    get product_path(@product.slug, variant: @variant.id, period: "90", check_price: "8.50")
    assert_response :success

    hrefs = css_select("a.variant-link[href]").map { |el| el["href"] }
    assert_equal 2, hrefs.size

    hrefs.each do |href|
      query = URI.decode_www_form(URI.parse(href).query).to_h
      assert_equal "90", query["period"]
      assert_equal "8.50", query["check_price"]
      assert_includes [ @variant.id.to_s, @variant2.id.to_s ], query["variant"]
    end
  end
end
