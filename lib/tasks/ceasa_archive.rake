# Local PDF archive (storage/ceasa/raw) management for CEASA bulletins.
# The archive is the source of truth for retracing any ingested price.

namespace :ceasa do
  desc "Heal storage/ceasa/raw: re-fetch source_url for bulletins missing a PDF"
  task backfill_archive: :environment do
    CeasaArchiveBackfillJob.perform_now
  end

  desc "Show archive coverage: bulletins in DB vs PDFs on disk"
  task archive_status: :environment do
    total = Bulletin.where(market: "ceasa-rj").count
    archived = 0
    missing = []
    Bulletin.where(market: "ceasa-rj").order(:price_date).find_each do |b|
      if CeasaRio::Archiver.archived?(b.price_date)
        archived += 1
      else
        missing << b.price_date
      end
    end

    puts "Bulletins in DB : #{total}"
    puts "PDFs archived   : #{archived} (#{total.zero? ? 0 : (archived * 100.0 / total).round(1)}%)"
    puts "Missing PDFs    : #{missing.size}"
    if missing.any?
      puts ""
      puts "First 30 missing dates: #{missing.first(30).join(', ')}"
    end
  end
end
