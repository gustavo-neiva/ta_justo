class Product < ApplicationRecord
  has_many :variants, dependent: :destroy
  has_many :product_aliases, dependent: :destroy
  has_many :product_maps, dependent: :destroy
  belongs_to :default_variant, class_name: "Variant", optional: true

  validates :name, :slug, :category, :section, presence: true
  validates :slug, uniqueness: true

  CATEGORIES = %w[fruta hortalica ovo peixe].freeze
  validates :category, inclusion: { in: CATEGORIES }

  before_validation :generate_slug, if: -> { slug.blank? }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
