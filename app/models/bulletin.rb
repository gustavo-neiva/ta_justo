class Bulletin < ApplicationRecord
  has_many :prices, dependent: :destroy

  validates :market, :price_date, :source_url, presence: true
  validates :price_date, uniqueness: { scope: :market }
  validates :source_url, uniqueness: true

  # The public CEASA PDF link is a pure function of the date — derive it for
  # display so legacy `local-archive:` placeholders (and any future ingest that
  # stores one) still render the real bulletin URL without a data repair.
  def pdf_url
    CeasaRio::Fetcher.new.url_for(price_date)
  end
end
