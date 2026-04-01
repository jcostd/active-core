class AccessLog < ApplicationRecord
  include Refreshable

  belongs_to :member, touch: true
  belongs_to :subscription, optional: true, touch: true
  belongs_to :checkin_by_user, class_name: "User"
  belongs_to :discipline, optional: true

  enum :status, { ok: 0, warning: 1, error: 2 }, default: :ok, validate: true

  before_validation :set_defaults

  validates :member, :checkin_by_user, :entered_at, presence: true

  validate :subscription_belongs_to_member
  validate :subscription_must_be_active, on: :create, if: -> { status == "ok" }

  scope :valid_entries, -> { where(status: :ok) }

  private
    def set_defaults
      self.entered_at ||= Time.current
    end

    def subscription_belongs_to_member
      return unless subscription && member
      if subscription.member_id != member_id
        errors.add(:subscription, "non appartiene a questo socio")
      end
    end
end
