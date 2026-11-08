module CeasaRio
  class Parser
    Bulletin = Struct.new(:price_date, :weekday, :rows, keyword_init: true)
    Row      = Struct.new(:section, :raw_product, :raw_tipo, :raw_unit,
                          :variation_12m, :min, :modal, :max, :price_per_kg, keyword_init: true)

    def initialize(pdf_path)
      @text = IO.popen([ "pdftotext", "-layout", pdf_path.to_s, "-" ], err: "/dev/null", &:read)
    end

    def parse
      bulletin =
        if @text =~ /Dia\s*Semana:/
          Modern.new(@text).parse
        elsif @text =~ /Boletim\s+[n°ºo]/i
          Legacy.new(@text).parse
        else
          raise "Unknown CEASA PDF format (no 'Dia Semana:' or 'Boletim n°' marker found)"
        end
      bulletin.rows.each { |row| self.class.drop_zero_prices!(row) }
      bulletin
    end

    # CEASA sometimes prints "0,00" in a price column (e.g. ENDÍVIA modal 0,00
    # with min 25,00 / max 40,00). Zero is never a real wholesale price: store
    # nil ("no price") so nothing downstream divides by it.
    def self.drop_zero_prices!(row)
      %i[min modal max].each { |k| row[k] = nil if row[k]&.zero? }
      row.price_per_kg = nil if row.modal.nil? || row.price_per_kg&.zero?
      row
    end
  end
end
