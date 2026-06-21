# CEASA validation rake task — validates parser + map against sample PDFs
# § 6.6: TIERED validation (core basket 100%, long tail best-effort)

namespace :ceasa do
  desc "Validate parser+map against sample PDFs — fails if any CORE-BASKET row unmapped"
  task validate_mapping: :environment do
    require Rails.root.join('db/seeds/core_basket.rb')
    
    fixtures_path = Rails.root.join("spec/fixtures/ceasa")
    
    unless Dir.exist?(fixtures_path)
      puts "⚠️  No fixtures found at #{fixtures_path}"
      puts "   Create spec/fixtures/ceasa/ and add sample PDFs to validate"
      exit 0
    end

    pdfs = Dir.glob(fixtures_path.join("*.pdf"))
    
    if pdfs.empty?
      puts "⚠️  No PDF files found in #{fixtures_path}"
      puts "   Add sample PDFs to validate the mapping"
      exit 0
    end

    puts "Validating against #{pdfs.count} sample PDFs..."
    puts ""

    core_unmapped = []
    tail_unmapped = []
    total_rows = 0
    total_unmapped = 0

    pdfs.each do |pdf_path|
      filename = File.basename(pdf_path)
      
      begin
        bulletin = CeasaRio::Parser.new(pdf_path).parse
        matcher = CeasaRio::VariantMatcher.new
        
        bulletin.rows.each do |row|
          total_rows += 1
          variant = matcher.match(row, market: "ceasa-rj")
          
          unless variant
            total_unmapped += 1
            msg = "#{filename} | §#{row.section} #{row.raw_product} | #{row.raw_tipo} | #{row.raw_unit}"
            
            if CoreBasket.includes_raw?(row)
              core_unmapped << msg
            else
              tail_unmapped << msg
            end
          end
        end
      rescue => e
        puts "❌ Error parsing #{filename}: #{e.message}"
        next
      end
    end

    puts "\n📊 Validation Results:"
    puts "   Total rows parsed: #{total_rows}"
    puts "   Total unmapped: #{total_unmapped}"
    puts "   Core basket unmapped: #{core_unmapped.count}"
    puts "   Long-tail unmapped: #{tail_unmapped.count}"
    puts ""

    if tail_unmapped.any?
      puts "Long-tail pending (acceptable in v1):"
      tail_unmapped.first(20).each { |m| puts "  ℹ️  #{m}" }
      puts "  ... and #{tail_unmapped.count - 20} more" if tail_unmapped.count > 20
      puts ""
    end

    if core_unmapped.any?
      puts "❌ CORE BASKET UNMAPPED (BLOCKER):"
      core_unmapped.each { |m| puts "  ❌ #{m}" }
      puts ""
      puts "Fix these mappings in db/seeds/product_maps.rb before proceeding."
      exit 1
    end

    puts "✅ Core basket 100% mapped!"
    puts "   (#{tail_unmapped.count} long-tail stragglers → will route to pending_matches)"
  end
end
