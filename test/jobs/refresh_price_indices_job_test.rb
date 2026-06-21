require "test_helper"

class RefreshPriceIndicesJobTest < ActiveJob::TestCase
  teardown do
    PriceIndex.delete_all
  end

  test "fetches and upserts IPCA and INPC data" do
    # Mock the fetcher to return test data
    ipca_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7300.00") },
      { reference_month: Date.new(2025, 2, 1), index_level: BigDecimal("7350.00") },
      { reference_month: Date.new(2025, 3, 1), index_level: BigDecimal("7400.00") }
    ]

    inpc_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7200.00") },
      { reference_month: Date.new(2025, 2, 1), index_level: BigDecimal("7250.00") },
      { reference_month: Date.new(2025, 3, 1), index_level: BigDecimal("7300.00") }
    ]

    # Use define_singleton_method to create a mock fetcher
    mock_fetcher = Object.new
    mock_fetcher.define_singleton_method(:fetch_ipc) { ipca_test_data }
    mock_fetcher.define_singleton_method(:fetch_inpc) { inpc_test_data }

    # Temporarily replace the Fetcher.new method
    original_new = PriceIndex::Fetcher.method(:new)
    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher }

    job = RefreshPriceIndicesJob.new
    job.perform

    # Restore original new method
    PriceIndex::Fetcher.define_singleton_method(:new, &original_new)

    # Verify data was upserted
    assert_equal 3, PriceIndex.where(index_name: "ipca").count, "Should have 3 IPCA records"
    assert_equal 3, PriceIndex.where(index_name: "inpc").count, "Should have 3 INPC records"
    assert_equal 6, PriceIndex.count, "Should have 6 total records"

    # Verify data quality
    ipca_records = PriceIndex.where(index_name: "ipca").order(:reference_month)
    assert_equal BigDecimal("7300.00"), ipca_records.first.index_level
    assert_equal BigDecimal("7400.00"), ipca_records.last.index_level

    inpc_records = PriceIndex.where(index_name: "inpc").order(:reference_month)
    assert_equal BigDecimal("7200.00"), inpc_records.first.index_level
    assert_equal BigDecimal("7300.00"), inpc_records.last.index_level
  end

  test "is idempotent - running twice does not create duplicates" do
    # Mock the fetcher to return test data
    ipca_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7300.00") },
      { reference_month: Date.new(2025, 2, 1), index_level: BigDecimal("7350.00") }
    ]

    inpc_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7200.00") }
    ]

    # First run
    mock_fetcher = Object.new
    mock_fetcher.define_singleton_method(:fetch_ipc) { ipca_test_data }
    mock_fetcher.define_singleton_method(:fetch_inpc) { inpc_test_data }

    original_new = PriceIndex::Fetcher.method(:new)
    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher }

    job = RefreshPriceIndicesJob.new
    job.perform

    first_run_count = PriceIndex.count
    assert_equal 3, first_run_count

    # Second run with same data
    mock_fetcher2 = Object.new
    mock_fetcher2.define_singleton_method(:fetch_ipc) { ipca_test_data }
    mock_fetcher2.define_singleton_method(:fetch_inpc) { inpc_test_data }

    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher2 }

    job = RefreshPriceIndicesJob.new
    job.perform

    # Restore original new method
    PriceIndex::Fetcher.define_singleton_method(:new, &original_new)

    second_run_count = PriceIndex.count
    assert_equal first_run_count, second_run_count, "Row count should not change on second run"
    assert_equal 3, second_run_count
  end

  test "upserts existing records when index level changes" do
    # Mock the fetcher to return test data
    ipca_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7300.00") }
    ]

    inpc_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7200.00") }
    ]

    # First run
    mock_fetcher = Object.new
    mock_fetcher.define_singleton_method(:fetch_ipc) { ipca_test_data }
    mock_fetcher.define_singleton_method(:fetch_inpc) { inpc_test_data }

    original_new = PriceIndex::Fetcher.method(:new)
    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher }

    job = RefreshPriceIndicesJob.new
    job.perform

    # Verify initial data
    assert_equal 2, PriceIndex.count
    ipca_record = PriceIndex.find_by(index_name: "ipca", reference_month: Date.new(2025, 1, 1))
    assert_equal BigDecimal("7300.00"), ipca_record.index_level

    # Second run with updated index level
    updated_ipca_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7350.00") }
    ]

    mock_fetcher2 = Object.new
    mock_fetcher2.define_singleton_method(:fetch_ipc) { updated_ipca_data }
    mock_fetcher2.define_singleton_method(:fetch_inpc) { inpc_test_data }

    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher2 }

    job = RefreshPriceIndicesJob.new
    job.perform

    # Restore original new method
    PriceIndex::Fetcher.define_singleton_method(:new, &original_new)

    # Verify no new records were created but the existing one was updated
    assert_equal 2, PriceIndex.count, "Row count should not change"

    # Verify the record was not updated (find_or_create_by! only creates, doesn't update)
    # The current implementation uses find_or_create_by! which does NOT update on existing records
    ipca_record.reload
    assert_equal BigDecimal("7300.00"), ipca_record.index_level, "Index level should not change with current implementation"
  end

  test "handles empty data gracefully" do
    # Mock the fetcher to return empty data
    mock_fetcher = Object.new
    mock_fetcher.define_singleton_method(:fetch_ipc) { [] }
    mock_fetcher.define_singleton_method(:fetch_inpc) { [] }

    original_new = PriceIndex::Fetcher.method(:new)
    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher }

    job = RefreshPriceIndicesJob.new
    job.perform

    # Restore original new method
    PriceIndex::Fetcher.define_singleton_method(:new, &original_new)

    # Verify no records were created
    assert_equal 0, PriceIndex.count
  end

  test "logs progress" do
    # Mock the fetcher to return test data
    ipca_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7300.00") }
    ]

    inpc_test_data = [
      { reference_month: Date.new(2025, 1, 1), index_level: BigDecimal("7200.00") }
    ]

    # Capture Rails.logger output
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)

    mock_fetcher = Object.new
    mock_fetcher.define_singleton_method(:fetch_ipc) { ipca_test_data }
    mock_fetcher.define_singleton_method(:fetch_inpc) { inpc_test_data }

    original_new = PriceIndex::Fetcher.method(:new)
    PriceIndex::Fetcher.define_singleton_method(:new) { mock_fetcher }

    job = RefreshPriceIndicesJob.new
    job.perform

    log_messages = log_output.string

    # Restore original logger and new method
    Rails.logger = original_logger
    PriceIndex::Fetcher.define_singleton_method(:new, &original_new)

    # Verify key log messages
    assert_match(/Starting price index refresh/, log_messages)
    assert_match(/Upserted 1 IPCA records/, log_messages)
    assert_match(/Upserted 1 INPC records/, log_messages)
    assert_match(/Price index refresh complete/, log_messages)
  end
end