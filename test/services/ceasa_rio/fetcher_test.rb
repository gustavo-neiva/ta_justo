require "test_helper"
require "webmock/minitest"

class CeasaRio::FetcherTest < ActiveSupport::TestCase
  setup { WebMock.disable_net_connect!(allow_localhost: true) }
  teardown { WebMock.reset! }

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

  # Regression: the crawler hands fetch_and_validate an ALREADY percent-encoded
  # href (%20, %C3%A1). A plain escape double-encodes those to %2520/%25C3%25A1
  # → server 404 → every backfill/recent fetch silently failed. The escape must
  # be idempotent.
  test "fetch_and_validate does not double-encode an already-escaped crawler href" do
    encoded = "https://www.rj.gov.br/ceasa/sites/default/files/arquivos_paginas/Boletim%20di%C3%A1rio%20de%20pre%C3%A7os%20%2007%2008%202026.pdf"
    stub_request(:get, encoded)
      .to_return(status: 200, body: "%PDF-1.7 fake", headers: { "content-type" => "application/pdf" })

    body = CeasaRio::Fetcher.new.fetch_and_validate(encoded)

    assert_equal "%PDF-1.7 fake", body
    assert_requested :get, encoded   # hit the encoded URL, not a %2520 double-encoded one
  end
end
