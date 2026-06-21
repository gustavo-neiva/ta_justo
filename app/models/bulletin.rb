class Bulletin < ApplicationRecord
  has_many :prices, dependent: :destroy

  validates :market, :price_date, :source_url, presence: true
  validates :price_date, uniqueness: { scope: :market }
  validates :source_url, uniqueness: true
end
