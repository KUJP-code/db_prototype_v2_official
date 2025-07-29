# frozen_string_literal: true

class Invoice < ApplicationRecord
  include InvoiceCalculatable
  include InvoicePdfable
  include InvoiceSummarisable

  before_save :update_regs_child
  before_save :calc_cost, unless: :in_ss?
  belongs_to :child
  delegate :parent, to: :child
  delegate :school, to: :child
  belongs_to :event

  has_many :registrations, dependent: :destroy
  accepts_nested_attributes_for :registrations
  has_many :merch_regs, -> { where(registerable_type: 'MerchItem') },
           class_name: 'Registration',
           inverse_of: :invoice,
           dependent: :destroy
  accepts_nested_attributes_for :merch_regs, allow_destroy: true
  has_many :slot_regs, -> { where(registerable_type: 'TimeSlot') },
           class_name: 'Registration',
           dependent: :destroy,
           inverse_of: :invoice
  accepts_nested_attributes_for :slot_regs, allow_destroy: true
  has_many :opt_regs, -> { where(registerable_type: 'Option') },
           class_name: 'Registration',
           dependent: :destroy,
           inverse_of: :invoice

  accepts_nested_attributes_for :opt_regs, allow_destroy: true,
                                           reject_if: :orphan_option?
  has_many :time_slots, through: :slot_regs,
                        source: :registerable,
                        source_type: 'TimeSlot'
  has_many :options, through: :opt_regs,
                     source: :registerable,
                     source_type: 'Option'

  has_many :merch_items, through: :merch_regs,
                         source: :registerable,
                         source_type: 'MerchItem'

  has_many :adjustments, dependent: :destroy
  accepts_nested_attributes_for :adjustments, allow_destroy: true
  has_many :coupons, as: :couponable,
                     dependent: :destroy
  accepts_nested_attributes_for :coupons, reject_if: :blank_or_dup

  # Track changes with Paper Trail
  has_paper_trail unless: proc { |t| t.in_ss || t.seen_at || t.entered || t.email_sent }

  # Allow export/import with postgres-copy
  acts_as_copy_target

  # Scopes
  # Only invoices with at least one time slot/option registered
  scope :real, -> { where('registrations_count > 0') }
  scope :for_registration_page,
        lambda { |event|
          where(event_id: event)
            .includes(:adjustments, :opt_regs, :registrations,
                      :slot_regs, :time_slots)
        }

  # Validations
  validates :total_cost,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def calc_cost
    generate_data
    self.total_cost = @data[:total_cost]
    self.summary = generate_summary(@data)
    @data
  end

  def id_and_cost
    "##{id}, #{yenify(total_cost)}"
  end

  private

  def blank_or_dup(coupon)
    return true if coupon['code'].empty? || coupons.map(&:code).include?(coupon['code'])

    false
  end

  def update_regs_child
    return if slot_regs.empty? || slot_regs.first.child_id == child_id

    registrations.each do |reg|
      reg.update!(child_id:)
    end
  end
end
