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
end
