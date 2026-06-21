class Price < ApplicationRecord
  belongs_to :bulletin
  belongs_to :variant

  validates :section, presence: true
  validates :variant_id, uniqueness: { scope: :bulletin_id }

  scope :with_per_kg, -> { where.not(price_per_kg: nil) }
  scope :last_n_months, ->(n) { 
    joins(:bulletin).where("bulletins.price_date >= ?", n.months.ago) 
  }
end
