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

  test "index links the source CEASA PDF" do
    get precos_path
    assert_response :success

    latest = Bulletin.where(market: "ceasa-rj").order(price_date: :desc).first
    assert_select "a[href=?]", latest.pdf_url, text: /Ver boletim PDF/
  end

  test "index loads and renders full época pills" do
    get precos_path
    assert_response :success

    pills = css_select(".epoca-pill")
    assert pills.any?, "expected at least one época pill"
    assert_match(/preço normal/, pills.first.text)
  end

  test "price column uses honest unit suffixes, never a modal number under /kg" do
    get precos_path
    assert_response :success

    assert_select ".col-price", text: /Preço(?!\/kg)/
    assert_select ".price-value", text: /R\$ 5\.00\/kg/
  end

  test "eggs show per-dúzia (modal ÷ 30), not the raw box price" do
    product = Product.create!(name: "Ovo", category: "ovo", section: 6)
    variant = Variant.create!(
      product: product, name: "Branco Extra", pricing_mode: "per_dozen", default_for_product: true
    )
    product.update!(default_variant: variant)

    latest = Bulletin.where(market: "ceasa-rj").order(price_date: :desc).first
    Price.create!(
      bulletin: latest, variant: variant, section: 6,
      raw_unit: "Cx 30 dz", original_unit: "dozen",
      modal: 150.0, price_per_kg: nil
    )

    get precos_path
    assert_response :success

    # 150 / 30 = 5.00 per dúzia — never the raw R$ 150 box price.
    assert_select ".price-value", text: /R\$ 5\.00\/dúzia/
    assert_select ".price-value", text: /150/, count: 0
  end

  test "products not in the core basket (fair_relevant: false) still appear on /precos" do
    product = Product.create!(
      name: "Atemóia", category: "fruta", section: 1, fair_relevant: false
    )
    variant = Variant.create!(
      product: product, name: "Comum", pricing_mode: "per_kg", default_for_product: true
    )
    product.update!(default_variant: variant)

    latest = Bulletin.where(market: "ceasa-rj").order(price_date: :desc).first
    Price.create!(
      bulletin: latest, variant: variant, section: 1,
      raw_unit: "Cx 3 kg", original_unit: "kg",
      modal: 50.0, price_per_kg: 16.67
    )

    get precos_path
    assert_response :success
    assert_select ".product-name", text: "Atemóia"
  end

  test "multi-pack variant collapses to one representative row on /precos" do
    product = Product.create!(name: "Manga", category: "fruta", section: 1)
    palmer = Variant.create!(
      product: product, name: "Palmer", pricing_mode: "per_kg", default_for_product: true
    )
    tommy = Variant.create!(
      product: product, name: "Tommy Atkins", pricing_mode: "per_kg"
    )
    product.update!(default_variant: palmer)

    latest = Bulletin.where(market: "ceasa-rj").order(price_date: :desc).first
    Price.create!(
      bulletin: latest, variant: palmer, section: 1,
      raw_unit: "Cx 8 kg", original_unit: "kg",
      modal: 64.00, price_per_kg: 8.00
    )
    Price.create!(
      bulletin: latest, variant: tommy, section: 1,
      raw_unit: "Cx 18 kg", original_unit: "kg",
      modal: 109.98, price_per_kg: 6.11
    )
    Price.create!(
      bulletin: latest, variant: tommy, section: 1,
      raw_unit: "Cx 5 kg", original_unit: "kg",
      modal: 65.00, price_per_kg: 13.00
    )

    get precos_path
    assert_response :success

    assert_select ".variant-name", text: "Tommy Atkins", count: 1
    assert_select ".variant-name", text: "Palmer", count: 1

    # Variant rows must link to the exact variant (?variant=ID), not the default.
    variant_rows = css_select(".price-row--variant[href*=variant]")
    assert_equal 2, variant_rows.size, "variant rows should carry ?variant= in href"
  end
end
