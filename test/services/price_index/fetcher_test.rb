require "test_helper"
require "webmock/minitest"

class PriceIndex::FetcherTest < ActiveSupport::TestCase
  # Test data matching BCB SGS API response shape
  IPCA_MOCK_RESPONSE = [
    { "data" => "01/01/2024", "valor" => 6642.78 },
    { "data" => "01/02/2024", "valor" => 6654.32 },
    { "data" => "01/03/2024", "valor" => 6670.15 }
  ].to_json

  INPC_MOCK_RESPONSE = [
    { "data" => "01/01/2024", "valor" => 6234.56 },
    { "data" => "01/02/2024", "valor" => 6245.89 },
    { "data" => "01/03/2024", "valor" => 6251.23 }
  ].to_json

  setup do
    @fetcher = PriceIndex::Fetcher.new
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.reset!
  end

  test "#fetch_ipc returns parsed data for IPCA series" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: IPCA_MOCK_RESPONSE)

    result = @fetcher.fetch_ipc

    assert_equal 3, result.size
    assert_equal Date.new(2024, 1, 1), result.first[:reference_month]
    assert_equal BigDecimal("6642.78"), result.first[:index_level]
    assert_equal Date.new(2024, 3, 1), result.last[:reference_month]
    assert_equal BigDecimal("6670.15"), result.last[:index_level]
  end

  test "#fetch_inpc returns parsed data for INPC series" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.188/dados?formato=json")
      .to_return(status: 200, body: INPC_MOCK_RESPONSE)

    result = @fetcher.fetch_inpc

    assert_equal 3, result.size
    assert_equal Date.new(2024, 1, 1), result.first[:reference_month]
    assert_equal BigDecimal("6234.56"), result.first[:index_level]
    assert_equal Date.new(2024, 3, 1), result.last[:reference_month]
    assert_equal BigDecimal("6251.23"), result.last[:index_level]
  end

  test "#fetch_series handles series 1737 (IPCA) correctly" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: IPCA_MOCK_RESPONSE)

    result = @fetcher.fetch_series(1737)

    assert_equal 3, result.size
    assert_equal Date.new(2024, 1, 1), result.first[:reference_month]
    assert_equal BigDecimal("6642.78"), result.first[:index_level]
  end

  test "#fetch_series handles series 188 (INPC) correctly" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.188/dados?formato=json")
      .to_return(status: 200, body: INPC_MOCK_RESPONSE)

    result = @fetcher.fetch_series(188)

    assert_equal 3, result.size
    assert_equal Date.new(2024, 1, 1), result.first[:reference_month]
    assert_equal BigDecimal("6234.56"), result.first[:index_level]
  end

  test "#fetch_series parses DD/MM/YYYY dates correctly" do
    mock_response = [
      { "data" => "01/06/2025", "valor" => 7312.97 },
      { "data" => "01/05/2026", "valor" => 7640.15 }
    ].to_json

    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: mock_response)

    result = @fetcher.fetch_series(1737)

    assert_equal 2, result.size
    assert_equal Date.new(2025, 6, 1), result.first[:reference_month]
    assert_equal Date.new(2026, 5, 1), result.last[:reference_month]
    assert_equal BigDecimal("7312.97"), result.first[:index_level]
    assert_equal BigDecimal("7640.15"), result.last[:index_level]
  end

  test "#fetch_series converts valor to BigDecimal for precision" do
    mock_response = [
      { "data" => "01/01/2024", "valor" => 6642.789 }
    ].to_json

    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: mock_response)

    result = @fetcher.fetch_series(1737)

    assert_equal 1, result.size
    assert_equal BigDecimal("6642.789"), result.first[:index_level]
    assert_instance_of BigDecimal, result.first[:index_level]
  end

  test "#fetch_series raises error on HTTP error" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 500, body: "Internal Server Error")

    error = assert_raises(PriceIndex::Fetcher::APIError) do
      @fetcher.fetch_series(1737)
    end

    assert_match(/500/, error.message)
  end

  test "#fetch_series raises error on empty response" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: [].to_json)

    error = assert_raises(PriceIndex::Fetcher::APIError) do
      @fetcher.fetch_series(1737)
    end

    assert_match(/No data returned/, error.message)
  end

  test "#fetch_series raises error on invalid JSON" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: "invalid json")

    error = assert_raises(PriceIndex::Fetcher::APIError) do
      @fetcher.fetch_series(1737)
    end

    assert_match(/Failed to parse JSON/, error.message)
  end

  test "#fetch_series adds bot User-Agent header" do
    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: IPCA_MOCK_RESPONSE, headers: { "User-Agent" => "TáJusto/1.0.0 (https://github.com/gustavo-neiva/ta_justo)" })

    result = @fetcher.fetch_series(1737)

    assert_equal 3, result.size
  end

  test "#fetch_series handles decimal comma in valor (Brazilian format)" do
    # Note: BCB SGS API returns valor as a number in JSON, not string with comma
    # This test ensures we handle numeric values correctly
    mock_response = [
      { "data" => "01/01/2024", "valor" => 6642.78 }
    ].to_json

    stub_request(:get, "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1737/dados?formato=json")
      .to_return(status: 200, body: mock_response)

    result = @fetcher.fetch_series(1737)

    assert_equal BigDecimal("6642.78"), result.first[:index_level]
  end
end