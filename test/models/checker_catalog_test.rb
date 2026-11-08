require "test_helper"

# The catalog is hand-curated; these checks keep it honest against the seeds
# (exact Unicode variant names — see AGENTS.md "Apostrophe Unicode").
class CheckerCatalogTest < ActiveSupport::TestCase
  setup do
    silence_stream($stdout) { load Rails.root.join("db/seeds/products.rb") }
  end

  test "every member points at an existing variant (exact name)" do
    missing = CheckerCatalog.items.flat_map(&:members).reject do |m|
      Variant.joins(:product).exists?(products: { slug: m.product }, name: m.variant)
    end
    assert_empty missing.map { |m| "#{m.product} / #{m.variant}" }
  end

  test "every produce variant belongs to exactly one item" do
    keys = CheckerCatalog.items.flat_map(&:members).map { |m| [ m.product, m.variant ] }
    assert_equal keys.uniq, keys, "a variant is listed under two items"
    produce = Variant.joins(:product).where.not(products: { category: "peixe" }).pluck("products.slug", :name)
    assert_empty produce - keys, "produce variants missing from config/checker_catalog.yml"
  end

  test "no stray keys (an unquoted comma inside { } silently splits a value)" do
    allowed_item = %w[id name scientific group icon tint top aliases closest confuse members]
    allowed_member = %w[product variant label hint note]
    YAML.load_file(CheckerCatalog::PATH).each do |h|
      assert_empty h.keys - allowed_item, h["id"]
      h["members"].each { |m| assert_empty m.keys - allowed_member, "#{h["id"]}: #{m.inspect}" }
    end
  end

  test "ids, groups, icons and cross-references are valid" do
    items = CheckerCatalog.items
    ids = items.map(&:id)
    assert_equal ids.uniq, ids
    items.each do |i|
      assert_includes CheckerCatalog::GROUPS.keys, i.group, i.id
      assert Rails.root.join("app/assets/images/produce/#{i.icon}.svg").exist?, "#{i.id}: icon #{i.icon} missing"
      assert_empty i.confuse - ids, "#{i.id}: confuse points at unknown ids"
      assert i.closest_note.present?, "#{i.id}: closest names need a note" if i.closest_names.any?
    end
  end

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(old)
  end
end
