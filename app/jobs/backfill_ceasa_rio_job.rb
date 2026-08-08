class BackfillCeasaRioJob < ApplicationJob
  queue_as :default
  LEGACY_MIN = Date.new(2022, 1, 1)  # 2022-01 is the hard floor (pre-2022 not published)

  def perform(since: nil)
    # since: nil → crawler defaults to (latest archived PDF − 7 days); an explicit Date pins the window.
    puts "Starting crawler..."
    urls = CeasaRio::Crawler.new.discover_urls(since: since)
    puts "Discovered #{urls.size} URLs"
    Rails.logger.info("Discovered #{urls.size} URLs")

    new_urls = urls.reject { |url| Bulletin.exists?(source_url: url) }
    puts "#{new_urls.size} new PDFs to download (#{urls.size - new_urls.size} already exist)"

    new_urls.each_with_index do |url, i|
      puts "[#{i + 1}/#{new_urls.size}] Fetching #{url}..."
      sleep 0.8  # polite crawling

      body = CeasaRio::Fetcher.new.fetch_and_validate(url)
      unless body
        puts "  ⚠️  Failed to fetch"
        next
      end

      process_url(url, body)
    end

    puts "✓ Backfill complete"
    Rails.logger.info("Backfill complete")
  rescue Interrupt
    puts "\n\n✗ Interrupted by user"
    raise
  end

  private

  def process_url(url, body)
    # Block form auto-unlinks the tempfile even on exception — no leak.
    bulletin = Tempfile.create([ "ceasa", ".pdf" ]) do |tmp|
      tmp.binmode
      tmp.write(body)
      tmp.close
      CeasaRio::Parser.new(tmp.path).parse
    end

    # Skip anything before the availability floor (pre-2022 not published)
    if bulletin.price_date < LEGACY_MIN
      puts "  Skipped (pre-2022): #{bulletin.price_date}"
      Rails.logger.info("Skipping pre-floor bulletin: #{bulletin.price_date} (#{url})")
      return
    end

    # Archive FIRST, then ingest from disk — source PDF always on hand.
    path = CeasaRio::Archiver.write(body, bulletin.price_date)
    CeasaRio::Loader.new.ingest_path(path, source_url: url, market: "ceasa-rj")
    puts "  ✓ Saved #{bulletin.price_date}"
    Rails.logger.info("Backfilled #{bulletin.price_date}")
  rescue => e
    puts "  ✗ Error: #{e.message}"
    Rails.logger.error("Failed to process #{url}: #{e.message}")
  end
end
