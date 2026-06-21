# ChecksController — The hero checker page
# GET / (root)
# GET /?product=tomate&price=18.50
class ChecksController < ApplicationController
  def show
    load_core_basket_products
    
    if params[:product].present? && params[:price].present?
      run_verdict
    end
  end

  private

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

    @paid_per_kg = params[:price].to_f
    
    if @paid_per_kg <= 0
      @error = "Preço inválido"
      return
    end

    begin
      verdict_service = FairPriceVerdict.new(variant: @variant, paid_per_kg: @paid_per_kg)
      @result = verdict_service.call
    rescue => e
      @error = e.message
    end
  end
end
