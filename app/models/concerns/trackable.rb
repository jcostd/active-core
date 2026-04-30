module Trackable
  extend ActiveSupport::Concern

  IGNORED_FIELDS = %w[
    updated_at
    created_at
    password_digest
    discarded_at
  ].freeze

  included do
    has_many :activity_logs, as: :subject, dependent: :destroy

    after_create_commit  :track_create
    after_update_commit  :track_update
    after_destroy_commit :track_destroy

    after_discard   :track_discard   rescue nil
    after_undiscard :track_undiscard rescue nil
  end

  def log_activity(action, changes = {})
    return unless Current.user

    activity_logs.create!(
      user:        Current.user,
      action:      action,
      changes_set: changes
    )
  end

  private

    def track_create
      return unless Current.user

      activity_logs.create!(
        user:        Current.user,
        action:      "created",
        changes_set: sanitized_attributes
      )
    end

    def track_update
      return unless Current.user

      relevant = sanitized_changes
      return if relevant.blank?

      activity_logs.create!(
        user:        Current.user,
        action:      "updated",
        changes_set: relevant
      )
    end

    def track_destroy
      return unless Current.user

      activity_logs.create!(
        user:        Current.user,
        action:      "destroyed",
        changes_set: sanitized_attributes
      )
    end

    def track_discard
      return unless Current.user
      return unless respond_to?(:discarded_at)

      activity_logs.create!(
        user:        Current.user,
        action:      "discarded",
        changes_set: {}
      )
    end

    def track_undiscard
      return unless Current.user
      return unless respond_to?(:discarded_at)

      activity_logs.create!(
        user:        Current.user,
        action:      "restored",
        changes_set: {}
      )
    end

    def sanitized_changes
      previous_changes.except(*IGNORED_FIELDS)
    end

    def sanitized_attributes
      attributes.except(*IGNORED_FIELDS)
    end
end
