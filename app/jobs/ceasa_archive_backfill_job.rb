class CeasaArchiveBackfillJob < ApplicationJob
  queue_as :default

  # Heals the local PDF archive for bulletins whose source PDF never landed on
  # disk (e.g. ingested before archival existed, or a crash leaked the temp).
  # Re-fetches each bulletin's stored source_url — those are real crawled
  # hrefs (never constructed), so they're safe to re-request.
  BATCH_PAUSE = 0.8 # seconds; polite to the CEASA server

  def perform
    fetcher = CeasaRio::Fetcher.new
    archived = 0
    failed = 0
    checked = 0

    Bulletin.where(market: "ceasa-rj").order(:price_date).find_each do |bulletin|
      checked += 1
      next if CeasaRio::Archiver.archived?(bulletin.price_date)

      sleep BATCH_PAUSE
      body = fetcher.fetch_and_validate(bulletin.source_url)
      if body
        CeasaRio::Archiver.write(body, bulletin.price_date)
        archived += 1
        Rails.logger.info("Archived #{bulletin.price_date}")
      else
        failed += 1
        Rails.logger.warn("Archive backfill: could not re-fetch #{bulletin.price_date} (#{bulletin.source_url})")
      end
    end

    Rails.logger.info("Archive backfill complete: checked #{checked}, +#{archived} archived, #{failed} failed")
  end
end
