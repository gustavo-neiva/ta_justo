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

      begin
        tempfile = Tempfile.new(["ceasa", ".pdf"])
        tempfile.binmode
        tempfile.write(body)
        tempfile.close

        bulletin = CeasaRio::Parser.new(tempfile.path).parse

        # Skip anything before the availability floor (pre-2022 not published)
        if bulletin.price_date < LEGACY_MIN
          Rails.logger.info("Skipping pre-floor bulletin: #{bulletin.price_date} (#{url})")
          next
        end

        archive(body, bulletin.price_date)
        CeasaRio::Loader.new.ingest(body, source_url: url, market: "ceasa-rj")
        Rails.logger.info("Backfilled #{bulletin.price_date}")
      rescue => e
        Rails.logger.error("Failed to process #{url}: #{e.message}")
      ensure
        tempfile&.close!
      end
    end

    Rails.logger.info("Backfill complete")
  end

  private

  def archive(body, date)
    dir = Rails.root.join("storage", "ceasa", "raw")
    FileUtils.mkdir_p(dir)
    path = dir.join("#{date.strftime('%Y-%m-%d')}.pdf")
    File.binwrite(path, body) unless File.exist?(path)
  end
end
