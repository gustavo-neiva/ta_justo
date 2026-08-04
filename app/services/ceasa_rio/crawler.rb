require "open-uri"
require "nokogiri"
require "timeout"

module CeasaRio
  class Crawler
    HUB = "https://www.rj.gov.br/ceasa/Cota%C3%A7%C3%A3o"
    MODERN_MIN = Date.new(2023, 3, 1)

    def discover_urls(since: nil)
      since ||= latest_archived_date
      puts "Fetching hub page..."
      puts "Only crawling months since #{since}" if since
      
      cota  = Nokogiri::HTML(fetch_with_timeout(HUB))
      years = parse_year_tabs(cota)
      puts "Found #{years.size} years"
      urls  = []
      years.each do |year, year_url|
        year_num = year.to_i
        next if since && year_num < since.year
        
        puts "Fetching year #{year}..."
        months = parse_month_links(Nokogiri::HTML(fetch_with_timeout(year_url)))
        puts "  Found #{months.size} months"
        months.each do |month_name, month_url|
          if since && year_num == since.year
            month_num = month_index(month_name)
            next if month_num && month_num < since.month
          end
          
          puts "  Crawling #{month_name}..."
          urls.concat(paginate_pdfs(month_url))
        end
      end
      urls.uniq
    rescue => e
      Rails.logger.error("Crawler error: #{e.message}")
      puts "Error: #{e.message}"
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
        text = a.text.gsub(/\p{Space}+/, " ").strip
        next unless months.any? { |m| text =~ /\A#{m}\z/i }
        href = a["href"]
        h[text] = href.start_with?("http") ? href : URI.join(HUB, href).to_s
      end
    end

    # v1: stop when a page yields zero new PDFs (the robust signal). The page cap is just
    # a safety bound, and `.next` is a defensive hint — not load-bearing.
    def paginate_pdfs(month_url)
      urls = []
      seen = Set.new
      (0..20).each do |page|
        page_url = "#{month_url}?page=#{page}"
        print "    Page #{page}..."
        html = Nokogiri::HTML(fetch_with_timeout(page_url))
        found = html.css("a[href*='arquivos_paginas'][href$='.pdf']").map { |a| URI.join(HUB, a["href"]).to_s }
        
        if found.empty?
          puts " no PDFs, stopping"
          break
        end
        
        new_urls = found.reject { |u| seen.include?(u) }
        if new_urls.empty?
          puts " all duplicates, stopping"
          break
        end
        
        puts " found #{found.size} PDFs (#{new_urls.size} new)"
        new_urls.each { |u| seen.add(u) }
        urls.concat(new_urls)
        sleep 0.3
      end
      urls
    rescue => e
      Rails.logger.error("Pagination error for #{month_url}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      []
    end

    private

    def latest_archived_date
      files = Dir["#{CeasaRio::Archiver.raw_dir}/*.pdf"]
      return nil if files.empty?
      
      dates = files.map { |f| File.basename(f, ".pdf") }
                   .map { |d| Date.parse(d) rescue nil }
                   .compact
      dates.max - 7 # Go back 1 week to catch any missed PDFs
    rescue
      nil
    end

    def month_index(month_name)
      %w[Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro]
        .index { |m| month_name =~ /#{m}/i }.to_i + 1 rescue nil
    end

    def fetch_with_timeout(url, timeout_sec = 10)
      Timeout.timeout(timeout_sec) do
        URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: timeout_sec)
      end
    end
  end
end
