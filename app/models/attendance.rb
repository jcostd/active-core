# presenza nel registro mensile di una disciplina: l'istruttore smarca chi vede, una volta al mese
class Attendance < ApplicationRecord
  include MonthlyRegister

  # kiosk e Iscritti seguono il registro della loro disciplina, la dashboard tutti
  broadcasts_refreshes_to ->(attendance) { [ attendance.discipline, :attendances ] }
  broadcasts_refreshes_to ->(_) { "attendances" }

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

  # cosa proporre alla cassa a chi frequenta senza abbonamento: la quota se manca (senza non si vende il corso),
  # altrimenti l'ultimo corso che aveva nella disciplina o il più venduto. Soci precaricati con Standing::PRELOAD
  def self.products_to_sell(attendances)
    catalog = Product.kept.popular.preload(:disciplines).to_a

    attendances.index_with do |attendance|
      member, discipline = attendance.member, attendance.discipline
      fits = if discipline.requires_membership? && !member.membership_valid?
        ->(product) { product.associative? }
      else
        ->(product) { product.institutional? && product.disciplines.include?(discipline) }
      end

      member.subscriptions.select { it.kept? && it.product.kept? && fits.(it.product) }.max_by(&:end_date)&.product || catalog.find(&fits)
    end
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
