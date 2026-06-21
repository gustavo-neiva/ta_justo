class BackfillCeasaRioJob < ApplicationJob
  queue_as :default
  MODERN_MIN = Date.new(2023, 3, 1)

  def perform
    urls = CeasaRio::Crawler.new.discover_urls
    Rails.logger.info("Discovered #{urls.size} URLs")
    
    urls.each do |url|
      next if Bulletin.exists?(source_url: url)
      
      sleep 0.8  # polite crawling
      
      body = CeasaRio::Fetcher.new.fetch_and_validate(url)
      next unless body
      
      # Archive and ingest
      begin
        tempfile = Tempfile.new(['ceasa', '.pdf'])
        tempfile.binmode
        tempfile.write(body)
        tempfile.close
        
        bulletin = CeasaRio::Parser.new(tempfile.path).parse
        
        # Skip if before Modern era
        if bulletin.price_date < MODERN_MIN
          Rails.logger.info("Skipping Legacy bulletin: #{bulletin.price_date}")
          next
        end
        
        # Archive
        archive(body, bulletin.price_date)
        
        # Ingest
        CeasaRio::Loader.new.ingest(body, source_url: url, market: "ceasa-rj")
        Rails.logger.info("Backfilled #{bulletin.price_date}")
      rescue => e
        Rails.logger.error("Failed to process #{url}: #{e.message}")
      ensure
        tempfile.close! if tempfile
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
