module CeasaRio
  class Parser
    Bulletin = Struct.new(:price_date, :weekday, :rows, keyword_init: true)
    Row      = Struct.new(:section, :raw_product, :raw_tipo, :raw_unit,
                          :variation_12m, :min, :modal, :max, :price_per_kg, keyword_init: true)

    def initialize(pdf_path)
      @text = `pdftotext -layout "#{pdf_path}" -`
    end

    def parse
      if @text =~ /Dia\s*Semana:/
        Modern.new(@text).parse
      elsif @text =~ /Boletim\s+[n°ºo]/i
        Legacy.new(@text).parse
      else
        raise "Unknown CEASA PDF format (no 'Dia Semana:' or 'Boletim n°' marker found)"
      end
    end
  end
end
