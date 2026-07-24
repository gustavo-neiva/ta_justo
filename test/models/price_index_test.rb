require "test_helper"

class PriceIndexTest < ActiveSupport::TestCase
  test "validates inclusion of index_name" do
    index = PriceIndex.new(
      index_name: "invalid",
      reference_month: Date.new(2024, 1, 1),
      index_level: 100.0
    )

    assert_not index.valid?
    assert index.errors[:index_name].any?
  end

  test "accepts valid index_name values" do
    %w[ipca inpc].each do |valid_name|
      index = PriceIndex.new(
        index_name: valid_name,
        reference_month: Date.new(2024, 1, 1),
        index_level: 100.0
      )
      assert index.valid?, "#{valid_name} should be valid"
    end
  end

  test "validates uniqueness of reference_month scoped to index_name" do
    existing_index = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 1, 1),
      index_level: 100.0
    )

    duplicate_index = PriceIndex.new(
      index_name: "ipca",
      reference_month: Date.new(2024, 1, 1),
      index_level: 200.0
    )

    assert_not duplicate_index.valid?
    assert duplicate_index.errors[:reference_month].any?
  end

  test "allows same reference_month for different index_name" do
    ipca_index = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 1, 1),
      index_level: 100.0
    )

    inpc_index = PriceIndex.new(
      index_name: "inpc",
      reference_month: Date.new(2024, 1, 1),
      index_level: 95.0
    )

    assert inpc_index.valid?
  end

  test "scope for_month returns index for specific month and index_name" do
    ipca_jan = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 1, 1),
      index_level: 100.0
    )

    ipca_feb = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 2, 1),
      index_level: 101.5
    )

    inpc_jan = PriceIndex.create!(
      index_name: "inpc",
      reference_month: Date.new(2024, 1, 1),
      index_level: 95.0
    )

    result = PriceIndex.for_month(Date.new(2024, 1, 1), "ipca")
    assert_equal 1, result.count
    assert_equal ipca_jan, result.first
  end

  test "scope latest returns most recent reference_month per index_name" do
    ipca_old = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 1, 1),
      index_level: 100.0
    )

    ipca_new = PriceIndex.create!(
      index_name: "ipca",
      reference_month: Date.new(2024, 2, 1),
      index_level: 101.5
    )

    inpc_new = PriceIndex.create!(
      index_name: "inpc",
      reference_month: Date.new(2024, 2, 1),
      index_level: 95.0
    )

    result = PriceIndex.latest
    assert_equal 2, result.count

    latest_ipca = result.find { |idx| idx.index_name == "ipca" }
    assert_equal ipca_new, latest_ipca

    latest_inpc = result.find { |idx| idx.index_name == "inpc" }
    assert_equal inpc_new, latest_inpc
  end
end
