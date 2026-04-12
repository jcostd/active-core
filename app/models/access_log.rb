class AccessLog < ApplicationRecord
  include Refreshable

  belongs_to :member, touch: true
  belongs_to :subscription, optional: true, touch: true
  belongs_to :checkin_by_user, class_name: "User"
  belongs_to :discipline, optional: true

  enum :status, { ok: 0, warning: 1, error: 2 }, default: :ok, validate: true

  before_validation :set_defaults
  before_validation :evaluate_access_policy, on: :create

  validates :member, :checkin_by_user, :entered_at, presence: true

  validate :prevent_double_tap, on: :create
  validate :subscription_belongs_to_member
  validate :subscription_must_be_active, on: :create, if: -> { status == "ok" }

  scope :valid_entries, -> { where(status: :ok) }

  private
    def set_defaults
      self.entered_at ||= Time.current
    end

    def evaluate_access_policy
      return unless member && discipline

      policy = AccessPolicy.new(member: member, discipline: discipline)
      policy.evaluate!

      self.status = policy.status
      self.subscription = policy.subscription
    end

    def prevent_double_tap
      return unless member_id && discipline_id

      recent_entry = AccessLog.where(member_id: member_id, discipline_id: discipline_id)
                       .where("entered_at >= ?", 10.minutes.ago)
                       .exists?

      if recent_entry
        errors.add(:base, "Check-in già effettuato negli ultimi 10 minuti.")
      end
    end

    def subscription_must_be_active
      if subscription.blank?
        errors.add(:base, "Impossibile registrare un accesso regolare senza un abbonamento attivo.")
      elsif subscription.end_date.present? && subscription.end_date < Date.current
        errors.add(:subscription, "risulta scaduto.")
      end
    end

    def subscription_belongs_to_member
      return unless subscription && member
      if subscription.member_id != member_id
        errors.add(:subscription, "non appartiene a questo socio")
      end
    end
end
