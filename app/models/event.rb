# frozen_string_literal: true

# Represents an event at a single school, with one or many time slots
# Must have a school
class Event < ApplicationRecord
  after_save :create_afternoons

  belongs_to :school
  delegate :area, to: :school
  belongs_to :member_prices, class_name: 'PriceList',
                             optional: true
  belongs_to :non_member_prices, class_name: 'PriceList',
                                 optional: true

  has_many :time_slots, dependent: :destroy
  accepts_nested_attributes_for :time_slots, allow_destroy: true,
                                             reject_if: :all_blank
  has_many :options, as: :optionable,
                     dependent: :destroy
  has_many :slot_options, through: :time_slots,
                          source: :options
  has_many :option_registrations, through: :time_slots
  has_many :registrations, through: :time_slots
  has_many :children, -> { distinct }, through: :registrations
  has_many :invoices, dependent: :destroy

  has_one_attached :image
  has_one_attached :banner

  validates :name, :start_date, :end_date, presence: true

  validates_comparison_of :end_date, greater_than_or_equal_to: :start_date

  # Scopes for event time
  scope :past_events, -> { where('end_date < ?', Time.zone.today).order(start_date: :desc) }
  scope :current_events, -> { where('start_date <= ? and end_date >= ?', Time.zone.today, Time.zone.today) }
  scope :future_events, -> { where('start_date > ?', Time.zone.today).order(start_date: :asc) }

  # Public Methods
  # List children attending from other schools
  def diff_school_children
    children.where.not(school: school).distinct
  end

  def f_start_date
    start_date.strftime('%Y年%m月%d日')
  end

  # Returns num of registrations for the フォトサービス event option
  def photo_regs
    photo_id = options.find_by(name: 'フォトサービス').id
    direct_regs = Registration.all.where(registerable_type: 'Option', registerable_id: photo_id)
    direct_regs.size + direct_regs.reduce(0) { |sum, reg| sum + reg.child.siblings.size }
  end

  private

  def create_afternoons
    time_slots.morning.each do |m_slot|
      next unless m_slot.afternoon_slot.nil?

      m_slot.create_afternoon_slot(
        name: m_slot.name,
        start_time: m_slot.start_time + 5.hours,
        end_time: m_slot.end_time + 7.hours,
        category: m_slot.category,
        morning: false,
        event_id: m_slot.event_id
      )
    end
  end
end
