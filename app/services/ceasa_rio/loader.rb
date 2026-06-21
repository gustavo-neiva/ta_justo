module CeasaRio
  class Loader
    def initialize(matcher: VariantMatcher.new)
      @matcher = matcher
    end

    def ingest(pdf_bytes, source_url:, market: "ceasa-rj")
      path = write_temp(pdf_bytes)
      bulletin = CeasaRio::Parser.new(path).parse
      
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
    ensure
      File.delete(path) if path && File.exist?(path)
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
      require 'tempfile'
      temp = Tempfile.new(['ceasa', '.pdf'])
      temp.binmode
      temp.write(pdf_bytes)
      temp.close
      temp.path
    end
  end
end
