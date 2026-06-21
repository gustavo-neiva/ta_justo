class FetchCeasaRioJob < ApplicationJob
  queue_as :default

  def perform
    result = CeasaRio::Fetcher.new.latest
    return unless result
    
    date, body = result
    return if Bulletin.exists?(price_date: date, market: "ceasa-rj")
    
    archive(body, date)
    url = CeasaRio::Fetcher.new.url_for(date)
    CeasaRio::Loader.new.ingest(body, source_url: url, market: "ceasa-rj")
    
    Rails.logger.info("Successfully fetched and ingested CEASA-RJ bulletin for #{date}")
  rescue => e
    Rails.logger.error("CEASA fetch failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  private

  def archive(body, date)
    dir = Rails.root.join("storage", "ceasa", "raw")
    FileUtils.mkdir_p(dir)
    path = dir.join("#{date.strftime('%Y-%m-%d')}.pdf")
    File.binwrite(path, body)
  end
end
