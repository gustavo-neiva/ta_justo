class Price < ApplicationRecord
  belongs_to :bulletin
  belongs_to :variant

  validates :section, presence: true
   validates :variant_id, uniqueness: { scope: [:bulletin_id, :raw_unit] }

  scope :with_per_kg, -> { where.not(price_per_kg: nil) }
  scope :last_n_months, ->(n) { 
    joins(:bulletin).where("bulletins.price_date >= ?", n.months.ago) 
  }
  
  # For variants with multiple packaging sizes, prefer smaller retail packs
  # (feira shoppers buy small, not wholesale bulk)
  scope :retail_packaging, -> {
    # Prefer units with smaller kg amounts (5kg, 10kg over 18kg, 20kg)
    # Extract first number from raw_unit and sort ascending
    select("prices.*, CAST(SUBSTR(raw_unit, INSTR(raw_unit, ' ') + 1) AS DECIMAL) as pack_size")
    .order("pack_size ASC")
  }
end
