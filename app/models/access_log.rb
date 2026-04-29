class AccessLog < ApplicationRecord
  include Refreshable
  include AccessLog::Filterable

  belongs_to :member,           touch: true
  belongs_to :subscription,     optional: true, touch: true
  belongs_to :checkin_by_user,  class_name: "User"
  belongs_to :discipline,       optional: true

  enum :status, { ok: 0, warning: 1, error: 2 }, default: :ok, validate: true

  before_validation :set_defaults
  before_validation :evaluate_access_policy, on: :create

  before_destroy :cache_valid_entry_state

  after_create_commit  :increment_entries_used
  after_destroy_commit :decrement_entries_used

  validates :member, :checkin_by_user, :entered_at, presence: true

  validate :prevent_double_tap,            on: :create
  validate :subscription_belongs_to_member

  scope :valid_entries, -> { where(status: [ :ok, :warning ]) }

  private

    def set_defaults
      self.entered_at ||= Time.current
    end

    def evaluate_access_policy
      return unless member && discipline

      policy = AccessPolicy.new(member: member, discipline: discipline).evaluate!
      self.status       = policy.status
      self.subscription = policy.subscription
    end

    def prevent_double_tap
      return unless member_id && discipline_id

      if AccessLog.where(member_id: member_id, discipline_id: discipline_id)
                  .where("entered_at >= ?", 10.minutes.ago)
                  .exists?
        errors.add(:base, "Check-in già effettuato negli ultimi 10 minuti.")
      end
    end

    def subscription_belongs_to_member
      return unless subscription_id
      if subscription&.member_id != member_id
        errors.add(:subscription, "non appartiene a questo socio")
      end
    end

    def cache_valid_entry_state
      @was_valid_entry = ok? || warning?
    end

    def increment_entries_used
      return unless subscription_id && (ok? || warning?)

      Subscription.where(id: subscription_id)
                  .update_all("entries_used = entries_used + 1")
    end

    def decrement_entries_used
      return unless subscription_id && @was_valid_entry

      Subscription.where(id: subscription_id)
                  .where("entries_used > 0")
                  .update_all("entries_used = entries_used - 1")
    end
end
