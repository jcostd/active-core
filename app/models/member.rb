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

class Member < ApplicationRecord
  include FtsSearchable, SoftDeletable, Personable, HasAddress, Avatarable
  include Refreshable
  include Member::Filterable

  RENEWAL_GRACE_PERIOD = 30

  normalizes :fiscal_code, with: ->(c) { c.strip.upcase }

  has_many :sales,         dependent: :restrict_with_error
  has_many :access_logs,   dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  has_many :active_subscriptions,
           -> { truly_active.order(subscriptions: { start_date: :asc }) },
           class_name: "Subscription"

  has_many :recent_sales,
           -> { order(sales: { created_at: :desc }).limit(5) },
           class_name: "Sale"

  validates :birth_date, presence: true
  validates :fiscal_code,
            presence: true,
            uniqueness: { conditions: -> { kept } },
            format: { with: /\A[A-Z0-9]{16}\z/ }
  validates :phone,
            phone: { possible: true, allow_blank: true, types: [ :mobile, :fixed_line ] }

  def suggested_start_date_for(product, reference_date = Date.current, last_sub: nil)
    reference_date = reference_date.to_date
    last_sub     ||= subscriptions.kept
                       .where(product:)
                       .order(subscriptions: { end_date: :desc })
                       .first

    return reference_date unless last_sub && last_sub.end_date

    continuity_date = last_sub.end_date.next_day
    gap_days        = (reference_date - continuity_date).to_i
    gap_days <= RENEWAL_GRACE_PERIOD ? continuity_date : reference_date
  end

  def medical_certificate_valid?(date = Date.current)
    medical_certificate_expiry.present? && medical_certificate_expiry >= date
  end

  def compliant?(date = Date.current)
    medical_certificate_valid?(date) && membership_valid?(date)
  end

  def membership_valid?(date = Date.current)
    if subscriptions.loaded?
      subscriptions.any? do |s|
        s.kept? &&
        s.product&.associative? &&
        s.start_date && s.start_date <= date &&
        s.end_date && s.end_date >= date &&
          (s.entry_limit.nil? || s.entry_limit.zero? || s.entries_used < s.entry_limit)
      end
    else
      subscriptions.truly_active_at(date)
        .joins(:product)
        .merge(Product.associative)
        .exists?
    end
  end

  def valid_subscription_for(discipline)
    active_subscriptions.for_discipline(discipline).first
  end

  def relevant_subscriptions(date = Date.current)
    subs = subscriptions.loaded? ? subscriptions.select(&:kept?) : subscriptions.kept.to_a

    subs
      .select { |s| s.end_date && s.end_date >= (date - 30.days) }
      .group_by(&:product_id)
      .map { |_, product_subs|
      product_subs.max_by(&:end_date)
    }
      .sort_by(&:end_date)
      .reverse
  end

  def relevant_subscriptions_from_loaded(date = Date.current)
    return relevant_subscriptions(date) unless subscriptions.loaded?

    subscriptions
      .select { |s| s.kept? && s.end_date && s.end_date >= (date - 30.days) }
      .sort_by { |s| s.end_date || Date.new(1970) }
      .reverse
  end

  def renewal_info_for(product)
    last_sub = subscriptions.kept
                            .where(product:)
                            .order(subscriptions: { end_date: :desc })
                            .first
    {
      start_date:            suggested_start_date_for(product, last_sub:),
      last_subscription_end: last_sub&.end_date
    }
  end
end
