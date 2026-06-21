require 'net/http'
require 'uri'

module CeasaRio
  class Fetcher
    BASE = "https://www.rj.gov.br/ceasa/sites/default/files/arquivos_paginas"

    def url_for(date)
      # Current pattern (2 spaces before DD). Stable for the current era.
      "#{BASE}/Boletim diário de preços  #{date.strftime('%d %m %Y')}.pdf"
    end

    # Returns [date, pdf_bytes] or nil. Walks back over weekends/holidays.
    def latest(days_back: 12)
      date = Date.today
      days_back.times do
        if date.saturday? || date.sunday? || br_holiday?(date)
          date -= 1
          next
        end
        body = fetch_and_validate(url_for(date))
        return [date, body] if body
        date -= 1
      end
      nil
    end

    def fetch_and_validate(url)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        resp = http.get(uri.request_uri)
        return nil unless resp.code == "200"
        return nil unless resp["content-type"]&.include?("application/pdf")
        body = resp.body
        return nil unless body.start_with?("%PDF")
        body
      end
    rescue => e
      Rails.logger.error("Fetch error for #{url}: #{e.message}")
      nil
    end

    def br_holiday?(date)
      require "holidays"
      Holidays.on(date, :br).any?
    end
  end
end
