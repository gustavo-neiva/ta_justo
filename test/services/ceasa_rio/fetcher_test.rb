require "test_helper"

class CeasaRio::FetcherTest < ActiveSupport::TestCase
  # Regression: url_for produces spaces + accented chars (diário/preços). The
  # raw string is not a valid ASCII URI, so URI() raised InvalidURIError and the
  # rescue in fetch_and_validate swallowed it — silently killing every fetch.
  # fetch_and_validate must ASCII-escape before handing the URL to URI().
  test "url_for output is escapable to a valid ascii URI" do
    url = CeasaRio::Fetcher.new.url_for(Date.new(2026, 8, 3))
    assert_match(/ /, url, "sanity: raw URL has spaces")
    assert_match(/á|ç/, url, "sanity: raw URL has accents")

    escaped = URI::DEFAULT_PARSER.escape(url)
    uri = assert_nothing_raised { URI(escaped) }
    assert_equal "www.rj.gov.br", uri.host
    assert escaped.ascii_only?, "escaped URL must be ascii-only for Net::HTTP"
  end
end
