# nota operativa di una lezione privata: chi l'ha tenuta e per chi, nomi scritti a mano (non per forza staff o soci)
class PrivateLesson < ApplicationRecord
  include MonthlyRegister
  include Refreshable
  include PrivateLesson::Filterable

  DURATIONS = [ 30, 45, 60, 90, 120 ].freeze

  belongs_to :recorded_by, class_name: "User"

  normalizes :teacher, with: ->(name) { ProperCase.person(name) }
  normalizes :athletes, with: ->(names) { Array(names).filter_map { ProperCase.person(it) }.uniq }
  normalizes :held_at, with: ->(time) { time.change(sec: 0) }
  normalizes :note, with: ->(note) { note.strip.presence }

  validates :teacher, :held_at, presence: true
  validates :athletes, presence: { message: "deve contenere almeno un nome" }
  validates :duration_minutes, inclusion: { in: DURATIONS }
  validates :note, length: { maximum: 500 }
  validate :month_open

  scope :in_month, ->(date) { where(held_at: date.to_date.in_time_zone.all_month) }

  # suggerimenti per l'autocompletamento: i nomi usati nell'ultimo anno, i più frequenti prima
  def self.teacher_names
    by_frequency(where(held_at: 1.year.ago..).pluck(:teacher)) | User.kept.operators.order(:first_name).pluck(:full_name)
  end

  def self.athlete_names
    by_frequency(where(held_at: 1.year.ago..).pluck(:athletes).flatten)
  end

  def self.by_frequency(names) = names.tally.sort_by { |name, count| [ -count, name ] }.map(&:first)

  def editable_by?(user) = self.class.editable_by?(user, held_at)

  def ends_at = held_at + duration_minutes.minutes

  private
    # chi scrive (o corregge) deve poter toccare sia il mese nuovo sia quello di prima
    def month_open
      return unless held_at && recorded_by

      if held_at.to_date.beginning_of_month > self.class.current_month
        errors.add(:held_at, "è in un mese non ancora iniziato")
      elsif [ held_at, held_at_in_database ].compact.any? { !self.class.editable_by?(recorded_by, it) }
        errors.add(:held_at, "è in un mese chiuso: solo un amministratore può correggerlo")
      end
    end
end
