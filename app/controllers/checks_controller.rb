# ChecksController — The hero checker page
# GET / (root)
# GET /?product=tomate&price=18.50
class ChecksController < ApplicationController
  def show
    load_core_basket_products
    load_unit_label_for_selected_product

    if params[:product].present? && params[:price].present?
      run_verdict
    end
  end

  private

  def load_unit_label_for_selected_product
    return unless params[:product].present?
    product = Product.find_by(slug: params[:product])
    return unless product&.default_variant
    @unit_label = unit_label_for(product.default_variant)
  end

  def unit_label_for(variant)
    case variant.pricing_mode
    when "per_dozen" then "dúzia"
    when "per_unit"  then "unidade"
    else                  "kg"
    end
  end

  def load_core_basket_products
    # Load the checkable products for the dropdown
    require Rails.root.join('db/seeds/core_basket.rb')
    @core_products = CoreBasket.checkable_list
  end

  def run_verdict
    @product = Product.find_by(slug: params[:product])
    
    unless @product
      @error = "Produto não encontrado"
      return
    end

    @variant = @product.default_variant
    
    unless @variant
      @error = "Produto sem variante padrão configurada"
      return
    end

    @unit_label = unit_label_for(@variant)
    @paid_amount = params[:price].to_f

    if @paid_amount <= 0
      @error = "Preço inválido"
      return
    end

    begin
      verdict_service = FairPriceVerdict.new(variant: @variant, paid_amount: @paid_amount)
      @result = verdict_service.call
    rescue => e
      @error = e.message
    end
  end
end
