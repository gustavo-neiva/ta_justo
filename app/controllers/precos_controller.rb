# PrecosController — Today's CEASA index page
# GET /precos
class PrecosController < ApplicationController
  def index
    @latest_bulletin = Bulletin.where(market: "ceasa-rj")
                               .order(price_date: :desc)
                               .first

    unless @latest_bulletin
      @error = "Nenhum boletim CEASA encontrado. Execute o job de fetch ou backfill primeiro."
      return
    end

    @price_date = @latest_bulletin.price_date
    @weekday = @latest_bulletin.weekday
    @stale = (Date.current - @price_date).to_i > FairPriceVerdict::STALE_DAYS

    # Group prices by section (1-6 for produce, skip 7-fish for v1 default view)
    @sections = {}
    
    (1..6).each do |section_num|
      section_prices = @latest_bulletin.prices
                                       .where(section: section_num)
                                       .joins(:variant)
                                       .includes(variant: :product)
                                       .where(products: { fair_relevant: true })
                                       .order('products.name ASC')
      
      next if section_prices.empty?
      
      @sections[section_num] = {
        name: section_name(section_num),
        prices: section_prices
      }
    end
  end

  private

  def section_name(num)
    {
      1 => "Frutas Nacionais",
      2 => "Frutas Importadas",
      3 => "Hortaliças Fruto",
      4 => "Hortaliças Folha/Flor",
      5 => "Hortaliças Raiz/Bulbo",
      6 => "Ovos"
    }[num] || "Seção #{num}"
  end
end
