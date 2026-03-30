class AccessLog < ApplicationRecord
  include Refreshable

  belongs_to :member, touch: true
  belongs_to :subscription, optional: true, touch: true
  belongs_to :checkin_by_user, class_name: "User"
  belongs_to :discipline, optional: true

  before_validation :set_defaults

  validates :member, :subscription, :checkin_by_user, presence: true
  validates :entered_at, presence: true

  validate :subscription_belongs_to_member
  validate :subscription_must_be_active, on: :create

  private

    def set_defaults
      self.entered_at ||= Time.current
    end

    def subscription_belongs_to_member
      return unless subscription && member

      if subscription.member_id != member_id
        errors.add(:subscription, "does not belong to this member")
      end
    end

    def subscription_must_be_active
      return unless subscription

      check_date = entered_at&.to_date || Date.current

      unless subscription.active?(check_date)
        errors.add(:subscription, "is not active for date #{check_date}")
      end
    end
end
