class PriceIndex < ApplicationRecord
  VALID_INDEX_NAMES = %w[ipca inpc].freeze

  validates :index_name, inclusion: { in: VALID_INDEX_NAMES }
  validates :reference_month, uniqueness: { scope: :index_name }

  # Find price index for a specific month and index_name
  scope :for_month, ->(month, index_name) { where(reference_month: month, index_name:) }

  # Find the most recent reference_month for each index_name
  scope :latest, -> {
    subquery = select(:index_name, "MAX(reference_month) as max_month").group(:index_name)
    joins("JOIN (#{subquery.to_sql}) latest ON price_indices.index_name = latest.index_name AND price_indices.reference_month = latest.max_month")
  }
end