class BackfillCeasaRioJob < ApplicationJob
  queue_as :default
  LEGACY_MIN = Date.new(2022, 1, 1)  # 2022-01 is the hard floor (pre-2022 not published)

  def perform
    urls = CeasaRio::Crawler.new.discover_urls
    Rails.logger.info("Discovered #{urls.size} URLs")

    urls.each do |url|
      next if Bulletin.exists?(source_url: url)

      sleep 0.8  # polite crawling

      body = CeasaRio::Fetcher.new.fetch_and_validate(url)
      next unless body

      process_url(url, body)
    end

    Rails.logger.info("Backfill complete")
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
      Rails.logger.info("Skipping pre-floor bulletin: #{bulletin.price_date} (#{url})")
      return
    end

    # Archive FIRST, then ingest from disk — source PDF always on hand.
    path = CeasaRio::Archiver.write(body, bulletin.price_date)
    CeasaRio::Loader.new.ingest_path(path, source_url: url, market: "ceasa-rj")
    Rails.logger.info("Backfilled #{bulletin.price_date}")
  rescue => e
    Rails.logger.error("Failed to process #{url}: #{e.message}")
  end
end
