# Tá Justo? Seeds — Idempotent product/variant/map initialization
# Run with: rails db:seed or rails db:seed:replant
#
# All seeds use find_or_create_by! on natural keys → safe to re-run

puts "🌱 Seeding Tá Justo database..."

# 1. Core Basket module (loads constants)
load Rails.root.join('db/seeds/core_basket.rb')

# 2. Products & Variants (~75 products, ~248 variants)
load Rails.root.join('db/seeds/products.rb')

# 3. ProductMaps (248 CEASA-RJ tuples → canonical products)
load Rails.root.join('db/seeds/product_maps.rb')

# 4. Price Indices (IPCA + INPC full history from BCB SGS API)
load Rails.root.join('db/seeds/price_indices.rb')

puts "\n✅ Seeding complete!"
puts "   Products: #{Product.count}"
puts "   Variants: #{Variant.count}"
puts "   ProductMaps: #{ProductMap.count}"
puts "   Core basket: #{CoreBasket::SLUGS.count} products"
puts "   Price indices: #{PriceIndex.count} (IPCA: #{PriceIndex.where(index_name: 'ipca').count}, INPC: #{PriceIndex.where(index_name: 'inpc').count})"
