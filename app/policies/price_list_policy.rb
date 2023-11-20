# frozen_string_literal: true

# Handles authorization for price lists
class PriceListPolicy < ApplicationPolicy
  def index?
    user.admin?
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
    user.admin?
  end

  def destroy?
    user.admin?
  end
end
