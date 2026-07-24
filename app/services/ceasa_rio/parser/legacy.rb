module CeasaRio
  class Parser
    class Legacy
      PRICE = /\A\d{1,4},\d{2}\z/

      # Section banner starters (checked BEFORE drop patterns, case/accent-insensitive prefix match)
      SECTION_STARTERS = [
        [ /\Afolhas[,\s]/i,                       4 ],
        [ /\Afrutos\b/i,                           3 ],
        [ /\Ara[ií]zes[,\s]/i,                    5 ],
        [ /\Afrutas nacionais\b/i,                 1 ],
        [ /\Afrutas importadas\b/i,                2 ],
        [ /\Apescados\b/i,                         7 ],
        [ /\Aflores e plantas ornamentais\b/i,     nil ],
        [ /\Aoutros g[eê]neros/i,                 nil ],
        [ /\Aoutros\b/i,                           nil ]
      ].freeze

      DROP_RE = [
        /Secretaria de Estado/i,
        /Centrais de Abastecimento/i,
        /PESQUISA DE PREÇOS/i,
        /FONTE:\s*DITEC/i,
        /\AFolha\s+\d+\z/i,
        /Boletim\s+[n°ºo]/i,
        /\A\d{2}\/\d{2}\/\d{4}\s*\z/,
        /Produto\s*[–-]\s*[C1]lasse/i,
        /Produto\s+Embalagem/i,
        /Produto\s+Emb\b/i,
        /Mínima?\s+Mais Comum/i,
        /Mínimo\.\s+Mais Comum/i,
        /Cotação\s*\(\s*R\$/i,
        /\ARizomas\z/i,
        /\A20\s+Kg\)\z/i,               # paren continuation: "20 Kg)"
        /\A25Kg\)\z/i,                   # paren continuation: "25Kg)"
        /\A\d+\z/                           # stray digit fragment from broken price line (e.g. "140,0" split to "0")
      ].freeze

      WEEKDAYS_PT = %w[domingo segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado].freeze

      # An "all-uppercase code" token: 3+ uppercase letters (product codes like ACE, OVOGE)
      CODE_RE = /\A[A-ZÁÉÍÓÚÃÕÂÊÔÇÀÜ]{3,}\z/

      def initialize(text)
        @text = text
      end

      def parse
        date = extract_date
        Bulletin.new(
          price_date: date,
          weekday:    WEEKDAYS_PT[date.wday],
          rows:       parse_rows
        )
      end

      private

      def extract_date
        m = @text.match(/(\d{2})\/(\d{2})\/(\d{4})/)
        raise "Could not extract date from legacy PDF" unless m
        Date.new(m[3].to_i, m[2].to_i, m[1].to_i)
      end

      def parse_rows
        section          = nil
        current_product  = nil
        current_pkg      = nil   # raw packaging string from product header
        paren_open       = false
        rows             = []

        @text.each_line do |raw|
          line = raw.strip
          next if line.empty?

          # 1. Section banner detection (before DROP_RE so we don't drop the line first)
          banner = section_for(line)
          if banner != :no_match
            section = banner
            current_product = nil
            current_pkg     = nil
            paren_open      = false
            next
          end

          # 2. OVOS bare line → section 6 + product header for children
          if line =~ /\AOVOS\s*\z/i
            section         = 6
            current_product = "OVOS"
            current_pkg     = "(30 DÚZIAS)"
            paren_open      = false
            next
          end

          # 3. DROP noise lines
          next if DROP_RE.any? { |re| line =~ re }

          # 4. Paren continuation: previous header had an unclosed paren
          if paren_open
            # A *-child after a truncated paren → close paren, fall through to child handling
            if line.start_with?("*")
              paren_open = false
            else
              current_pkg = (current_pkg || "") + " " + line
              paren_open  = current_pkg.count("(") > current_pkg.count(")")
              next
            end
          end

          # 5. *-child line
          if line.start_with?("*")
            next unless section
            row = parse_child(line, section, current_product, current_pkg)
            rows << row if row
            next
          end

          # 6. Line has prices (or "Sem cotação") → data row
          if has_prices?(line) || sem_cotacao?(line)
            row = if has_paren?(line)
                    # Self-contained: name before "(", packaging from parens
                    parse_standalone(line, section)
            elsif current_product
                    # Non-starred tipo child (e.g. PIMENTA children)
                    parse_nonstarred_child(line, section, current_product, current_pkg)
            else
                    parse_standalone(line, section)
            end
            rows << row if row
            # A self-contained row with parens resets the header context
            current_product = nil if has_paren?(line)
            current_pkg     = nil if has_paren?(line)
            paren_open      = false
            next
          end

          # 7. Product header (no prices, no *, not a section banner)
          name, pkg = split_name_and_pkg(line)
          next unless name && !name.empty?
          current_product = name
          current_pkg     = pkg
          opens           = (pkg || "").count("(")
          closes          = (pkg || "").count(")")
          paren_open      = opens > closes
        end

        rows
      end

      # Returns the canonical section int (or nil to skip) or :no_match
      def section_for(line)
        SECTION_STARTERS.each do |re, sec|
          return sec if line =~ re
        end
        :no_match
      end

      def has_prices?(line)
        line.split(/\s+/).count { |t| t =~ PRICE } >= 3
      end

      def sem_cotacao?(line)
        line =~ /Sem\s+cota[çc]ão/i
      end

      def has_paren?(line)
        line.include?("(")
      end

      # Self-contained row: product name (before "(" if present) + prices
      def parse_standalone(line, section)
        toks = line.split(/\s+/)
        min, modal, max = extract_prices!(toks)

        if min.nil? && !sem_cotacao?(line)
          return nil  # couldn't extract prices
        end

        # Find paren in remaining toks
        full_text = toks.join(" ")
        name, pkg = split_name_and_pkg(full_text)

        # Fallback: if no paren, name = tokens before the first code-looking token
        if pkg.nil? && name
          name_toks, emb_tok, rest = split_name_from_code(toks)
          name = name_toks.join(" ")
          # Embalagem code can be the token right after the product code
          # e.g. "Abrótea ABT Kg" → emb_tok="ABT", first of rest is "Kg"
          following = rest.find { |t| t =~ /\AKg\z/i }
          if emb_tok =~ /\AKg\z/i || following
            pkg = "(Kg)"
          end
        end

        return nil unless name && !name.empty?

        raw_unit = synthesize_unit(pkg)

        Row.new(
          section:       section,
          raw_product:   name.strip,
          raw_tipo:      nil,
          raw_unit:      raw_unit,
          variation_12m: nil,
          min: min, modal: modal, max: max,
          price_per_kg:  CeasaRio::UnitNormalizer.new.per_kg(raw_unit, modal)
        )
      end

      # Non-starred tipo child (e.g. PIMENTA children without *)
      def parse_nonstarred_child(line, section, current_product, current_pkg)
        toks = line.split(/\s+/)
        min, modal, max = extract_prices!(toks)
        return nil if min.nil? && !sem_cotacao?(line)

        # tipo: tokens before the first code
        tipo_toks, code_tok, rest = split_name_from_code(toks)
        raw_tipo = tipo_toks.join(" ").presence

        raw_unit = synthesize_unit(current_pkg)
        # If parent had no packaging, check if embalagem after code is bare "Kg"
        if raw_unit.nil?
          following_kg = (code_tok =~ /\AKg\z/i) || rest.any? { |t| t =~ /\AKg\z/i }
          raw_unit = "kg" if following_kg
        end

        Row.new(
          section:       section,
          raw_product:   current_product,
          raw_tipo:      raw_tipo,
          raw_unit:      raw_unit,
          variation_12m: nil,
          min: min, modal: modal, max: max,
          price_per_kg:  CeasaRio::UnitNormalizer.new.per_kg(raw_unit, modal)
        )
      end

      # *-prefixed child: inherits current_product; tipo from line
      def parse_child(line, section, current_product, current_pkg)
        return nil unless current_product

        inner = line.sub(/\A\*/, "").strip
        toks  = inner.split(/\s+/)
        min, modal, max = extract_prices!(toks)
        return nil if min.nil? && !sem_cotacao?(line)

        # Child may have its own parens (e.g. "*Grande (2 Kg)")
        full_text = toks.join(" ")
        if has_paren?(full_text)
          tipo_name, child_pkg = split_name_and_pkg(full_text)
          raw_tipo = tipo_name&.strip
          raw_unit = synthesize_unit(child_pkg)
        else
          # tipo = tokens before first code; inherit parent packaging for raw_unit
          tipo_toks, _code, _rest = split_name_from_code(toks)
          raw_tipo = tipo_toks.join(" ").presence
          raw_unit = synthesize_unit(current_pkg)
        end

        Row.new(
          section:       section,
          raw_product:   current_product,
          raw_tipo:      raw_tipo,
          raw_unit:      raw_unit,
          variation_12m: nil,
          min: min, modal: modal, max: max,
          price_per_kg:  CeasaRio::UnitNormalizer.new.per_kg(raw_unit, modal)
        )
      end

      # Extract 3 prices from the right of the token array (mutates toks).
      # Returns [min, modal, max] or [nil, nil, nil] for Sem cotação lines.
      def extract_prices!(toks)
        prices = []
        while toks.any? && toks.last =~ PRICE && prices.size < 3
          prices.unshift(toks.pop)
        end
        if prices.size == 3
          prices.map { |p| p.gsub(",", ".").to_f }
        else
          [ nil, nil, nil ]
        end
      end

      # Split "PRODUCT NAME (packaging...)" → [name, "packaging..."] or [text, nil]
      def split_name_and_pkg(text)
        return [ nil, nil ] if text.nil? || text.strip.empty?
        idx = text.index("(")
        if idx
          name = text[0...idx].strip
          pkg  = text[idx..].strip
          [ name.empty? ? nil : name, pkg.empty? ? nil : pkg ]
        else
          [ text.strip, nil ]
        end
      end

      # For no-paren lines: split into [name_tokens, code_token_or_nil, rest_tokens]
      # Collects tokens until the first CODE_RE match (3+ uppercase letters).
      def split_name_from_code(toks)
        name_toks = []
        code_tok  = nil
        rest      = []
        found     = false
        toks.each_with_index do |t, i|
          if !found && t =~ CODE_RE
            code_tok = t
            rest     = toks[(i + 1)..] || []
            found    = true
            break
          end
          name_toks << t unless found
        end
        [ name_toks, code_tok, rest ]
      end

      # Convert legacy packaging string into a modern-style raw_unit the UnitNormalizer handles.
      def synthesize_unit(pkg)
        return nil if pkg.nil? || pkg.strip.empty?
        # Eggs: dozen (DÚZIAS or dúzias – handle both capital/lowercase Ú)
        return "Cx 30 dz" if pkg =~ /d[úÚu]zia/i
        # Bare "(Kg)" → already per-kg
        return "kg" if pkg =~ /\A\(Kg\)\z/i
        # Extract first weight in kg
        m = pkg.match(/(\d+(?:[,.]\d+)?)\s*kg/i)
        return nil unless m
        weight = m[1].tr(".", ",")
        "Cx #{weight} kg"
      end
    end
  end
end
