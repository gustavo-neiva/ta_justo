# Price Indices Seed — Full historical data for IPCA and INPC
# This seeds the complete historical series from BCB SGS API (~1100 rows total)
# Run as part of db:seed or standalone with: rails runner db/seeds/price_indices.rb

puts "📊 Seeding price indices (IPCA + INPC) from BCB SGS API..."

begin
  fetcher = PriceIndex::Fetcher.new

  # Fetch and upsert IPCA series
  puts "  Fetching IPCA series (#{PriceIndex::Fetcher::IPCA_SERIES})..."
  ipca_data = fetcher.fetch_ipc
  puts "  Retrieved #{ipca_data.length} IPCA records"

  ipca_data.each do |entry|
    PriceIndex.find_or_create_by!(
      index_name: "ipca",
      reference_month: entry[:reference_month]
    ) do |record|
      record.index_level = entry[:index_level]
    end
  end
  puts "  ✅ Upserted #{ipca_data.length} IPCA records"

  # Fetch and upsert INPC series
  puts "  Fetching INPC series (#{PriceIndex::Fetcher::INPC_SERIES})..."
  inpc_data = fetcher.fetch_inpc
  puts "  Retrieved #{inpc_data.length} INPC records"

  inpc_data.each do |entry|
    PriceIndex.find_or_create_by!(
      index_name: "inpc",
      reference_month: entry[:reference_month]
    ) do |record|
      record.index_level = entry[:index_level]
    end
  end
  puts "  ✅ Upserted #{inpc_data.length} INPC records"

  total_records = PriceIndex.count
  ipca_count = PriceIndex.where(index_name: "ipca").count
  inpc_count = PriceIndex.where(index_name: "inpc").count

  puts "\n✅ Price indices seeded successfully!"
  puts "   Total records: #{total_records}"
  puts "   IPCA records: #{ipca_count}"
  puts "   INPC records: #{inpc_count}"
rescue PriceIndex::Fetcher::APIError => e
  puts "❌ Failed to fetch price indices: #{e.message}"
  puts "   This is expected if the BCB API is unavailable."
  puts "   Price indices will be seeded later by the job or manual re-run."
rescue => e
  puts "❌ Unexpected error seeding price indices: #{e.message}"
  puts "  #{e.backtrace.first(5).join("\n")}"
end
