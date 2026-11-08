module ChecksHelper
  PRODUCE_ICONS = Rails.root.join("app/assets/images/produce")

  # One hidden <symbol> per IconOven icon used; tiles/cards reference it with <use>.
  def produce_icon_sprite(items)
    symbols = items.map(&:icon).uniq.map do |name|
      inner = File.read(PRODUCE_ICONS.join("#{name}.svg"))[%r{<svg[^>]*>(.*)</svg>}m, 1]
      %(<symbol id="pi-#{name}" viewBox="0 0 24 24">#{inner}</symbol>)
    end
    %(<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" style="position:absolute;width:0;height:0;overflow:hidden">#{symbols.join}</svg>).html_safe
  end

  # Line icon (stroke=currentColor), tinted via CSS class.
  def produce_icon(item, size: nil)
    css = [ "produce-icon", "tint-#{item.tint || "green"}", ("produce-icon--#{size}" if size) ].compact.join(" ")
    %(<svg class="#{css}" aria-hidden="true"><use href="#pi-#{item.icon}"/></svg>).html_safe
  end

  # "R$ 3,00/kg" or "R$ 2,50–6,50/kg" for an item's search result line.
  def item_price_summary(ref)
    return "sem cotação recente" unless ref && ref[:headline]
    unit = ref[:headline][:unit]
    values = ref[:rows].reject { |r| r[:outlier] }.select { |r| r[:unit] == unit }.map { |r| r[:value] }
    if ref[:varies] && values.size > 1
      "#{brl(values.min)}–#{brl(values.max).delete_prefix("R$ ")}/#{unit}"
    else
      "#{brl(ref[:headline][:value])}/#{unit}"
    end
  end

  def short_date(date) = date&.strftime("%d/%m")
end
