module DateRangeable
  extend ActiveSupport::Concern

  included do
    scope :active_at, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
    scope :active, -> { active_at(Date.current) }
    scope :expired, -> { where("end_date < ?", Date.current) }
    scope :upcoming, -> { where("start_date > ?", Date.current) }

    validates :start_date, :end_date, presence: true
    validate :end_date_after_start_date
  end

  def active?(date = Date.current)
    return false unless start_date && end_date
    date.between?(start_date, end_date)
  end

  def future?
    start_date.present? && start_date > Date.current
  end

  def expired?(date = Date.current)
    end_date.present? && end_date < date
  end

  def days_left
    return false unless end_date
    (end_date - Date.current).to_i
  end

  def expiring_soon?
    !future? && days_left.between?(0, 7)
  end

  private
    def end_date_after_start_date
      if start_date && end_date && end_date < start_date
        errors.add(:end_date, "deve essere successiva o uguale alla data di inizio")
      end
    end
end
