require "test_helper"

class PrecosPageTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @product = Product.create!(name: "Manga Espadal", category: "fruta", section: 1)
    @variant = Variant.create!(
      product: @product, name: "Espada", pricing_mode: "per_kg", default_for_product: true
    )
    @product.update!(default_variant: @variant)

    # Seed one bulletin per month for 7 distinct months so seasonality has >=6 medians.
    7.times do |i|
      bulletin = Bulletin.create!(
        market: "ceasa-rj",
        price_date: (6 - i).months.ago.to_date,
        source_url: "https://ex.test/precos-#{i}.pdf"
      )
      Price.create!(
        bulletin: bulletin, variant: @variant, section: 1,
        raw_unit: "Cx 1 kg", original_unit: "kg",
        modal: 10.0, price_per_kg: 5.0
      )
    end
  end

  test "index loads and renders full época pills" do
    get precos_path
    assert_response :success

    pills = css_select(".epoca-pill")
    assert pills.any?, "expected at least one época pill"
    assert_match(/tipicamente/, pills.first.text)
  end
end
