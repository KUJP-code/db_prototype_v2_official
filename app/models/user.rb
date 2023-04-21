# frozen_string_literal: true

# Represents a user
# Access changes based on role
# Can be customer, school manager, area manager or admin
class User < ApplicationRecord
  # Allow use of separate fields to ensure consistent name formatting
  attr_accessor :first_name, :family_name, :kana_first, :kana_family

  has_many :managements, foreign_key: :manager_id,
                         inverse_of: :manager,
                         dependent: :destroy
  has_many :managed_schools, through: :managements,
                             source: :manageable,
                             source_type: 'School'
  has_many :school_children, through: :managed_schools,
                             source: :children
  has_many :school_events, -> { order(start_date: :asc) }, through: :managed_schools,
                                                           source: :events
  has_many :managed_areas, through: :managements,
                           source: :manageable,
                           source_type: 'Area'
  has_many :area_schools, through: :managed_areas,
                          source: :schools
  has_many :area_events, -> { order(start_date: :asc) }, through: :area_schools,
                                                         source: :events
  has_many :area_children, through: :area_schools,
                           source: :children
  has_many :children, dependent: nil,
                      foreign_key: :parent_id,
                      inverse_of: :parent
  accepts_nested_attributes_for :children, allow_destroy: true
  validates_associated :children
  has_many :invoices, through: :children
  has_many :registrations, through: :children
  has_many :schools, -> { distinct }, through: :children
  has_many :areas, -> { distinct }, through: :schools
  has_many :time_slots, through: :registrations,
                        source: :registerable,
                        source_type: 'TimeSlot'
  has_many :registered_options, through: :registrations,
                                source: :registerable,
                                source_type: 'Option'
  has_many :events, -> { order(start_date: :asc).distinct }, through: :time_slots

  # Set full name from submitted first and last names
  before_validation :set_name, :set_kana

  # Make sure children are deleted when Parent is
  before_destroy :destroy_children

  # Track changes with PaperTrail
  has_paper_trail

  # Allow export/import with postgres-copy
  acts_as_copy_target

  # Validations
  validates :name, :katakana_name, presence: true
  validates :katakana_name, format: { with: /\A[ァ-ヶヶヶ ]+\z/ }
  
  validates :email, confirmation: true

  validates :phone, format: { with: /\A[0-9 \-+x.)(]+\Z/ }

  validates :pin, length: { is: 4 }, allow_blank: true

  # Map role integer in db to a string
  enum :role, customer: 0,
              school_manager: 1,
              area_manager: 2,
              admin: 3,
              default: :customer

  # Scopes for each role
  scope :customers, -> { where(role: :customer) }
  scope :area_managers, -> { where(role: :area_manager) }
  scope :school_managers, -> { where(role: :school_manager) }
  scope :admins, -> { where(role: :admin) }

  # Scope for User#show TODO: Optimise properly once the view is finalised
  scope :user_show, lambda { |param_id|
    where(id: param_id).includes(:children,
                                 :events,
                                 :registrations,
                                 :time_slots,
                                 :registered_options,
                                 :managed_schools,
                                 :managed_areas)
                       .first
  }

  # Include default devise modules. Others available are:
  # :confirmable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :timeoutable,
         :recoverable, :rememberable, :validatable, :lockable

  # Public methods
  # Finds the list of events at their children's schools
  def children_events
    child_schools = children.map(&:school_id).uniq
    Event.all.where(school_id: child_schools).order(:start_date)
  end

  # Checks if User has children
  def children?
    return false if children.empty?

    true
  end

  def opt_registrations
    registrations.where(registerable_type: 'Option')
  end

  def slot_registrations
    registrations.where(registerable_type: 'TimeSlot')
  end

  # Checks if User is a member of staff
  def staff?
    admin? || area_manager? || school_manager?
  end

  private

  def destroy_children
    children.destroy_all
  end

  def set_kana
    # Guard clause should never happen in prod because required field, but does
    # when directly modifying after creation in seeds file
    return if kana_first.nil? && kana_family.nil?

    self.katakana_name = [kana_first.strip, kana_family.strip].join(' ')
  end

  def set_name
    # Guard clause should never happen in prod because required field, but does
    # when directly modifying after creation in seeds file
    return if first_name.nil? && family_name.nil?

    self.name = [first_name.strip, family_name.strip].join(' ')
  end
end
