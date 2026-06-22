require "test_helper"

class CeasaRio::ParserTest < ActiveSupport::TestCase
  MODERN_FIXTURE = Rails.root.join("test/fixtures/files/ceasa/modern/2026-06-19.pdf").to_s
  LEGACY_JAN22   = Rails.root.join("test/fixtures/files/ceasa/legacy/2022-01-25.pdf").to_s
  LEGACY_DEC22   = Rails.root.join("test/fixtures/files/ceasa/legacy/2022-12-30.pdf").to_s
  LEGACY_JAN23   = Rails.root.join("test/fixtures/files/ceasa/legacy/2023-01-02.pdf").to_s

  # ── Phase L1 ─────────────────────────────────────────────────────────────────
  # Modern parse is byte-identical to pre-refactor (dispatcher delegates correctly)

  test "modern: parses date and weekday" do
    b = parse(MODERN_FIXTURE)
    assert_equal Date.new(2026, 6, 19), b.price_date
    assert_equal "sexta-feira", b.weekday
  end

  test "modern: returns more than 150 rows" do
    assert parse(MODERN_FIXTURE).rows.size > 150
  end

  test "modern: ABACATE row in section 1 with expected modal" do
    row = parse(MODERN_FIXTURE).rows.find { |r| r.raw_product == "ABACATE" }
    assert row, "Expected an ABACATE row"
    assert_equal 1, row.section
    assert_in_delta 60.0, row.modal, 0.01
  end

  test "modern: egg row uses per-dozen family with nil price_per_kg" do
    row = parse(MODERN_FIXTURE).rows.find { |r| r.raw_product == "OVO" }
    assert row, "Expected an OVO row"
    assert_equal 6, row.section
    assert_includes row.raw_unit, "dz"
    assert_nil row.price_per_kg
  end

  # ── Phase L2 ─────────────────────────────────────────────────────────────────
  # Legacy parser: date, weekday, sections, *Tipo blocks, weights, eggs, Sem cotação

  test "legacy: parses date and derives weekday" do
    b = parse(LEGACY_JAN22)
    assert_equal Date.new(2022, 1, 25), b.price_date
    assert_equal "terça-feira", b.weekday
  end

  test "legacy: variation_12m is nil on all rows" do
    b = parse(LEGACY_JAN22)
    assert b.rows.any?, "Expected rows"
    assert b.rows.none?(&:variation_12m), "Expected all variation_12m to be nil"
  end

  test "legacy: returns more than 150 rows" do
    assert parse(LEGACY_JAN22).rows.size > 150
  end

  test "legacy: section mapping — Acelga → section 4 (Folhas)" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.raw_product == "Acelga" }
    assert row
    assert_equal 4, row.section
  end

  test "legacy: section mapping — ABACATE → section 1 (Frutas Nacionais)" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.raw_product == "ABACATE" }
    assert row
    assert_equal 1, row.section
  end

  test "legacy: section mapping — OVOS → section 6" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.section == 6 }
    assert row, "Expected a row in section 6 (OVOS)"
  end

  test "legacy: section mapping — fish → section 7 (Pescados)" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.section == 7 }
    assert row, "Expected a row in section 7 (Pescados)"
  end

  test "legacy: *Tipo block — ALFACE CRESPA *Extra has correct product, tipo, unit and modal" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.raw_product == "ALFACE CRESPA" && r.raw_tipo == "Extra" }
    assert row, "Expected ALFACE CRESPA *Extra row"
    assert_equal 4, row.section
    assert_includes row.raw_unit, "6"
    assert_includes row.raw_unit, "kg"
    assert_in_delta 25.0, row.modal, 0.01
  end

  test "legacy: weight from parens — Acelga (PGM 20 KG) → price_per_kg = modal / 20" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.raw_product == "Acelga" }
    assert row
    assert_in_delta 18.0 / 20.0, row.price_per_kg, 0.01
  end

  test "legacy: eggs are per-dozen family with nil price_per_kg" do
    row = parse(LEGACY_JAN22).rows.find { |r| r.section == 6 && r.raw_tipo == "Extra" }
    assert row, "Expected OVOS *Extra row"
    assert_includes row.raw_unit, "dz"
    assert_nil row.price_per_kg
  end

  test "legacy: Sem cotação rows have nil prices but are still present" do
    rows = parse(LEGACY_JAN22).rows.select { |r| r.modal.nil? }
    assert rows.any?, "Expected at least one Sem cotação row"
    # verify they're proper Row structs (section assigned, product present)
    rows.first(5).each do |r|
      assert r.raw_product.present?, "Sem cotação row should have a raw_product"
    end
  end

  test "legacy: 2022-12-30 parses without error and has >150 rows" do
    b = parse(LEGACY_DEC22)
    assert b.price_date
    assert b.rows.size > 150
  end

  test "legacy: 2023-01-02 parses without error and has >150 rows" do
    b = parse(LEGACY_JAN23)
    assert b.price_date
    assert b.rows.size > 150
  end

  # ── Dispatcher ───────────────────────────────────────────────────────────────

  test "dispatcher: routes modern PDF to Modern sub-parser" do
    b = parse(MODERN_FIXTURE)
    # Modern has variation_12m (could be nil if no 12M data, but weekday is extracted from text)
    assert_equal Date.new(2026, 6, 19), b.price_date
  end

  test "dispatcher: routes legacy PDF to Legacy sub-parser (derives weekday, no variation_12m)" do
    b = parse(LEGACY_JAN22)
    assert_equal "terça-feira", b.weekday  # derived, not read from text
    assert b.rows.none?(&:variation_12m)
  end

  private

  def parse(path)
    CeasaRio::Parser.new(path).parse
  end
end
