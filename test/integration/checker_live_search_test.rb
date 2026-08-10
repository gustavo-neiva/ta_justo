require "test_helper"

class CheckerLiveSearchTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Manga", category: "fruta", section: 1, slug: "manga")
    Variant.create!(product: @product, name: "Espada", pricing_mode: "per_kg")
    @palmer = Variant.create!(product: @product, name: "Palmer", pricing_mode: "per_kg", default_for_product: true)
    @product.update!(default_variant: @palmer)
  end

  test "checker renders live search input, embedded index JSON, hidden fields and noscript fallback" do
    get root_path
    assert_response :success

    assert_select "input[type=search][data-product-search-target=input]", 1
    assert_select "input[type=hidden][name=product][data-product-search-target=product]", 1
    assert_select "input[type=hidden][name=variant][data-product-search-target=variant]", 1
    assert_select "div[data-product-search-target=results]", 1
    assert_select "noscript select[name=product]", 1

    form = css_select("form[data-controller=product-search]").first
    assert form, "expected form with product-search controller"

    index_json = form["data-product-search-index-value"]
    assert index_json.present?, "expected search index JSON embedded in form"

    index = JSON.parse(index_json)
    manga = index.find { |p| p["slug"] == "manga" }
    assert manga, "expected Manga in embedded search index"
    assert_includes manga["variants"].map { |v| v["name"] }, "Espada"
    assert manga["variants"].all? { |v| v["id"].present? }, "expected every variant to have an id"
  end

  test "checker pre-fills search input and hidden fields from product and variant params" do
    espada = @product.variants.find_by!(name: "Espada")
    get root_path(product: "manga", variant: espada.id)
    assert_response :success

    assert_select "input[type=hidden][name=product][value=manga]"
    assert_select "input[type=hidden][name=variant][value='#{espada.id}']"
    assert_select "input[type=search][value='Manga › Espada']"
  end
end
