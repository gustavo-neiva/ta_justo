# ChecksController — o verificador (página principal)
# GET /                                   → busca + grade da banca
# GET /?item=alface                       → abre o cartão do item
# GET /?product=tomate&variant=1&price=8,50 → veredito (mesmo motor de sempre)
class ChecksController < ApplicationController
  def show
    @items = CheckerCatalog.items
    @refs = CheckerReference.all
    @open_item = CheckerCatalog.find(params[:item])

    run_verdict if params[:product].present? && params[:price].present?
    @open_item ||= CheckerCatalog.for_variant(@variant) if @variant
  end

  private

  def run_verdict
    @product = Product.find_by(slug: params[:product])

    unless @product
      @error = "Produto não encontrado"
      return
    end

    @variant = resolve_variant(@product)

    unless @variant
      @error = params[:variant].present? ? "Variante não encontrada" : "Produto sem variante padrão configurada"
      return
    end

    # Signs are written "4,99"; Ruby's to_f would read that as 4.0.
    @paid_amount = params[:price].to_s.strip.tr(",", ".").to_f

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

  def resolve_variant(product)
    if params[:variant].present?
      product.variants.find_by(id: params[:variant])
    else
      product.default_variant
    end
  end
end
