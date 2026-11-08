require "test_helper"

# The checker page: catalog-driven search index, stall tiles, item cards with
# the CEASA math, and the verdict form (Brazilian decimal comma).
class CheckerTest < ActionDispatch::IntegrationTest
  setup do
    @bulletin = Bulletin.create!(market: "ceasa-rj", price_date: Date.current, source_url: "https://ex.test/b.pdf")
    manga = Product.create!(name: "Manga", category: "fruta", section: 1, slug: "manga")
    @palmer = Variant.create!(product: manga, name: "Palmer", pricing_mode: "per_kg")
    @tommy = Variant.create!(product: manga, name: "Tommy Atkins", pricing_mode: "per_kg")
    price(@palmer, "Cx 18 kg", 60)
    price(@tommy, "Cx 5 kg", 65)   # smallest pack → headline R$13/kg
    price(@tommy, "Cx 18 kg", 60)  # shown in the breakdown

    banana = Product.create!(name: "Banana", category: "fruta", section: 1, slug: "banana")
    { "Prata Extra" => 60, "Nanica/D'Água Extra" => 50, "Ouro" => 130 }.each do |name, modal|
      price(Variant.create!(product: banana, name: name, pricing_mode: "per_kg"), "Cx 20 kg", modal)
    end
    price(Variant.create!(product: banana, name: "Figo", pricing_mode: "per_kg"), "Cx 2 kg", 90) # R$45/kg

    alface = Product.create!(name: "Alface", category: "hortalica", section: 4, slug: "alface")
    @crespa = Variant.create!(product: alface, name: "Crespa Extra", pricing_mode: "per_unit", avg_weight_kg: 0.35)
    price(@crespa, "Preg 6 kg", 40)
  end

  def price(variant, raw_unit, modal)
    Price.create!(bulletin: @bulletin, variant: variant, section: 1, raw_unit: raw_unit, original_unit: "kg",
                  modal: modal, min: modal - 5, max: modal + 5, price_per_kg: (modal / PackSize.kg(raw_unit)).round(2))
  end

  test "home: focused search box, catalog index with prices, stall tiles, cards closed" do
    get root_path
    assert_response :success
    assert_select "input#checker-q[type=search][autofocus]"
    index = JSON.parse(css_select("[data-controller=checker]").first["data-checker-index-value"])
    manga = index.find { |i| i["id"] == "manga" }
    assert_equal "R$ 3,33–13,00/kg", manga["price"]
    assert_includes manga["varieties"], "Tommy"
    assert_select ".checker-grid a.tile[href=?] .tile-name", "/?item=alface", text: "Alface"
    assert_select "section.item-card[hidden]", CheckerCatalog.items.size
  end

  test "?item= opens the card: varieties, other packs, outlier flag" do
    get root_path(item: "manga")
    assert_select "section#item-manga:not([hidden])" do
      assert_select ".item-varies"
      assert_select ".variety-price", text: /R\$ 13,00\/kg/
      assert_select ".variety-math", text: /Cx 18 kg → R\$ 3,33\/kg/
    end

    get root_path(item: "banana")
    assert_select "section#item-banana .variety", 4
    assert_select "section#item-banana .badge-odd", 1 # Figo R$45/kg vs ~R$3
  end

  test "single-price item shows a headline, the unit, and the 'closest reference' note for unquoted types" do
    get root_path(item: "alface")
    assert_select "section#item-alface" do
      assert_select ".item-ceasa", text: /R\$ 2,33.*por unidade/
      assert_select ".item-fair", text: /até R\$ 5,84/
      assert_select "[data-closest-note][hidden]", text: /só cota alface crespa e lisa/
      assert_select "form.price-form input[name=price][inputmode=decimal]"
    end
  end

  test "verdict accepts a comma decimal and reopens the item card" do
    get root_path(product: "manga", variant: @palmer.id, price: "8,50")
    assert_select ".verdict-result .verdict-price-row", text: /Você pagou: R\$ 8,50\/kg/
    assert_select "section#item-manga:not([hidden])"
  end
end
