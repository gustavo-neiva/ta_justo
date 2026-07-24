class RefreshPriceIndicesJob < ApplicationJob
  queue_as :default

  def perform
    fetcher = PriceIndex::Fetcher.new

    Rails.logger.info("Starting price index refresh...")

    # Fetch and upsert IPCA series
    ipca_data = fetcher.fetch_ipc
    upsert_series("ipca", ipca_data)
    Rails.logger.info("Upserted #{ipca_data.length} IPCA records")

    # Fetch and upsert INPC series
    inpc_data = fetcher.fetch_inpc
    upsert_series("inpc", inpc_data)
    Rails.logger.info("Upserted #{inpc_data.length} INPC records")

    Rails.logger.info("Price index refresh complete")
  end

  private

  # Idempotent upsert of a single index series
  #
  # @param index_name [String] "ipca" or "inpc"
  # @param data [Array<Hash>] Array of {reference_month: Date, index_level: BigDecimal}
  def upsert_series(index_name, data)
    data.each do |entry|
      PriceIndex.find_or_create_by!(
        index_name: index_name,
        reference_month: entry[:reference_month]
      ) do |record|
        record.index_level = entry[:index_level]
      end
    end
  end
end
