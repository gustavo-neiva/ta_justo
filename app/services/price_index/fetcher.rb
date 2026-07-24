# Fetches price index data from BCB SGS API
#
# Uses the simple SGS JSON API:
# https://api.bcb.gov.br/dados/serie/bcdata.sgs.{code}/dados?formato=json
#
# Response format:
# [{ "data" => "DD/MM/YYYY", "valor" => <index_level> }, ...]
#
class PriceIndex
  class Fetcher
    VERSION = "1.0.0"

    # Series codes for BCB SGS
    IPCA_SERIES = 1737  # Índice Nacional de Preços ao Consumidor Amplo
    INPC_SERIES = 188   # Índice Nacional de Preços ao Consumidor

    # Base URL for BCB SGS API
    BASE_URL = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.%{series}/dados?formato=json"

    # Custom error class for API-related errors
    class APIError < StandardError; end

    # Fetch IPCA (Índice Nacional de Preços ao Consumidor Amplo) series
    #
    # @return [Array<Hash>] Array of {reference_month: Date, index_level: BigDecimal}
    # @raise [APIError] if API request fails or returns invalid data
    def fetch_ipc
      fetch_series(IPCA_SERIES)
    end

    # Fetch INPC (Índice Nacional de Preços ao Consumidor) series
    #
    # @return [Array<Hash>] Array of {reference_month: Date, index_level: BigDecimal}
    # @raise [APIError] if API request fails or returns invalid data
    def fetch_inpc
      fetch_series(INPC_SERIES)
    end

    # Fetch data for a specific BCB SGS series code
    #
    # @param series_code [Integer] BCB SGS series code (e.g., 1737 for IPCA, 188 for INPC)
    # @return [Array<Hash>] Array of {reference_month: Date, index_level: BigDecimal}
    # @raise [APIError] if API request fails or returns invalid data
    def fetch_series(series_code)
    uri = URI(format(BASE_URL, series: series_code))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request.add_field("User-Agent", user_agent)

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise APIError, "BCB API error: #{response.code} #{response.message}"
    end

    parse_response(response.body)
  rescue JSON::ParserError => e
    raise APIError, "Failed to parse JSON response: #{e.message}"
  rescue StandardError => e
    raise APIError, "Failed to fetch series #{series_code}: #{e.message}"
  end

    private

    # Parse BCB SGS JSON response
    #
    # @param body [String] JSON response body
    # @return [Array<Hash>] Array of {reference_month: Date, index_level: BigDecimal}
    # @raise [APIError] if response is empty or malformed
    def parse_response(body)
      data = JSON.parse(body)

      if data.empty?
        raise APIError, "No data returned from API"
      end

      data.map do |entry|
        {
          reference_month: parse_date(entry["data"]),
          index_level: parse_value(entry["valor"])
        }
      end
    end

    # Parse BCB date format (DD/MM/YYYY) to Date object
    #
    # @param date_string [String] Date in DD/MM/YYYY format
    # @return [Date] Parsed date
    def parse_date(date_string)
      day, month, year = date_string.split("/").map(&:to_i)
      Date.new(year, month, day)
    end

    # Parse index value to BigDecimal for precision
    #
    # @param value [Numeric, String] Index value (may be numeric or string)
    # @return [BigDecimal] Parsed value as BigDecimal
    def parse_value(value)
      BigDecimal(value.to_s)
    end

    # Bot User-Agent header for API requests
    #
    # @return [String] User-Agent string
    def user_agent
      "TáJusto/#{VERSION} (https://github.com/gustavo-neiva/ta_justo)"
    end
  end
end
