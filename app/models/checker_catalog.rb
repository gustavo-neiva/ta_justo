# What a shopper recognises at the stall → CEASA variants. Data lives in
# config/checker_catalog.yml (see the header there for the field contract).
class CheckerCatalog
  PATH = Rails.root.join("config/checker_catalog.yml")

  GROUPS = {
    "legumes" => "Legumes", "folhas" => "Folhas", "temperos" => "Temperos",
    "raizes" => "Raízes", "frutas" => "Frutas", "ovos" => "Ovos"
  }.freeze
  # No honest produce icon → a generic one for the group (never a look-alike).
  FALLBACK_ICON = {
    "legumes" => "seedling", "folhas" => "leaf", "temperos" => "herb",
    "raizes" => "root", "frutas" => "seedling", "ovos" => "egg"
  }.freeze

  Member = Data.define(:product, :variant, :label, :hint, :note)
  Item = Data.define(:id, :name, :scientific, :group, :icon, :tint, :top,
                     :aliases, :closest_note, :closest_names, :confuse, :members)

  def self.items
    @items ||= YAML.load_file(PATH).map { |h| build(h) }.freeze
  end

  def self.find(id)
    items.find { |i| i.id == id.to_s }
  end

  def self.by_group
    items.group_by(&:group).sort_by { |g, _| GROUPS.keys.index(g) }
  end

  # Item that holds a given CEASA variant (to reopen the card after a verdict).
  def self.for_variant(variant)
    items.find { |i| i.members.any? { |m| m.product == variant.product.slug && m.variant == variant.name } }
  end

  # Search terms only — no DB, so the gold-set test is deterministic.
  # `prices` (id → short price string) is merged in by the controller.
  def self.search_index(prices = {})
    items.map do |i|
      { id: i.id, name: i.name, icon: i.icon, tint: i.tint, top: i.top,
        aliases: i.aliases, closest: i.closest_names,
        varieties: i.members.map(&:label), price: prices[i.id] }.compact
    end
  end

  def self.build(h)
    closest = h["closest"] || {}
    Item.new(
      id: h.fetch("id"), name: h.fetch("name"), scientific: h["scientific"],
      group: h.fetch("group"), icon: h["icon"] || FALLBACK_ICON.fetch(h["group"]),
      tint: h["tint"], top: !!h["top"], aliases: Array(h["aliases"]),
      closest_note: closest["note"], closest_names: Array(closest["names"]),
      confuse: Array(h["confuse"]),
      members: h.fetch("members").map do |m|
        Member.new(product: m.fetch("product"), variant: m.fetch("variant"),
                   label: m.fetch("label"), hint: m["hint"], note: m["note"])
      end
    )
  end
  private_class_method :build
end
