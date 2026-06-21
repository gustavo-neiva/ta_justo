class PendingMatch < ApplicationRecord
  validates :market, :raw_product, presence: true

  scope :by_occurrence, -> { order(occurrence_count: :desc) }
  scope :for_market, ->(market) { where(market: market) }
end
