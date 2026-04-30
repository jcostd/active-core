# Copyright (C) 2026 Jacopo Costantini <jacopocostantini32@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

class AccessLog < ApplicationRecord
  include Refreshable
  include AccessLog::Filterable

  DOUBLE_TAP_TIMEOUT = 10.minutes
  KIOSK_COOLDOWN     = 60.minutes

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

  scope :valid_entries,    -> { where(access_logs: { status: [ :ok, :warning ] }) }
  scope :today,            -> { where(access_logs: { entered_at: Time.current.all_day }) }
  scope :recent_for_kiosk, -> { where("access_logs.entered_at >= ?", KIOSK_COOLDOWN.ago) }

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
           .where("entered_at >= ?", DOUBLE_TAP_TIMEOUT.ago)
           .exists?
        errors.add(:base, "Check-in già effettuato negli ultimi #{DOUBLE_TAP_TIMEOUT.in_minutes.to_i} minuti.")
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
