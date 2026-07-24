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
    when :cheap     then "época barata"
    when :normal    then "preço normal"
    when :expensive then "época cara"
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
    text  = timing.qualifier ? "#{timing.qualifier} #{timing.label}" : timing.label

    content_tag(:span, "#{emoji} #{text}", class: "epoca-pill #{bucket_class}")
  end
end
