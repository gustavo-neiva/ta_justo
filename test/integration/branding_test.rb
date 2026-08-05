require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  test "footer includes author name linking to personal site with noopener" do
    get root_path
    assert_response :success

    link = css_select("footer a[href='https://gustavoneiva.dev']").first
    assert link, "expected footer link to gustavoneiva.dev"
    assert_includes link.text, "Gustavo Neiva"
    assert_equal "_blank", link["target"]
    assert_includes link["rel"], "noopener"
    assert_includes link["rel"], "noreferrer"
  end

  test "about page includes author name linking to personal site with noopener" do
    get sobre_path
    assert_response :success

    link = css_select("a[href='https://gustavoneiva.dev']").first
    assert link, "expected about page link to gustavoneiva.dev"
    assert_includes link.text, "Gustavo Neiva"
    assert_equal "_blank", link["target"]
    assert_includes link["rel"], "noopener"
    assert_includes link["rel"], "noreferrer"
  end
end
