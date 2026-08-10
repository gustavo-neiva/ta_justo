module ApplicationHelper
  # ── Markup axis helpers ──────────────────────────────────────────────────────

  def markup_emoji(bucket)
    case bucket
    when :barato then "✅"
    when :media  then "➖"
    when :caro   then "⚠️"
    end
  end

  def markup_label(bucket)
    case bucket
    when :barato then "Barato"
    when :media  then "Na média"
    when :caro   then "Caro"
    end
  end

  # ── MarketTiming axis helpers ────────────────────────────────────────────────

  def timing_emoji(bucket)
    case bucket
    when :cheap     then "📉"
    when :normal    then "📊"
    when :expensive then "📈"
    end
  end

  def timing_label(bucket)
    case bucket
    when :cheap     then "em época"
    when :normal    then "preço normal"
    when :expensive then "fora de época"
    end
  end

  # Renders the época pill for the /precos index. Returns empty string when
  # no timing signal is available (thin history, no tag shown).
  def epoca_pill(timing)
    return "".html_safe unless timing

    bucket_class = {
      cheap:     "epoca-pill--cheap",
      normal:    "epoca-pill--normal",
      expensive: "epoca-pill--expensive"
    }[timing.bucket]

    emoji = { cheap: "📉", normal: "📊", expensive: "📈" }[timing.bucket]
    text  = timing.label

    content_tag(:span, "#{emoji} #{text}", class: "epoca-pill #{bucket_class}")
  end

  # Renders a price in its honest CEASA unit: /kg when CEASA quotes by kg,
  # /dúzia for eggs, /unidade for piece-priced variants. Never shows a modal
  # number under a "/kg" label.
  def price_with_unit(price)
    if price.price_per_kg
      "R$ #{number_with_precision(price.price_per_kg, precision: 2)}/kg"
    elsif price.modal
      suffix = case price.variant.pricing_mode
      when "per_dozen" then "dúzia"
      when "per_unit"  then "unidade"
      else                  "kg"
      end
      "R$ #{number_with_precision(price.modal, precision: 2)}/#{suffix}"
    else
      "S/C"
    end
  end

  # Explains how the displayed price was derived from the raw CEASA row.
  # Only odd-packaging per_kg gets a "÷ pack weight" derivation; bare kg,
  # direct unit, dozen and weight-derived unit prices state their real unit.
  def price_basis_line(variant, price)
    case variant.pricing_mode
    when "per_dozen"
      "R$ %.2f/dúzia = caixa R$ %.2f ÷ 30 dz (CEASA)" % [
        price.modal.to_f / 30, price.modal.to_f
      ]
    when "per_unit"
      if price.original_unit == "unit"
        line = "R$ %.2f/unidade (preço CEASA por peça)" % price.modal.to_f
        if variant.avg_weight_kg&.positive?
          line += " ≈ R$ %.2f/kg (peça ~%dg estimada)" % [
            price.modal.to_f / variant.avg_weight_kg.to_f,
            (variant.avg_weight_kg.to_f * 1000).round
          ]
        end
        line
      else
        "R$ %.2f/unidade ≈ R$ %.2f/kg × ~%dg (estimado)" % [
          price.price_per_kg.to_f * variant.avg_weight_kg.to_f,
          price.price_per_kg.to_f,
          (variant.avg_weight_kg.to_f * 1000).round
        ]
      end
    else # per_kg
      kg = PackSize.kg(price.raw_unit)
      if kg
        "R$ %.2f/kg = modal R$ %.2f ÷ %g kg (embalagem %s, CEASA)" % [
          price.price_per_kg.to_f, price.modal.to_f, kg, price.raw_unit
        ]
      else
        "R$ %.2f/kg (preço CEASA por kg)" % price.price_per_kg.to_f
      end
    end
  end
end
