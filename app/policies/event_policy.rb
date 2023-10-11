# frozen_string_literal: true

# Handles authorisation for events
class EventPolicy < ApplicationPolicy
  def show?
    staff_or_parent?(user, record)
  end

  def new?
    user.admin?
  end

  def edit?
    user.admin?
  end

  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy
    user.admin?
  end

  # Handles authorisation for event index scopes
  # attendance sheets handled by the controller
  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        Event.all.order(start_date: :desc).includes(:school).with_attached_image
      when 'area_manager'
        user.area_events.includes(:school).with_attached_image
      when 'school_manager'
        user.school_events.includes(:school).with_attached_image
      else
        user.schools.first.events.with_attached_image
      end
    end
  end

  private

  def staff_or_parent?(user, record)
    user.staff? || user.id == record.parent_id
  end
end
