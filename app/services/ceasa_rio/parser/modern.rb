module CeasaRio
  class Parser
    class Modern
      PRICE       = /\A\d{1,4},\d{2}\z/
      UNIT_ANCHOR = /\A(Cx|Sc|Unid|Preg|Ama|Mol|Pct|kg|Saco|Caixa)\b/i
      SECTION_RE  = /\A\s*(\d+)\.\s+(.+?)\s*\z/
      DROP_RE     = [ /SECRETARIA DE AGRICULTURA/i, /CENTRAIS DE ABASTECIMENTO/i,
                     /Dia Semana:/i, /PRODUTOS\s+TIPO/i, /VARIAÇÃO/i, /ULTIMOS/i,
                     /12 MESES/i, /Fonte:\s*CEASA/i, /Página:/i, /\AHASTE\z/, /\ATUBÉRCULO E RIZOMA\z/ ]

      def initialize(text)
        @text = text
      end

      def parse
        Bulletin.new(price_date: extract_date, weekday: extract_weekday, rows: parse_rows)
      end

      private

      def extract_date
        m = @text.match(/Dia Semana:\s+\S+\s+(\d{2})\/(\d{2})\/(\d{4})/)
        return Date.new($3.to_i, $2.to_i, $1.to_i) if m

        m = @text.match(/Dia Semana:.*?DATA:\s+(\d{2})\/(\d{2})\/(\d{4})/)
        return Date.new($3.to_i, $2.to_i, $1.to_i) if m

        raise "Could not find price_date in PDF (Dia Semana: line)"
      end

      def extract_weekday
        @text[/Dia Semana:\s+(\S+)/, 1]
      end

      def parse_rows
        section = nil
        rows = []
        @text.each_line do |raw|
          next if DROP_RE.any? { |re| raw =~ re }
          line = raw.strip
          next if line.empty?
          if line =~ SECTION_RE
            section = $1.to_i
            next
          end
          row = parse_line(line, section) or next
          rows << row
        end
        rows
      end

      def parse_line(line, section)
        toks = line.split(/\s+/)
        return nil if toks.size < 3

        prices = []
        while toks.any? && toks.last =~ PRICE && prices.size < 3
          prices.unshift(toks.pop)
        end

        if prices.size == 3
          var_tok = toks.pop || "S/C"
          variation = var_tok
          min, modal, max = prices.map { |p| p.gsub(",", ".").to_f }
        elsif prices.empty? && toks.last == "S/C"
          toks.pop
          variation = nil; min = modal = max = nil
        else
          return nil
        end

        idx = toks.index { |t| t =~ UNIT_ANCHOR || t =~ /\A\d+(,\d+)?kg\z/i }
        name_toks = idx ? toks[0...idx] : toks
        unit      = idx ? toks[idx..].join(" ") : nil

        Row.new(section: section,
                raw_product: name_toks.first.to_s,
                raw_tipo:    (name_toks[1..]&.join(" ").presence),
                raw_unit:    unit,
                variation_12m: variation,
                min: min, modal: modal, max: max,
                price_per_kg: CeasaRio::UnitNormalizer.new.per_kg(unit, modal))
      end
    end
  end
end
