# frozen_string_literal: true

# Represents a child, or student, enrolled at a school and/or attending an event
# Must have a parent, and a school
class Child < ApplicationRecord
  belongs_to :parent, class_name: 'User', optional: true
  belongs_to :school, optional: true
  delegate :area, to: :school
  has_many :registrations, dependent: :destroy
  has_many :time_slots, through: :registrations,
                        source: :registerable,
                        source_type: 'TimeSlot'
  has_many :options, through: :registrations,
                     source: :registerable,
                     source_type: 'Option'
  has_many :events, through: :time_slots

  # Map level integer in table to a level
  enum :level, unknown: 0,
               kindy: 1,
               land_low: 2,
               land_high: 3,
               sky_low: 4,
               sky_high: 5,
               galaxy_low: 6,
               galaxy_high: 7,
               keep_up: 8,
               specialist: 9,
               tech_up: 10

  # Map category int in table to a category
  enum :category, internal: 0,
                  reservation: 1,
                  external: 2

  # Validations
  validates :ja_first_name, :ja_family_name, :katakana_name, :en_name, :post_photos, presence: true

  validates :ja_first_name, :ja_family_name, format: { with: /[一-龠]+|[ぁ-ゔ]+|[ァ-ヴー]+|[々〆〤ヶ]+/u }
  validates :katakana_name, format: { with: /[ァ-ヴー]/u }
  validates :en_name, format: { with: /[A-Za-z '-]/ }

  validates :birthday, comparison: { greater_than: 13.years.ago, less_than: 2.years.ago }
  validates :ssid, uniqueness: true

  # Scopes for broad levels
  scope :elementary, -> { where(level: [2, 3, 4, 5, 6, 7, 8, 9, 10]) }
  scope :evening_only, -> { where(level: [8, 9, 10]) }
  scope :land, -> { where(level: [2, 3]) }
  scope :sky, -> { where(level: [4, 5]) }
  scope :galaxy, -> { where(level: [5, 6]) }

  # TODO: Do this with ActiveRecord, not select
  def diff_school_events
    events.reject { |event| event.school == school }
  end
end
