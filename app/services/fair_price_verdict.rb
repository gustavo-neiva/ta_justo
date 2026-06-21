class FairPriceVerdict
  # ⚠️ PROVISIONAL bands — a GUESS, not yet validated against real feira data (§3.2).
  # Markup of retail (feira) over CEASA atacado. Tunable.
  BARATO_MAX  = 1.7   # < 1.7× atacado → Barato
  MEDIA_MAX   = 2.5   # 1.7–2.5× → Na média  ; > 2.5× → Caro
  STALE_DAYS  = 10    # Days before showing "desatualizado" badge

  Result = Struct.new(
    :verdict, :ratio, :ceasa_per_kg, :paid_per_kg,
    :percentile_12m, :seasonality_note, :explanation,
    :ceasa_date, :stale,
    keyword_init: true
  )

  def initialize(variant:, paid_per_kg:)
    @variant       = variant
    @paid_per_kg   = paid_per_kg.to_f
  end

  def call
    latest = @variant.prices.where.not(price_per_kg: nil)
                     .joins(:bulletin).order('bulletins.price_date DESC').first
    raise "Sem preço CEASA para #{@variant.name}" unless latest

    ceasa = latest.price_per_kg.to_f
    ceasa_date = latest.bulletin.price_date
    stale = (Date.current - ceasa_date).to_i > STALE_DAYS
    
    ratio = @paid_per_kg / ceasa
    pct   = percentile_12m(latest.price_per_kg)
    verdict = ratio < BARATO_MAX ? :barato : (ratio <= MEDIA_MAX ? :media : :caro)

    Result.new(
      verdict: verdict,
      ratio: ratio,
      ceasa_per_kg: ceasa,
      paid_per_kg: @paid_per_kg,
      percentile_12m: pct,
      seasonality_note: seasonality_note,
      explanation: build_explanation(ratio, ceasa, pct, verdict),
      ceasa_date: ceasa_date,
      stale: stale
    )
  end

  private

  def percentile_12m(current_per_kg)
    series = @variant.prices.where.not(price_per_kg: nil)
                    .joins(:bulletin).where('bulletins.price_date >= ?', 12.months.ago)
                    .pluck(:price_per_kg).map(&:to_f)
    return nil if series.size < 10
    below = series.count { |p| p < current_per_kg.to_f }
    (below.to_f / series.size * 100).round
  end

  def seasonality_note
    nil   # v1.1: derive from heatmap month-averages
  end

  def build_explanation(ratio, ceasa, pct, verdict)
    "Você paga R$ #{'%.2f' % @paid_per_kg}/kg = #{'%.1f' % ratio}× o atacado CEASA " \
    "(R$ #{'%.2f' % ceasa}/kg). Margem típica de feira: #{BARATO_MAX}–#{MEDIA_MAX}×." \
    "#{" Hoje está no #{pct}º percentil dos últimos 12 meses." if pct}"
  end
end
