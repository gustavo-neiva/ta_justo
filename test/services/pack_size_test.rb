require "test_helper"

# PackSize extracts the net weight (in kg) from a CEASA raw_unit string.
# This is the deterministic input to "smallest retail pack" representative-row
# selection (Plan §3.1). Pure function — no DB.
class PackSizeTest < ActiveSupport::TestCase
  # ── Happy path: kg weights in the many formats CEASA emits ────────────────
  {
    "Cx 15 kg"             => 15.0,
    "Cx 5 kg"              => 5.0,
    "Cx 1 kg"              => 1.0,
    "Cx 1,0 kg"            => 1.0,   # Brazilian decimal comma
    "Cx 1,2 kg / 4 cambucas" => 1.2, # pack + count, weight is the first
    "Ama 0,25 kg"          => 0.25,
    "Ama 0,200 kg / 10 mol" => 0.2,
    "SC 30 KG"             => 30.0,  # uppercase
    "0,5kg"                => 0.5,   # no prefix, no space
    "Cx 2,5 kg"            => 2.5
  }.each do |raw, expected|
    test "extracts #{expected} kg from #{raw.inspect}" do
      assert_equal expected, PackSize.kg(raw)
    end
  end

  # ── Non-kg units return nil (eggs are sold by dúzia, handled elsewhere) ──
  %w[Cx 30 dz dozen Unid band].each do |raw|
    test "returns nil for #{raw.inspect} (not a kg unit)" do
      assert_nil PackSize.kg(raw)
    end
  end

  test "returns nil for blank input" do
    assert_nil PackSize.kg(nil)
    assert_nil PackSize.kg("")
  end

  # ── Piece counts (per_unit conversions use modal ÷ count) ─────────────────
  {
    "Preg 16 kg/8 unid" => 8, "Preg 2 kg/16 unid" => 16, "Preg 8 kg / 8 cab" => 8,
    "Preg 20 kg/8 cab" => 8, "Ama 0,5 kg / 10 mol" => 10, "Ama 0,25 kg / 5 unid" => 5
  }.each do |raw, expected|
    test "counts #{expected} pieces in #{raw.inspect}" do
      assert_equal expected, PackSize.count(raw)
    end
  end

  test "no count when the pack text has none" do
    [ "Cx 20 kg", "Preg 6 kg", "Unid", "Unid 2,0 kg", nil, "Cx 1,2 kg / 4 cambucas" ].each { |raw| assert_nil PackSize.count(raw), raw.inspect }
  end

  test "single_unit? only for packs that start with Unid" do
    assert PackSize.single_unit?("Unid")
    assert PackSize.single_unit?("Unid 2,0 kg")
    refute PackSize.single_unit?("Preg 16 kg/8 unid")
    refute PackSize.single_unit?(nil)
  end
end
