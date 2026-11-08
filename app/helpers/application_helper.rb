module ApplicationHelper
  # Inline SVG icons (Heroicons solid 24, MIT — https://heroicons.com).
  # fill="currentColor" so icons inherit surrounding text color.
  ICONS = {
    "check-circle"          => '<path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm13.36-1.814a.75.75 0 1 0-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 0 0-1.06 1.06l2.25 2.25a.75.75 0 0 0 1.14-.094l3.75-5.25Z" clip-rule="evenodd"/>',
    "minus-circle"          => '<path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25Zm3 10.5a.75.75 0 0 0 0-1.5H9a.75.75 0 0 0 0 1.5h6Z" clip-rule="evenodd"/>',
    "exclamation-triangle"  => '<path fill-rule="evenodd" d="M9.401 3.003c1.155-2 4.043-2 5.197 0l7.355 12.748c1.154 2-.29 4.5-2.599 4.5H4.645c-2.309 0-3.752-2.5-2.598-4.5L9.4 3.003ZM12 8.25a.75.75 0 0 1 .75.75v3.75a.75.75 0 0 1-1.5 0V9a.75.75 0 0 1 .75-.75Zm0 8.25a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z" clip-rule="evenodd"/>',
    "x-circle"              => '<path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25Zm-1.72 6.97a.75.75 0 1 0-1.06 1.06L10.94 12l-1.72 1.72a.75.75 0 1 0 1.06 1.06L12 13.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L13.06 12l1.72-1.72a.75.75 0 1 0-1.06-1.06L12 10.94l-1.72-1.72Z" clip-rule="evenodd"/>',
    "information-circle"    => '<path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm8.706-1.442c1.146-.573 2.437.463 2.126 1.706l-.709 2.836.042-.02a.75.75 0 0 1 .67 1.34l-.04.022c-1.147.573-2.438-.463-2.127-1.706l.71-2.836-.042.02a.75.75 0 1 1-.671-1.34l.041-.022ZM12 9a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z" clip-rule="evenodd"/>',
    "arrow-trending-down"   => '<path fill-rule="evenodd" d="M1.72 5.47a.75.75 0 0 1 1.06 0L9 11.69l3.756-3.756a.75.75 0 0 1 .985-.066 12.698 12.698 0 0 1 4.575 6.832l.308 1.149 2.277-3.943a.75.75 0 1 1 1.299.75l-3.182 5.51a.75.75 0 0 1-1.025.275l-5.511-3.181a.75.75 0 0 1 .75-1.3l3.943 2.277-.308-1.149a11.194 11.194 0 0 0-3.528-5.617l-3.809 3.81a.75.75 0 0 1-1.06 0L1.72 6.53a.75.75 0 0 1 0-1.061Z" clip-rule="evenodd"/>',
    "arrow-trending-up"     => '<path fill-rule="evenodd" d="M15.22 6.268a.75.75 0 0 1 .968-.431l5.942 2.28a.75.75 0 0 1 .431.97l-2.28 5.94a.75.75 0 1 1-1.4-.537l1.63-4.251-1.086.484a11.2 11.2 0 0 0-5.45 5.173.75.75 0 0 1-1.199.19L9 12.312l-6.22 6.22a.75.75 0 0 1-1.06-1.061l6.75-6.75a.75.75 0 0 1 1.06 0l3.606 3.606a12.695 12.695 0 0 1 5.68-4.974l1.086-.483-4.251-1.632a.75.75 0 0 1-.432-.97Z" clip-rule="evenodd"/>',
    "chart-bar"             => '<path d="M18.375 2.25c-1.035 0-1.875.84-1.875 1.875v15.75c0 1.035.84 1.875 1.875 1.875h.75c1.035 0 1.875-.84 1.875-1.875V4.125c0-1.036-.84-1.875-1.875-1.875h-.75ZM9.75 8.625c0-1.036.84-1.875 1.875-1.875h.75c1.036 0 1.875.84 1.875 1.875v11.25c0 1.035-.84 1.875-1.875 1.875h-.75a1.875 1.875 0 0 1-1.875-1.875V8.625ZM3 13.125c0-1.036.84-1.875 1.875-1.875h.75c1.035 0 1.875.84 1.875 1.875v6.75c0 1.035-.84 1.875-1.875 1.875h-.75A1.875 1.875 0 0 1 3 19.875v-6.75Z"/>',
    "chat-bubble-left-right"=> '<path d="M4.913 2.658c2.075-.27 4.19-.408 6.337-.408 2.147 0 4.262.139 6.337.408 1.922.25 3.291 1.861 3.405 3.727a4.403 4.403 0 0 0-1.032-.211 50.89 50.89 0 0 0-8.42 0c-2.358.196-4.04 2.19-4.04 4.434v4.286a4.47 4.47 0 0 0 2.433 3.984L7.28 21.53A.75.75 0 0 1 6 21v-4.03a48.527 48.527 0 0 1-1.087-.128C2.905 16.58 1.5 14.833 1.5 12.862V6.638c0-1.97 1.405-3.718 3.413-3.979Z"/><path d="M15.75 7.5c-1.376 0-2.739.057-4.086.169C10.124 7.797 9 9.103 9 10.609v4.285c0 1.507 1.128 2.814 2.67 2.94 1.243.102 2.5.157 3.768.165l2.782 2.781a.75.75 0 0 0 1.28-.53v-2.39l.33-.026c1.542-.125 2.67-1.433 2.67-2.94v-4.286c0-1.505-1.125-2.811-2.664-2.94A49.392 49.392 0 0 0 15.75 7.5Z"/>',
    "archive-box"           => '<path d="M3.375 3C2.339 3 1.5 3.84 1.5 4.875v.75c0 1.036.84 1.875 1.875 1.875h17.25c1.035 0 1.875-.84 1.875-1.875v-.75C22.5 3.839 21.66 3 20.625 3H3.375Z"/><path fill-rule="evenodd" d="m3.087 9 .54 9.176A3 3 0 0 0 6.62 21h10.757a3 3 0 0 0 2.995-2.824L20.913 9H3.087Zm6.163 3.75A.75.75 0 0 1 10 12h4a.75.75 0 0 1 0 1.5h-4a.75.75 0 0 1-.75-.75Z" clip-rule="evenodd"/>'
  }.freeze

  def icon(name)
    content_tag(:svg, ICONS.fetch(name.to_s).html_safe,
                xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24",
                fill: "currentColor", class: "icon", "aria-hidden": "true")
  end

  def brl(value) = Variant.brl(value)

  # ── Markup axis helpers ──────────────────────────────────────────────────────

  def markup_icon(bucket)
    icon({ barato: "check-circle", media: "minus-circle", caro: "exclamation-triangle" }[bucket])
  end

  def markup_label(bucket)
    case bucket
    when :barato then "Barato"
    when :media  then "Na média"
    when :caro   then "Caro"
    end
  end

  # ── MarketTiming axis helpers ────────────────────────────────────────────────

  def timing_icon(bucket)
    icon({ cheap: "arrow-trending-down", normal: "chart-bar", expensive: "arrow-trending-up" }[bucket])
  end

  def timing_label(bucket)
    case bucket
    when :cheap     then "na época"
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

    text  = timing.label

    content_tag(:span, safe_join([ timing_icon(timing.bucket), text ], " "), class: "epoca-pill #{bucket_class}")
  end

  # Renders a price in its honest CEASA unit: /kg when CEASA quotes by kg,
  # /dúzia for eggs, /unidade for piece-priced variants. Never shows a modal
  # number under a "/kg" label.
  def price_with_unit(price)
    if price.variant.pricing_mode == "per_dozen" && price.modal
      # CEASA sells eggs by the box ("Cx 30 dz"); modal is per-box → per-dúzia = ÷30.
      per_dozen = price.modal.to_f / FairPriceVerdict::DOZENS_PER_BOX
      "R$ #{number_with_precision(per_dozen, precision: 2)}/dúzia"
    elsif price.price_per_kg
      "R$ #{number_with_precision(price.price_per_kg, precision: 2)}/kg"
    elsif price.modal
      suffix = price.variant.pricing_mode == "per_unit" ? "un." : "kg"
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
      value, basis = variant.comparable_with_basis(price)
      value ? "R$ %.2f/unidade (%s)" % [ value, basis ] : "S/C"
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
