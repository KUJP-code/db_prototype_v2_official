# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    staff_or_parent?(user, record)
  end

  def new?
    return false if user.statistician?

    true
  end

  def create?
    staff_or_parent?(user, record)
  end

  def update?
    staff_or_parent?(user, record)
  end

  def destroy?
    user.staff?
  end

  def confirm?
    staff_or_parent?(user, record)
  end

  def confirmed?
    true
  end

  def copy?
    staff_or_parent?(user, record)
  end

  def merge?
    user.staff?
  end

  def seen?
    user.staff?
  end

  def permitted_attributes
    always_permit = [
      :id, :child_id, :event_id,
      { slot_regs_attributes: %i[id child_id _destroy invoice_id
                                 registerable_id registerable_type],
        opt_regs_attributes: %i[id child_id _destroy invoice_id
                                registerable_id registerable_type],
        merch_regs_attributes: %i[id child_id _destroy invoice_id
                                  registerable_id registerable_type],
        coupons_attributes: [:code] }
    ]
    return always_permit if user.customer?
    return nil unless user.staff?

    always_permit + [
      :in_ss, :entered, :email_sent,
      { adjustments_attributes: %i[id reason change invoice_id _destroy] }
    ]
  end

  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        scope.all
      when 'area_manager'
        scope.where(event_id: user.area_events.ids)
      when 'school_manager'
        scope.where(event_id: user.school_events.ids)
      when 'customer'
        scope.where(id: user.invoices.ids)
      else
        scope.none
      end
    end
  end

  private

  def staff_or_parent?(user, record)
    user.staff? || user.children.ids.include?(record.child_id)
  end
end
