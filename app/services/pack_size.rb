# Extracts the net weight (in kg) from a CEASA-RJ raw_unit string.
#
# Used by representative-row selection to pick the smallest retail pack
# (Plan §3.1) — the single deterministic rule that replaces the ad-hoc
# "first by date" choice scattered across verdict / controller / stats.
#
# Pure function: raw_unit → Float (kg) or nil. No DB, no side effects.
class PackSize
  # Matches the first "<number> kg" token, tolerating Brazilian decimal
  # commas, missing prefix ("0,5kg"), uppercase ("SC 30 KG"), and trailing
  # pack-count annotations ("Cx 1,2 kg / 4 cambucas").
  NUMBER_KG = /(\d+(?:[.,]\d+)?)\s*kg/i.freeze

  def self.kg(raw_unit)
    return nil if raw_unit.blank?

    match = raw_unit.match(NUMBER_KG)
    return nil unless match

    match[1].tr(",", ".").to_f
  end
end
