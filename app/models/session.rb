class Session < ApplicationRecord
  IDLE_TIMEOUT      = 1.hour
  KIOSK_TIMEOUT     = 30.days
  ACTIVITY_INTERVAL = 1.minute

  belongs_to :user

  scope :expired, -> {
    where(kiosk: false, updated_at: ...IDLE_TIMEOUT.ago).or(where(updated_at: ...KIOSK_TIMEOUT.ago))
  }

  def self.sweep = expired.delete_all

  def self.find_resumable(id)
    joins(:user).merge(User.kept).find_by(id:)
  end

  def expired?(kiosk_request: false)
    updated_at < (kiosk_request ? KIOSK_TIMEOUT : IDLE_TIMEOUT).ago
  end

  # throttled: at most one write per ACTIVITY_INTERVAL
  def record_activity!(kiosk_request: false)
    return if updated_at > ACTIVITY_INTERVAL.ago && (kiosk? || !kiosk_request)

    update_columns(updated_at: Time.current, kiosk: kiosk? || kiosk_request)
  end
end
