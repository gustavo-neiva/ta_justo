# ProductsController — Product detail page (minimal v1, no charts)
# GET /produtos/:id
class ProductsController < ApplicationController
  def show
    @product = Product.find_by!(slug: params[:id])
    @variant = @product.default_variant

    unless @variant
      redirect_to root_path, alert: "Produto sem variante configurada"
      return
    end

    # Latest price for the variant
    @latest_price = @variant.prices
                            .joins(:bulletin)
                            .order('bulletins.price_date DESC')
                            .first

    unless @latest_price
      @error = "Nenhum preço encontrado para #{@product.name}"
      return
    end

    @price_date = @latest_price.bulletin.price_date
    @stale = (Date.current - @price_date).to_i > FairPriceVerdict::STALE_DAYS

    # Stats (simple queries, no chart data in v1)
    recent_prices = @variant.prices
                            .where.not(price_per_kg: nil)
                            .joins(:bulletin)
                            .where('bulletins.price_date >= ?', 12.months.ago)

    @stats = {
      latest: @latest_price.price_per_kg&.round(2),
      min_12m: recent_prices.minimum(:price_per_kg)&.round(2),
      max_12m: recent_prices.maximum(:price_per_kg)&.round(2),
      avg_12m: recent_prices.average(:price_per_kg)&.to_f&.round(2)
    }

    # All variants for this product (for variant selector)
    @variants = @product.variants.order(:name)

    # Inline verdict calculator (optional user input)
    if params[:check_price].present?
      @check_price = params[:check_price].to_f
      if @check_price > 0
        verdict_service = FairPriceVerdict.new(variant: @variant, paid_per_kg: @check_price)
        @verdict = verdict_service.call
      end
    end
  end
end
