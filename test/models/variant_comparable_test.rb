require "test_helper"

# Variant#comparable is the single CEASA-row → shopper-unit conversion used by
# the verdict, charts, seasonality and the checker breakdown.
class VariantComparableTest < ActiveSupport::TestCase
  def variant(mode, weight = nil)
    Variant.new(name: "V", pricing_mode: mode, avg_weight_kg: weight)
  end

  def row(raw_unit, modal, ppkg: nil, unit: "kg")
    Price.new(raw_unit: raw_unit, modal: modal, price_per_kg: ppkg, original_unit: unit)
  end

  test "per_unit divides by the piece count CEASA prints, not our weight guess" do
    # Couve-flor 2026-10: R$30 per crate of 8 heads = R$3.75/head
    # (weight path gave 1.88/kg × 1.2 kg = 2.26; the old "2 kg/16 unid" text gave 21).
    assert_in_delta 3.75, variant("per_unit", 1.2).comparable(row("Preg 16 kg/8 unid", 30, ppkg: 1.88)), 0.001
    assert_in_delta 1.5, variant("per_unit", 0.1).comparable(row("Ama 0,5 kg / 10 mol", 15, ppkg: 30)), 0.001
  end

  test "per_unit 'Unid 2,0 kg' is a per-piece quote" do
    assert_equal 6.0, variant("per_unit", 1.5).comparable(row("Unid 2,0 kg", 6, ppkg: 3))
  end

  test "per_unit falls back to avg weight when CEASA gives only a pack weight" do
    value, basis = variant("per_unit", 0.35).comparable_with_basis(row("Preg 6 kg", 40, ppkg: 6.67))
    assert_in_delta 2.33, value, 0.01
    assert_match(/peso estimado/, basis)
  end

  test "per_kg and per_dozen" do
    value, basis = variant("per_kg").comparable_with_basis(row("Cx 18 kg", 120, ppkg: 6.67))
    assert_equal 6.67, value
    assert_equal "R$ 120,00 ÷ 18 kg", basis
    assert_in_delta 4.67, variant("per_dozen").comparable(row("Cx 30 dz", 140, unit: "dozen")), 0.01
  end

  test "zero or missing modal is no price" do
    assert_nil variant("per_kg").comparable(row("0,5kg", 0, ppkg: 0))
    assert_nil variant("per_unit", 1).comparable(row("Unid", nil, unit: "unit"))
  end
end
