# frozen_string_literal: true

# Represents an individual child's registration for either time slot or option
# Must have a child, and the registered time slot/option
class Registration < ApplicationRecord
  # Ensure option registrations are destroyed when the registration for their time slot is
  before_destroy :destroy_registered_options, if: :slot_registration?

  # List associations
  belongs_to :child
  belongs_to :registerable, polymorphic: true
  delegate :event, to: :registerable
  delegate :area, to: :event
  delegate :school, to: :registerable
  delegate :parent, to: :child

  # Set scopes for registerable type
  scope :slot_registrations, -> { where(registerable_type: 'TimeSlot') }
  scope :option_registrations, -> { where(registerable_type: 'Option') }

  private

  def slot_registration?
    return true if registerable_type == 'TimeSlot'

    false
  end

  def destroy_registered_options
    child = self.child
    slot_options = registerable.options
    reg_opt = Registration.joins(:child).where(child: child).option_registrations.where(registerable: slot_options)
    reg_opt.destroy_all
  end
end
