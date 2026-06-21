# One-off blast-radius check (Plan §3.1).
# Counts how many multi-pack verdicts would flip if we switch the representative
# row to the smallest retail pack. Run in dev with:
#   bin/rails runner script/check_verdict_flips.rb
# Small/expected -> ship. Large/surprising -> scrutinise PackSize parsing.

flips = 0
checked = 0
multi_pack = 0

Variant.where(pricing_mode: %w[per_kg per_unit]).find_each do |v|
  # Bulletins that have >1 distinct raw_unit (i.e. multi-pack) for this variant
  multi_bulletin_ids = v.prices.joins(:bulletin)
    .group("bulletins.id")
    .having(Arel.sql("COUNT(DISTINCT prices.raw_unit) > 1"))
    .pluck("bulletins.id")
  next if multi_bulletin_ids.empty?

  multi_pack += 1
  bid = multi_bulletin_ids.max # latest multi-pack bulletin
  bulletin = Bulletin.find(bid)

  # OLD rule: first row by (no explicit order, ad-hoc) — emulate as the SQL
  # default insertion order the controller used (id ASC among same date).
  old_row = v.prices.where(bulletin: bulletin).order(:id).first
  # NEW rule: smallest retail pack via PackSize.
  new_row = v.representative_price(bulletin: bulletin)

  next unless old_row && new_row && old_row.price_per_kg && new_row.price_per_kg

  checked += 1
  flips += 1 if old_row.price_per_kg != new_row.price_per_kg
end

puts "Multi-pack variants: #{multi_pack}"
puts "Multi-pack bulletins checked: #{checked}"
puts "Verdict-relevant price changes (old ≠ new): #{flips}"
