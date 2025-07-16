# frozen_string_literal: true

# Represents an individual child's registration for either time slot or option
# Must have a child, and the registered time slot/option
class Registration < ApplicationRecord
  # Ensure option registrations are destroyed when the registration for their time slot is
  before_destroy :destroy_registered_options, if: :slot_registration?

  # List associations
  belongs_to :child
  belongs_to :registerable, polymorphic: true, counter_cache: true
  belongs_to :invoice, counter_cache: true
  delegate :event, to: :registerable
  delegate :area, to: :event
  delegate :school, to: :registerable
  delegate :parent, to: :child

  # Validations
  validates :registerable_id,
            uniqueness: {
              scope: %i[child_id registerable_type],
              message: :register_once
            }

  # Set scopes for registerable type
  scope :slot_registrations, -> { where(registerable_type: 'TimeSlot') }
  scope :option_registrations, -> { where(registerable_type: 'Option') }
  scope :merch_registrations, -> { where(registerable_type: 'MerchItem')}

  def slot_registration?
    return true if registerable_type == 'TimeSlot'

    false
  end

  def merch_registration?
    registerable_type == 'MerchItem'
  end

  #  monkey patch this to cover for old delegate event/school to registerable calls.
  def event
    if merch_registration?
      invoice.event
    else
      registerable.event
    end
  end

  def school
    if merch_registration?
      invoice.event.school
    else
      registerable.school
    end
  end

  private

  def destroy_registered_options
    child = self.child
    slot_options = registerable.options
    reg_opt = Registration.joins(:child).where(child: child).option_registrations.where(registerable: slot_options)
    reg_opt.destroy_all
  end
end
