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

  # Retail pieces per CEASA pack, when the pack text states them:
  # "Preg 16 kg/8 unid" → 8, "Preg 8 kg / 8 cab" → 8, "Ama 0,5 kg / 10 mol" → 10.
  COUNT = /(\d+)\s*(?:unid|cab|mol)\b/i.freeze

  def self.count(raw_unit)
    n = raw_unit.to_s.match(COUNT)&.[](1).to_i
    n.positive? ? n : nil
  end

  # "Unid" / "Unid 2,0 kg": the modal is already the price of ONE piece
  # (the kg is the piece's typical weight, not the pack weight).
  def self.single_unit?(raw_unit)
    raw_unit.to_s.strip.match?(/\AUnid\b/i)
  end
end
