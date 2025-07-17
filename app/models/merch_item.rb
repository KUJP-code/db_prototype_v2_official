class MerchItem < ApplicationRecord

  has_many :event_merch_items, dependent: :destroy
  has_many :events, through: :event_merch_items
  has_many :registrations, as: :registerable, dependent: :destroy

  has_one_attached :image
  has_one_attached :avif

  validates :name, :cost, presence: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }

  def closed?
    closed || (close_at && close_at <= Time.current) || (stock && stock <= 0)
  end

  def purchasable?(qty = 1)
    stock.nil? || stock >= qty
  end

  def decrement_stock!(qty = 1)
    update!(stock: stock - qty) if stock
  end

  def description
    metadata['description']
  end

  def description=(value)
    self.metadata ||= {}
    self.metadata['description'] = value
  end
end
