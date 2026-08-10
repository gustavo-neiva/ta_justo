require "test_helper"

# Regression: the product detail page must use the SAME representative row as
# the verdict (Plan §3.1 "single source of truth"), so the displayed latest
# price equals the computed comparable.
class ProductsControllerRepresentativePriceTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Manga Detalhe", category: "fruta", section: 1)
    @variant = Variant.create!(
      product: @product, name: "Tommy", pricing_mode: "per_kg", default_for_product: true
    )
    @product.update!(default_variant: @variant)
    @bulletin = Bulletin.create!(
      market: "ceasa-rj", price_date: 1.day.ago.to_date,
      source_url: "https://ex.test/detail.pdf"
    )
    # Multi-pack: wholesale 18kg + retail 5kg on the same bulletin.
    Price.create!(
      bulletin: @bulletin, variant: @variant, section: 1,
      raw_unit: "Cx 18 kg", original_unit: "kg", modal: 110, price_per_kg: 6.11
    )
    Price.create!(
      bulletin: @bulletin, variant: @variant, section: 1,
      raw_unit: "Cx 5 kg", original_unit: "kg", modal: 65, price_per_kg: 13.0
    )
  end

  test "stat card shows the representative (smallest retail pack) price" do
    get product_path(@product.slug)
    assert_response :success

    # The retail pack price (13.0), NOT the wholesale one (6.11).
    assert_select ".stat-value", text: /13\.00/
    assert_select ".stat-value", text: /6\.11/, count: 0
  end

  test "direct-unit variant shows the modal unit price instead of an error" do
    product = Product.create!(name: "Coco Detalhe", category: "fruta", section: 1)
    variant = Variant.create!(
      product: product, name: "Verde", pricing_mode: "per_unit",
      default_for_product: true
    )
    product.update!(default_variant: variant)
    Price.create!(
      bulletin: @bulletin, variant: variant, section: 1,
      raw_unit: "Unid", original_unit: "unit",
      modal: 3.30, price_per_kg: nil
    )

    get product_path(product.slug)
    assert_response :success
    assert_select ".alert", text: /Nenhum preço encontrado/, count: 0
    assert_select ".stat-value", text: /3\.30/
  end
end
