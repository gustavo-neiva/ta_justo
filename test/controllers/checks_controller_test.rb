require "test_helper"

class ChecksControllerTest < ActionDispatch::IntegrationTest
  test "show assigns search index with core products and variants" do
    product = Product.create!(name: "Manga", category: "fruta", section: 1, slug: "manga")
    Variant.create!(product: product, name: "Espada", pricing_mode: "per_kg")
    Variant.create!(product: product, name: "Palmer", pricing_mode: "per_kg", default_for_product: true)
    product.update!(default_variant: product.variants.find_by(name: "Palmer"))

    get root_path
    assert_response :success

    index = controller.instance_variable_get(:@search_index)
    assert index.present?, "expected @search_index to be assigned and non-empty"

    entry = index.find { |p| p[:slug] == "manga" }
    assert entry, "expected Manga in search index"
    assert_equal [ "Espada", "Palmer" ], entry[:variants].map { |v| v[:name] }.sort
    assert entry[:variants].all? { |v| v[:id].present? }, "expected every variant to have an id"
  end
end
