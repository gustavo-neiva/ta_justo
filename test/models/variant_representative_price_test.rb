require "test_helper"

# Variant#representative_price — the deterministic "smallest retail pack"
# selection that replaces the ad-hoc first-by-date pick (Plan §3.1).
# It is the single source of truth shared by verdict, controller stats,
# and the raw-data "usamos esta" highlight.
class VariantRepresentativePriceTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Manga", category: "fruta", section: 1)
    @variant = Variant.create!(
      product: @product, name: "Tommy", pricing_mode: "per_kg"
    )
    @bulletin = Bulletin.create!(
      market: "ceasa-rj", price_date: Date.new(2026, 6, 19),
      source_url: "https://ex.test/b.pdf"
    )
  end

  # ── Core: smallest retail pack wins among same-bulletin rows ─────────────
  test "picks the smallest retail pack on a multi-pack bulletin (per_kg)" do
    big   = price_row("Cx 18 kg", modal: 110, min: 100, max: 120, per_kg: 6.11)
    small = price_row("Cx 5 kg",  modal: 65,  min: 60,  max: 70,  per_kg: 13.0)

    assert_equal small, @variant.representative_price(bulletin: @bulletin)
  end

  test "is deterministic regardless of insertion order" do
    small = price_row("Cx 5 kg",  modal: 65,  per_kg: 13.0)
    big   = price_row("Cx 18 kg", modal: 110, per_kg: 6.11)

    assert_equal small, @variant.representative_price(bulletin: @bulletin)
  end

  # ── Single-pack bulletin: that row is representative ─────────────────────
  test "returns the only row when there is a single pack" do
    only = price_row("Cx 15 kg", modal: 60, per_kg: 4.0)
    assert_equal only, @variant.representative_price(bulletin: @bulletin)
  end

  # ── Mode scoping ─────────────────────────────────────────────────────────
  test "per_dozen selects from original_unit = 'dozen' rows" do
    egg = Variant.create!(
      product: Product.create!(name: "Ovo", category: "ovo", section: 6),
      name: "Branco", pricing_mode: "per_dozen"
    )
    dozen_row = Price.create!(
      bulletin: @bulletin, variant: egg, section: 6,
      original_unit: "dozen", modal: 180, raw_unit: "Cx 30 dz"
    )
    # A stray per-kg row must not be picked for a per_dozen variant
    Price.create!(
      bulletin: @bulletin, variant: egg, section: 6,
      original_unit: "kg", modal: 9, raw_unit: "Cx 1 kg", price_per_kg: 9
    )

    assert_equal dozen_row, egg.representative_price(bulletin: @bulletin)
  end

  test "per_kg/per_unit ignore rows without price_per_kg" do
    # Row with no per_kg should never be the representative comparable value
    price_row("Cx 10 kg", modal: 50, per_kg: nil)
    good = price_row("Cx 5 kg", modal: 40, per_kg: 8.0)

    assert_equal good, @variant.representative_price(bulletin: @bulletin)
  end

  test "returns nil when no usable row exists for the bulletin" do
    assert_nil @variant.representative_price(bulletin: @bulletin)
  end

  # ── per_unit: direct-unit rows (original_unit = 'unit', price_per_kg nil) ───
  test "per_unit selects direct-unit row when price_per_kg is nil" do
    coco = Variant.create!(
      product: Product.create!(name: "Coco", category: "fruta", section: 1),
      name: "Verde", pricing_mode: "per_unit", avg_weight_kg: 1.2
    )
    unit = Price.create!(
      bulletin: @bulletin, variant: coco, section: 1,
      raw_unit: "Unid", original_unit: "unit",
      modal: 3.30, price_per_kg: nil
    )

    assert_equal unit, coco.representative_price(bulletin: @bulletin)
  end

  test "per_unit prefers direct-unit row over weight-derived rows" do
    coco = Variant.create!(
      product: Product.create!(name: "Coco", category: "fruta", section: 1),
      name: "Verde", pricing_mode: "per_unit", avg_weight_kg: 1.2
    )
    unit = Price.create!(
      bulletin: @bulletin, variant: coco, section: 1,
      raw_unit: "Unid", original_unit: "unit",
      modal: 3.30, price_per_kg: nil
    )
    Price.create!(
      bulletin: @bulletin, variant: coco, section: 1,
      raw_unit: "Cx 10 kg", original_unit: "kg",
      modal: 50.0, price_per_kg: 5.0
    )

    assert_equal unit, coco.representative_price(bulletin: @bulletin)
  end

  test "per_unit weight-derived rows still use smallest retail pack" do
    melon = Variant.create!(
      product: Product.create!(name: "Melancia", category: "fruta", section: 1),
      name: "Crimson", pricing_mode: "per_unit", avg_weight_kg: 5.0
    )
    big   = Price.create!(
      bulletin: @bulletin, variant: melon, section: 1,
      raw_unit: "Cx 20 kg", original_unit: "kg",
      modal: 80.0, price_per_kg: 4.0
    )
    small = Price.create!(
      bulletin: @bulletin, variant: melon, section: 1,
      raw_unit: "Cx 5 kg", original_unit: "kg",
      modal: 25.0, price_per_kg: 5.0
    )

    assert_equal small, melon.representative_price(bulletin: @bulletin)
  end

  test "latest_price resolves a direct-unit row" do
    coco = Variant.create!(
      product: Product.create!(name: "Coco", category: "fruta", section: 1),
      name: "Verde", pricing_mode: "per_unit", avg_weight_kg: 1.2
    )
    unit = Price.create!(
      bulletin: @bulletin, variant: coco, section: 1,
      raw_unit: "Unid", original_unit: "unit",
      modal: 3.30, price_per_kg: nil
    )

    assert_equal unit, coco.latest_price
  end

  test "representative_series includes direct-unit rows for per_unit" do
    coco = Variant.create!(
      product: Product.create!(name: "Coco", category: "fruta", section: 1),
      name: "Verde", pricing_mode: "per_unit", avg_weight_kg: 1.2
    )
    Price.create!(
      bulletin: @bulletin, variant: coco, section: 1,
      raw_unit: "Unid", original_unit: "unit",
      modal: 3.30, price_per_kg: nil
    )

    series = coco.representative_series
    assert_equal 1, series.size
    assert_equal "unit", series.first.original_unit
  end

  private

  def price_row(raw_unit, modal:, min: nil, max: nil, per_kg: nil)
    Price.create!(
      bulletin: @bulletin, variant: @variant, section: 1,
      raw_unit: raw_unit, original_unit: "kg",
      modal: modal, min: min, max: max, price_per_kg: per_kg
    )
  end
end
