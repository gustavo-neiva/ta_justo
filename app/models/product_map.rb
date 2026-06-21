class ProductMap < ApplicationRecord
  belongs_to :product
  belongs_to :variant

  validates :market, :section, :raw_product, presence: true
  validates :raw_product, uniqueness: { 
    scope: [:market, :section, :raw_tipo],
    message: "mapping already exists for this market/section/product/tipo combination"
  }

  # Ensure raw_tipo is never nil (use empty string)
  before_validation :normalize_raw_tipo

  private

  def normalize_raw_tipo
    self.raw_tipo = "" if raw_tipo.nil?
  end
end
