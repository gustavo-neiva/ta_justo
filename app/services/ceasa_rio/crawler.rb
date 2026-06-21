require 'open-uri'
require 'nokogiri'

module CeasaRio
  class Crawler
    HUB = "https://www.rj.gov.br/ceasa/Cota%C3%A7%C3%A3o"
    MODERN_MIN = Date.new(2023, 3, 1)

    def discover_urls
      cota  = Nokogiri::HTML(URI.open(HUB, "User-Agent" => "Mozilla/5.0"))
      years = parse_year_tabs(cota)
      urls  = []
      years.each do |_year, year_url|
        months = parse_month_links(Nokogiri::HTML(URI.open(year_url, "User-Agent" => "Mozilla/5.0")))
        months.each_value do |month_url|
          urls.concat(paginate_pdfs(month_url))
        end
      end
      urls.uniq
    rescue => e
      Rails.logger.error("Crawler error: #{e.message}")
      []
    end

    # Handles BOTH absolute (https://...) and relative (/ceasa/node/...) hrefs.
    def parse_year_tabs(html)
      html.css("a").each_with_object({}) do |a, h|
        text = a.text.strip
        href = a["href"].to_s
        next unless text =~ /\A20\d{2}\z/
        h[text] = href.start_with?("http") ? href : URI.join(HUB, href).to_s
      end
    end

    def parse_month_links(html)
      months = %w[Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro]
      html.css("a").each_with_object({}) do |a, h|
        text = a.text.strip.gsub(/\p{Space}+/, " ")
        next unless months.any? { |m| text =~ /\A#{m}\z/i }
        href = a["href"]
        h[text] = href.start_with?("http") ? href : URI.join(HUB, href).to_s
      end
    end

    # v1: stop when a page yields zero new PDFs (the robust signal). The page cap is just
    # a safety bound, and `.next` is a defensive hint — not load-bearing.
    def paginate_pdfs(month_url)
      urls = []
      (0..20).each do |page|
        html = Nokogiri::HTML(URI.open("#{month_url}?page=#{page}", "User-Agent" => "Mozilla/5.0"))
        found = html.css("a[href*='arquivos_paginas'][href$='.pdf']").map { |a| URI.join(HUB, a["href"]).to_s }
        break if found.empty?
        urls.concat(found)
      end
      urls
    rescue => e
      Rails.logger.error("Pagination error for #{month_url}: #{e.message}")
      []
    end
  end
end
