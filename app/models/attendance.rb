# presenza nel registro mensile di una disciplina: l'istruttore smarca chi vede, una volta al mese
class Attendance < ApplicationRecord
  include Refreshable

  belongs_to :member
  belongs_to :discipline
  belongs_to :marked_by, class_name: "User"

  normalizes :month, with: ->(date) { date.beginning_of_month }

  before_validation -> { self.month ||= Date.current }, on: :create

  validates :month, presence: true
  validates :member, uniqueness: { scope: %i[discipline_id month], message: "è già nel registro di questo mese" }
  validate :markable, on: :create

  scope :in_month, ->(date) { where(month: date.to_date.beginning_of_month) }

  # nessun abbonamento non annullato della disciplina tocca il mese: frequenta senza essere iscritto
  scope :unenrolled, -> {
    where.not(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM subscriptions
        JOIN product_disciplines ON product_disciplines.product_id = subscriptions.product_id
        WHERE subscriptions.member_id = attendances.member_id
          AND product_disciplines.discipline_id = attendances.discipline_id
          AND subscriptions.discarded_at IS NULL
          AND subscriptions.start_date <= date(attendances.month, '+1 month', '-1 day')
          AND subscriptions.end_date >= attendances.month
      )
    SQL
  }

  def self.current_month = Date.current.beginning_of_month

  # il mese in corso lo corregge chiunque faccia l'appello, i mesi chiusi solo l'admin, quelli futuri nessuno
  def self.editable_by?(user, month)
    month = month.to_date.beginning_of_month
    month == current_month || (user.admin? && month < current_month)
  end

  def editable_by?(user) = self.class.editable_by?(user, month)

  private
    def markable
      errors.add(:member, "è archiviato") if member&.discarded?
      errors.add(:discipline, "è archiviata") if discipline&.discarded?
      return unless month && marked_by

      if month > self.class.current_month
        errors.add(:month, "non è ancora iniziato")
      elsif !editable_by?(marked_by)
        errors.add(:month, "è chiuso: solo un amministratore può correggerlo")
      end
    end
end
