class FairPriceVerdict
  # ⚠️ Bands live on Markup VO (single source of truth). Forwarded here for
  # the explanation strings and for callers that reference them via this class.
  BARATO_MAX  = Markup::BARATO_MAX
  MEDIA_MAX   = Markup::MEDIA_MAX
  STALE_DAYS  = 10

  # Eggs: CEASA sells "Cx 30 dz" — modal is per-box, so per-dozen = modal / 30.
  DOZENS_PER_BOX = 30

  # Synthesis table: fires only on high-signal disagreement cells (plan §3.8).
  # Key: [markup_bucket, timing_bucket]. Silent cells are absent.
  SYNTHESIS = {
    %i[barato expensive] => {
      key:      :barato_epoca_cara,
      sentence: "Bom preço do vendedor, mas o produto está caro pra esta época do ano — pode ficar mais barato."
    },
    %i[media cheap] => {
      key:      :media_epoca_barata,
      sentence: "Preço ok, e o produto está barato agora — bom momento pra comprar."
    },
    %i[media expensive] => {
      key:      :media_epoca_cara,
      sentence: "Margem ok, mas é época cara pra este produto."
    },
    %i[caro cheap] => {
      key:      :caro_epoca_barata,
      sentence: "Vendedor caro num momento em que o produto está barato — considere outros fornecedores."
    }
  }.freeze

  Result = Struct.new(
    :verdict, :ratio,
    :ceasa_comparable, :paid_comparable, :unit_label,
    :percentile_12m, :seasonality_note, :explanation,
    :ceasa_date, :stale,
    :markup, :market_timing, :synthesis_key, :synthesis_sentence,
    keyword_init: true
  )

  # paid_amount: what the user entered — R$/kg for per_kg, R$/dúzia for per_dozen,
  # R$/unidade for per_unit. Unit is determined by @variant.pricing_mode.
  def initialize(variant:, paid_amount:)
    @variant     = variant
    @paid_amount = paid_amount.to_f
  end

  def call
    case @variant.pricing_mode
    when "per_dozen" then call_per_dozen
    when "per_unit"  then call_per_unit
    else                  call_per_kg
    end
  end

  private

  # ── per_kg (produce, fish, garlic, etc.) ─────────────────────────────────────

  def call_per_kg
    latest = representative_latest
    raise "Sem preço CEASA para #{@variant.name}" unless latest

    ceasa      = latest.price_per_kg.to_f
    ceasa_date = latest.bulletin.price_date
    stale      = stale?(ceasa_date)
    ratio      = @paid_amount / ceasa
    pct        = percentile_12m(ceasa, :per_kg)
    markup     = Markup.new(ratio: ratio)
    timing     = compute_market_timing
    synthesis  = synthesize(markup.bucket, timing)

    Result.new(
      verdict: markup.bucket, ratio: ratio,
      ceasa_comparable: ceasa, paid_comparable: @paid_amount,
      unit_label: "kg",
      percentile_12m: pct, seasonality_note: SeasonalityCalculator.new(@variant).note,
      explanation: explanation_per_kg(ratio, ceasa, pct),
      ceasa_date: ceasa_date, stale: stale,
      markup: markup, market_timing: timing,
      synthesis_key: synthesis&.dig(:key),
      synthesis_sentence: synthesis&.dig(:sentence)
    )
  end

  # ── per_dozen (eggs) ──────────────────────────────────────────────────────────

  def call_per_dozen
    latest = representative_latest
    raise "Sem preço CEASA (por dúzia) para #{@variant.name}" unless latest

    ceasa_per_dozen = latest.modal.to_f / DOZENS_PER_BOX
    ceasa_date      = latest.bulletin.price_date
    stale           = stale?(ceasa_date)
    ratio           = @paid_amount / ceasa_per_dozen
    pct             = percentile_12m(ceasa_per_dozen, :per_dozen)
    markup          = Markup.new(ratio: ratio)
    timing          = compute_market_timing
    synthesis       = synthesize(markup.bucket, timing)

    Result.new(
      verdict: markup.bucket, ratio: ratio,
      ceasa_comparable: ceasa_per_dozen.round(2), paid_comparable: @paid_amount,
      unit_label: "dúzia",
      percentile_12m: pct, seasonality_note: SeasonalityCalculator.new(@variant).note,
      explanation: explanation_per_dozen(ratio, ceasa_per_dozen, pct),
      ceasa_date: ceasa_date, stale: stale,
      markup: markup, market_timing: timing,
      synthesis_key: synthesis&.dig(:key),
      synthesis_sentence: synthesis&.dig(:sentence)
    )
  end

  # ── per_unit (abacaxi, melancia, alface, etc.) ────────────────────────────────

  def call_per_unit
    raise "Variante #{@variant.name} sem avg_weight_kg — não pode gerar veredicto" unless @variant.avg_weight_kg&.positive?

    latest = representative_latest
    raise "Sem preço CEASA (por kg) para #{@variant.name}" unless latest

    ceasa_per_unit = latest.price_per_kg.to_f * @variant.avg_weight_kg.to_f
    ceasa_date     = latest.bulletin.price_date
    stale          = stale?(ceasa_date)
    ratio          = @paid_amount / ceasa_per_unit
    pct            = percentile_12m(ceasa_per_unit, :per_unit)
    markup         = Markup.new(ratio: ratio)
    timing         = compute_market_timing
    synthesis      = synthesize(markup.bucket, timing)

    Result.new(
      verdict: markup.bucket, ratio: ratio,
      ceasa_comparable: ceasa_per_unit.round(2), paid_comparable: @paid_amount,
      unit_label: "unidade",
      percentile_12m: pct, seasonality_note: SeasonalityCalculator.new(@variant).note,
      explanation: explanation_per_unit(ratio, ceasa_per_unit, pct),
      ceasa_date: ceasa_date, stale: stale,
      markup: markup, market_timing: timing,
      synthesis_key: synthesis&.dig(:key),
      synthesis_sentence: synthesis&.dig(:sentence)
    )
  end

  # ── shared helpers ────────────────────────────────────────────────────────────

  # Percentile of `current` within the trailing-12m representative series.
  # Ranks the CEASA series — strictly paid-independent (Plan §3.1 bug fix).
  # Nominal here; the deflated MarketTiming percentile is a separate axis (Phase 3).
  def percentile_12m(current, mode)
    series = comparable_series(mode)
    return nil if series.size < 10
    below = series.count { |p| p < current }
    (below.to_f / series.size * 100).round
  end

  def comparable_series(mode)
    @variant.representative_series(months: 12).map do |price|
      case mode
      when :per_kg    then price.price_per_kg.to_f
      when :per_dozen then price.modal.to_f / DOZENS_PER_BOX
      when :per_unit  then price.price_per_kg.to_f * @variant.avg_weight_kg.to_f
      end
    end
  end

  def representative_latest
    @variant.representative_price(bulletin: latest_representative_bulletin)
  end

  def latest_representative_bulletin
    @variant.latest_price&.bulletin
  end

  def compute_market_timing
    MarketTiming.new(variant: @variant).compute
  end

  # Returns the synthesis hash or nil (silence).
  def synthesize(markup_bucket, timing)
    return nil if timing.nil? || timing.null?
    SYNTHESIS[[ markup_bucket, timing.bucket ]]
  end

  def stale?(ceasa_date)
    (Date.current - ceasa_date).to_i > STALE_DAYS
  end

  def explanation_per_kg(ratio, ceasa, pct)
    "Você paga R$ #{"%.2f" % @paid_amount}/kg = #{"%.1f" % ratio}× o atacado CEASA " \
    "(R$ #{"%.2f" % ceasa}/kg). Margem típica de feira: #{BARATO_MAX}–#{MEDIA_MAX}×." \
    "#{" Hoje está no #{pct}º percentil dos últimos 12 meses." if pct}"
  end

  def explanation_per_dozen(ratio, ceasa_dz, pct)
    "Você paga R$ #{"%.2f" % @paid_amount}/dúzia = #{"%.1f" % ratio}× o atacado CEASA " \
    "(R$ #{"%.2f" % ceasa_dz}/dúzia). Margem típica de feira: #{BARATO_MAX}–#{MEDIA_MAX}×." \
    "#{" Hoje está no #{pct}º percentil dos últimos 12 meses." if pct}"
  end

  def explanation_per_unit(ratio, ceasa_unit, pct)
    weight_g = (@variant.avg_weight_kg.to_f * 1000).round
    "Você paga R$ #{"%.2f" % @paid_amount}/unidade = #{"%.1f" % ratio}× o atacado CEASA " \
    "(R$ #{"%.2f" % ceasa_unit}/unidade, ~#{weight_g}g estimado). " \
    "Margem típica de feira: #{BARATO_MAX}–#{MEDIA_MAX}×." \
    "#{" Hoje está no #{pct}º percentil dos últimos 12 meses." if pct}"
  end
end
