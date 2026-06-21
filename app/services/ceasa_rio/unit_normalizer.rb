module CeasaRio
  class UnitNormalizer
    KG_RE = /(\d+(?:,\d+)?)\s*kg/i

    def per_kg(raw_unit, modal_price)
      return nil if modal_price.nil?
      unit = raw_unit.to_s

      # SPECIAL 1: bare "kg" → already per-kg (weight = 1)
      return modal_price.round(2) if unit.strip.match?(/\Akg\z/i)

      # SPECIAL 2: eggs "Cx 30 dz" → per-DOZEN, not per-kg (mark non-kg)
      return nil if unit =~ /dz/i   # eggs: keep modal as per-dz; price_per_kg = nil

      # SPECIAL 3: "Cx 6" (truncated, no kg) → can't normalize safely
      return nil if unit =~ /\ACx\s+\d+\z/i && unit !~ KG_RE

      # SPECIAL 4: bare "Unid" (no weight) → per-piece, not per-kg
      return nil if unit.strip.match?(/\AUnid\z/i)

      # GENERAL: extract first kg weight → modal / weight
      m = unit.match(KG_RE)
      return nil unless m
      weight = m[1].gsub(',', '.').to_f
      weight.zero? ? nil : (modal_price / weight).round(2)
    end

    def family(raw_unit)
      unit = raw_unit.to_s
      return "dozen" if unit =~ /dz/i
      return "unit" if unit.strip.match?(/\AUnid\z/i)
      "kg"
    end
  end
end
