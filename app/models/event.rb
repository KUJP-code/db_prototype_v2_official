# frozen_string_literal: true

class Event < ApplicationRecord
  def self.summary_json(names)
    names.index_with do |name|
      Event.where(name:).map(&:to_gas_summary)
    end
  end

  attr_reader :sibling_events

  belongs_to :school
  delegate :area, to: :school
  belongs_to :member_prices, class_name: 'PriceList',
                             optional: true
  belongs_to :non_member_prices, class_name: 'PriceList',
                                 optional: true

  has_many :time_slots, dependent: :destroy
  has_many :event_merch_items, dependent: :destroy
  has_many :merch_items, through: :event_merch_items
  accepts_nested_attributes_for :time_slots, allow_destroy: true,
                                             reject_if: :all_blank
  has_many :options, as: :optionable,
                     dependent: :destroy
  has_many :event_option_regs, through: :options,
                               source: :registrations
  accepts_nested_attributes_for :options, allow_destroy: true,
                                          reject_if: :all_blank
  has_many :slot_options, through: :time_slots,
                          source: :options
  has_many :option_registrations, through: :time_slots
  has_many :registrations, through: :time_slots
  has_many :invoices, -> { real },
           dependent: :destroy,
           inverse_of: :event
  has_many :children, -> { distinct }, through: :invoices

  has_one_attached :image
  has_one_attached :avif

  has_rich_text :description

  paginates_per 40

  validates :name, :start_date, :end_date, :early_bird_date, presence: true

  validates_comparison_of :early_bird_discount, less_than_or_equal_to: 0
  validates_comparison_of :end_date, greater_than_or_equal_to: :start_date
  validates_comparison_of :goal, less_than: 2_147_483_647

  # Scopes
  scope :real, -> { where.not(school_id: [1, 2]) }
  scope :upcoming, -> { where('end_date > ?', Time.zone.now) }

  def avif_id
    return nil if avif.blob.nil?

    avif.blob.id
  end

  def avif_id=(avif_id)
    return if avif_id.nil?

    self.avif = ActiveStorage::Blob.find(avif_id)
  end

  # List children attending from other schools
  def diff_school_children
    children.where.not(school:).distinct
  end

  def image_id
    return nil if image.blob.nil?

    image.blob.id
  end

  def image_id=(image_id)
    return if image_id.nil?

    self.image = ActiveStorage::Blob.find(image_id)
  end

  def party?
    early_bird_discount.negative?
  end

  # Free regs from siblings being registered not included
  def photo_regs
    options.sum(:registrations_count)
  end

  def price_list_for(child)
    price_list = child.member? ? member_prices : non_member_prices
    price_list.courses
  end

  def seasonal?
    early_bird_discount.zero?
  end

  def to_gas_summary
    external_kids = children.external
    internal_kids = children.internal
    reservation_kids = children.reservation

    {
      school_id:,
      internal_count: internal_kids.count,
      internal_revenue: Invoice.where(event_id: id, child_id: internal_kids.ids).sum(:total_cost),
      external_count: external_kids.count,
      external_revenue: Invoice.where(event_id: id, child_id: external_kids.ids).sum(:total_cost),
      reservation_count: reservation_kids.count,
      reservation_revenue: Invoice.where(event_id: id,
                                         child_id: reservation_kids.ids).sum(:total_cost),
      total_revenue: invoices.sum(:total_cost),
      goal:
    }
  end

  def with_sibling_events
    @sibling_events = Event.where(name:)
                           .where.not(school_id: 2)
                           .includes(:school)
    self
  end
end
