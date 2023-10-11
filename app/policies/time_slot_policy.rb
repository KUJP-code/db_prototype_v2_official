# frozen_string_literal: true

# Handles authorisation for TimeSlots
class TimeSlotPolicy < ApplicationPolicy
  def index?
    user.staff?
  end

  def show?
    user.admin?
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
    user.admin? || user.area_manager?
  end

  # Handles scopes for TimeSlot index
  class Scope < Scope
    def resolve
      case user.role
      when :admin
        School.all
      when :area_manager
        user.area_schools
      end
    end
  end
end
