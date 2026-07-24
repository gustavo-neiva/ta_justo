require "test_helper"

# Regression guard for the percentile bug (Plan §3.1).
# The OLD code ranked `@paid_amount` against the historical series — so the
# percentile moved with what the shopper paid, which is nonsensical for a
# "market timing" judgment about the COMMODITY. It must rank today's CEASA
# value, and be strictly paid-independent.
class FairPriceVerdictPercentileTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Abacaxi", category: "fruta", section: 1)
    @variant = Variant.create!(
      product: @product, name: "Pérola", pricing_mode: "per_unit",
      avg_weight_kg: 1.5
    )
    # Build 12 monthly bulletins with a CEASA price_per_kg series.
    @bulletins = (1..12).map do |i|
      Bulletin.create!(
        market: "ceasa-rj",
        price_date: Date.new(2025, 7, 1) + (i - 1).months,
        source_url: "https://ex.test/#{i}.pdf"
      )
    end
    # per_kg climbs 2.0 -> 3.1; latest (today) is the HIGHEST.
    @bulletins.each_with_index do |b, i|
      Price.create!(
        bulletin: b, variant: @variant, section: 1,
        raw_unit: "Unid 1,5 kg", original_unit: "kg",
        modal: ((2.0 + i * 0.1) * 1.5), price_per_kg: (2.0 + i * 0.1)
      )
    end
  end

  test "per_unit percentile ranks the CEASA series, not the shopper's price" do
    # Same variant, two wildly different paid prices. The percentile of the
    # COMMODITY must be identical — it does not depend on what the shopper pays.
    rich = verdict_for(paid: 999.0)
    poor = verdict_for(paid: 0.50)

    assert rich.percentile_12m == poor.percentile_12m,
           "percentile must be paid-independent (got #{rich.percentile_12m} vs #{poor.percentile_12m})"
  end

  test "per_unit percentile reflects today's CEASA position in the series" do
    # Today's CEASA is the highest of 12 → ~92nd percentile (11 below it).
    # Freeze clock so all 12 bulletins stay within 12.months.ago window.
    travel_to(Date.new(2026, 6, 1)) do
      res = verdict_for(paid: 100.0) # paid huge so it can't accidentally match
      assert_equal 92, res.percentile_12m
    end
  end

  private

  def verdict_for(paid:)
    FairPriceVerdict.new(variant: @variant, paid_amount: paid).call
  end
end
