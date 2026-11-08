# Today's CEASA reference for every checker item, with the numbers behind it.
#
# Per member variant: the representative row (smallest retail pack, Plan §3.1)
# is the headline; other packs on the same bulletin go to the breakdown.
# Plain hashes so the whole thing caches cheaply (one rebuild per new bulletin).
class CheckerReference
  DEAD_DAYS  = 60   # no usable price for this long → variety leaves the list
  OUTLIER    = 3.0  # > 3× (or < ⅓) the item's median → "valor atípico"
  SAME_PRICE = 1.3  # varieties within 1.3× → one headline, no choice needed

  def self.all
    key = [ "checker-reference", Price.maximum(:id), Date.current, File.mtime(CheckerCatalog::PATH).to_i ]
    Rails.cache.fetch(key) { CheckerCatalog.items.to_h { |item| [ item.id, new(item).call ] } }
  end

  def initialize(item)
    @item = item
  end

  def call
    rows = @item.members.each_with_index.map { |m, i| row_for(m).merge(index: i) }
    live, dead = rows.partition { |r| r[:value] && !r[:dead] }
    flag_outliers(live)
    usable = live.reject { |r| r[:outlier] }
    values = usable.map { |r| r[:value] }
    {
      rows: live,
      dead: dead,
      headline: usable.first,
      varies: values.size > 1 && values.max / values.min > SAME_PRICE
    }
  end

  private

  def row_for(member)
    variant = Variant.joins(:product).find_by(products: { slug: member.product }, name: member.variant)
    base = { label: member.label, hint: member.hint, note: member.note,
             product: member.product, variant_id: variant&.id, unit: variant&.unit_label }
    price = variant&.latest_price
    return base.merge(dead: true) unless price

    date = price.bulletin.price_date
    value, basis = variant.comparable_with_basis(price)
    base.merge(
      value: value&.round(2), basis: basis, date: date,
      dead: (Date.current - date).to_i > DEAD_DAYS,
      stale: (Date.current - date).to_i > FairPriceVerdict::STALE_DAYS,
      raw_unit: price.raw_unit, min: price.min&.to_f, modal: price.modal&.to_f, max: price.max&.to_f,
      barato_max: value && (value * Markup::BARATO_MAX).round(2),
      media_max: value && (value * Markup::MEDIA_MAX).round(2),
      other_packs: other_packs(variant, price)
    )
  end

  # Same variant, same bulletin, different packaging (e.g. Manga Tommy:
  # Cx 5 kg R$13/kg headline vs Cx 18 kg R$3.33/kg).
  def other_packs(variant, price)
    variant.prices.where(bulletin_id: price.bulletin_id).where.not(id: price.id).filter_map do |p|
      v = variant.comparable(p)
      { raw_unit: p.raw_unit, modal: p.modal.to_f, value: v.round(2) } if v
    end
  end

  def flag_outliers(live)
    return if live.size < 3
    sorted = live.map { |r| r[:value] }.sort
    median = sorted[sorted.size / 2]
    live.each { |r| r[:outlier] = r[:value] > median * OUTLIER || r[:value] < median / OUTLIER }
  end
end
