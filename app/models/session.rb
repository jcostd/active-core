class Session < ApplicationRecord
  IDLE_TIMEOUT      = 1.hour
  KIOSK_TIMEOUT     = 30.days
  ACTIVITY_INTERVAL = 1.minute

  belongs_to :user

  scope :expired, -> {
    where(updated_at: ...IDLE_TIMEOUT.ago).where.not(user: User.kiosk).or(where(updated_at: ...KIOSK_TIMEOUT.ago))
  }

  def self.sweep = expired.delete_all

  def self.find_resumable(id)
    joins(:user).merge(User.kept).includes(:user).find_by(id:)
  end

  # l'iPad del kiosk resta collegato, tutti gli altri escono dopo un'ora di inattività
  def timeout = user.kiosk? ? KIOSK_TIMEOUT : IDLE_TIMEOUT

  def expired? = updated_at < timeout.ago

  # al massimo una scrittura ogni ACTIVITY_INTERVAL
  def record_activity!
    update_columns(updated_at: Time.current) unless updated_at > ACTIVITY_INTERVAL.ago
  end
end
