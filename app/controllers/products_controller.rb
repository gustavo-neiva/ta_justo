# ProductsController — Product detail page with historical chart
# GET /produtos/:id
# GET /produtos/:id?variant=123&period=365&check_price=8.50
class ProductsController < ApplicationController
  VALID_PERIODS = %w[90 365 all].freeze
  DEFAULT_PERIOD = "365"

  def show
    @product = Product.find_by!(slug: params[:id])

    # Variant selection: honor ?variant=ID, else default_variant
    @variant =
      if params[:variant].present?
        @product.variants.find_by(id: params[:variant]) || @product.default_variant
      else
        @product.default_variant
      end

    unless @variant
      redirect_to root_path, alert: "Produto sem variante configurada"
      return
    end

    @period = VALID_PERIODS.include?(params[:period]) ? params[:period] : DEFAULT_PERIOD
    @unit_label = unit_label_for(@variant)

    # Single source of truth (Plan §3.1): the row shown here is the same
    # representative row the verdict and stats compute against.
    @latest_price = @variant.latest_price

    unless @latest_price
      @error = "Nenhum preço encontrado para #{@product.name}"
      @variants = @product.variants.order(:name)
      return
    end

    @price_date = @latest_price.bulletin.price_date
    @stale = (Date.current - @price_date).to_i > FairPriceVerdict::STALE_DAYS

    @stats = build_stats(@variant)
    @variants = @product.variants.order(:name)

    # Chart series (Phase 2 fills these helpers in)
    @chart_data    = ChartSeries.new(@variant, period: @period).points
    @seasonal_data = SeasonalityCalculator.new(@variant).monthly_curve

    # Two-axis plan: MarketTiming (paid-independent — always shown on detail page)
    @market_timing = MarketTiming.new(variant: @variant).compute

    # Raw wholesale data for the transparent source section (plan §3.7)
    @raw_prices = @variant.prices
                          .where(bulletin: @latest_price.bulletin)
                          .order(:id)
                          .to_a
    @representative_price_id = @latest_price.id

    run_inline_verdict
  end

  private

  def unit_label_for(variant)
    case variant.pricing_mode
    when "per_dozen" then "dúzia"
    when "per_unit"  then "unidade"
    else                  "kg"
    end
  end

  def build_stats(variant)
    # Representative series over 12m — same selection rule as the verdict.
    series = variant.representative_series(months: 12).map do |price|
      comparable_for(variant, price)
    end.reject(&:nil?)

    {
      latest:  @latest_price.present? ? comparable_for(variant, @latest_price)&.round(2) : nil,
      min_12m: series.min&.round(2),
      max_12m: series.max&.round(2),
      avg_12m: (series.any? ? (series.sum / series.size).round(2) : nil)
    }
  end

  # Comparable value for a variant's pricing mode (kg / dúzia / unidade).
  def comparable_for(variant, price)
    case variant.pricing_mode
    when "per_dozen" then price.modal.to_f / 30
    when "per_unit"  then price.price_per_kg.to_f * variant.avg_weight_kg.to_f if variant.avg_weight_kg&.positive?
    else                  price.price_per_kg.to_f
    end
  end

  def run_inline_verdict
    return if params[:check_price].blank?

    paid = params[:check_price].to_f
    return unless paid.positive?

    @check_price = paid
    @verdict = FairPriceVerdict.new(variant: @variant, paid_amount: paid).call

    if ENV["POSTHOG_PROJECT_TOKEN"].present? && ENV["POSTHOG_HOST"].present?
      PostHog.capture(
        event: "product_price_check_completed",
        properties: {
          product_slug: @product.slug,
          pricing_mode: @variant.pricing_mode,
          selected_period: @period,
          verdict: @verdict.verdict.to_s
        }
      )
    end
  rescue => e
    @verdict_error = e.message
  end
end
