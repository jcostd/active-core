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

  normalizes :fiscal_code, with: ->(c) { c.strip.upcase.presence }

  # casella del form: iscrizione senza CF, da completare in seguito
  attribute :fiscal_code_pending, :boolean, default: false

  has_many :sales,         dependent: :restrict_with_error
  has_many :access_logs,   dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  has_many :active_subscriptions,
           -> { active_at(Date.current).order(subscriptions: { start_date: :asc }) },
           class_name: "Subscription"

  has_many :recent_sales,
           -> { order(sales: { created_at: :desc }).limit(5) },
           class_name: "Sale"

  validates :birth_date, presence: true
  validates :fiscal_code,
            presence: { message: "non può essere lasciato in bianco: inseriscilo o spunta \"CF da completare\"" },
            unless: :fiscal_code_pending?
  validates :fiscal_code, uniqueness: { conditions: -> { kept } }, allow_nil: true
  # soci già presenti con CF errato restano modificabili: si verifica solo un CF nuovo o cambiato
  validate :fiscal_code_checksum, if: -> { fiscal_code.present? && (new_record? || will_save_change_to_fiscal_code?) }

  scope :missing_fiscal_code, -> { where(members: { fiscal_code: nil }) }
  validates :phone,
            phone: { possible: true, allow_blank: true, types: [ :mobile, :fixed_line ] }

  def fiscal_code_pending?
    super || (persisted? && fiscal_code_in_database.nil?)
  end

  def fiscal_code_checksum
    errors.add(:fiscal_code, "non è valido: controlla lettere, cifre e carattere finale") unless FiscalCode.valid?(fiscal_code)
  end

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

  def membership_valid?(date = Date.current)
    if subscriptions.loaded?
      subscriptions.any? do |s|
        s.kept? &&
        s.product&.associative? &&
        s.start_date && s.start_date <= date &&
        s.end_date && s.end_date >= date
      end
    else
      subscriptions.active_at(date)
        .joins(:product)
        .merge(Product.associative)
        .exists?
    end
  end

  # fine della copertura associativa continua a partire da date (quote consecutive sommate)
  def membership_covered_until(date)
    memberships = subscriptions.kept.joins(:product).merge(Product.associative)
                               .where(subscriptions: { end_date: date.. })
                               .order(:start_date)

    memberships.reduce(nil) do |covered, membership|
      break covered if membership.start_date > (covered ? covered + 1 : date)
      [ covered, membership.end_date ].compact.max
    end
  end

  def valid_subscription_for(discipline)
    active_subscriptions.for_discipline(discipline).first
  end

  def relevant_subscriptions(date = Date.current)
    subs = subscriptions.loaded? ? subscriptions.select(&:kept?) : subscriptions.kept.to_a

    subs.select { it.end_date && it.end_date >= date - 30.days }
        .group_by(&:product_id)
        .map { |_, product_subs| product_subs.max_by(&:end_date) }
        .sort_by(&:end_date)
        .reverse
  end
end
