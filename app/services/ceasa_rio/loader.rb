module CeasaRio
  class Loader
    def initialize(matcher: VariantMatcher.new)
      @matcher = matcher
    end

    # Parse + persist from an ALREADY-ARCHIVED file path. This is the primary
    # entrypoint from jobs: the PDF is on disk first, then ingested — so a
    # Bulletin can never exist without its source PDF. Re-parsing from the
    # archive also validates the archived bytes are intact.
    def ingest_path(path, source_url:, market: "ceasa-rj")
      bulletin = CeasaRio::Parser.new(path).parse
      persist!(bulletin, source_url: source_url, market: market)
    end

    # Legacy convenience: ingest from raw bytes (writes + cleans a temp).
    # Prefer #ingest_path from jobs — archive first, then ingest from disk.
    def ingest(pdf_bytes, source_url:, market: "ceasa-rj")
      path = write_temp(pdf_bytes)
      ingest_path(path, source_url:, market:)
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    private

    def persist!(bulletin, source_url:, market:)
      # Idempotent - skip if already ingested
      return if Bulletin.exists?(market: market, price_date: bulletin.price_date)

      ActiveRecord::Base.transaction do
        b = Bulletin.create!(
          market: market,
          price_date: bulletin.price_date,
          weekday: bulletin.weekday,
          source_url: source_url
        )

        bulletin.rows.each do |row|
          variant = @matcher.match(row, market: market)

          unless variant
            record_pending(row, market: market, date: bulletin.price_date)
            next
          end

          # Skip if this exact variant+packaging already exists for this bulletin
          # (protects against PDF parsing duplicates while preserving different pack sizes)
          next if Price.exists?(bulletin: b, variant: variant, raw_unit: row.raw_unit)

          unit_normalizer = CeasaRio::UnitNormalizer.new

          Price.create!(
            bulletin: b,
            variant: variant,
            section: row.section,
            raw_product: row.raw_product,
            raw_tipo: row.raw_tipo,
            raw_unit: row.raw_unit,
            original_unit: unit_normalizer.family(row.raw_unit),
            original_value: row.modal,
            converted: !row.price_per_kg.nil?,
            variation_12m: row.variation_12m,
            min: row.min,
            modal: row.modal,
            max: row.max,
            price_per_kg: row.price_per_kg
          )
        end
      end
    end

    private

    # CRITICAL safety net: every unmapped row is captured, never lost.
    def record_pending(row, market:, date:)
      pm = PendingMatch.find_or_initialize_by(
        market: market,
        section: row.section,
        raw_product: row.raw_product,
        raw_tipo: row.raw_tipo.to_s
      )
      pm.raw_unit ||= row.raw_unit
      pm.first_seen ||= date
      pm.occurrence_count = (pm.occurrence_count || 0) + 1
      pm.save!
    end

    def write_temp(pdf_bytes)
      require "tempfile"
      temp = Tempfile.new([ "ceasa", ".pdf" ])
      temp.binmode
      temp.write(pdf_bytes)
      temp.close
      temp.path
    end
  end
end
