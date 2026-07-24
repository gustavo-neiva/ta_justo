class FetchCeasaRioJob < ApplicationJob
  queue_as :default

  def perform
    result = CeasaRio::Fetcher.new.latest
    return unless result

    date, body = result
    return if Bulletin.exists?(price_date: date, market: "ceasa-rj")

    # Archive FIRST, then ingest from disk — a Bulletin can never exist
    # without its source PDF available for retracing.
    path = CeasaRio::Archiver.write(body, date)
    url = CeasaRio::Fetcher.new.url_for(date)
    CeasaRio::Loader.new.ingest_path(path, source_url: url, market: "ceasa-rj")

    Rails.logger.info("Successfully fetched and ingested CEASA-RJ bulletin for #{date}")
  rescue => e
    Rails.logger.error("CEASA fetch failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end
