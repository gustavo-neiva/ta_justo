module CeasaRio
  class VariantMatcher
    # Uses the ProductMap table (data-driven, editable) for deterministic matching
    def match(parsed_row, market: "ceasa-rj")
      ProductMap.find_by(
        market: market,
        section: parsed_row.section,
        raw_product: parsed_row.raw_product,
        raw_tipo: parsed_row.raw_tipo.to_s
      )&.variant
      # nil → caller records to pending_matches (data never lost)
    end
  end
end
