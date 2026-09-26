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

class Subscription < ApplicationRecord
  include SoftDeletable, Monetizable
  include Subscription::Filterable

  attr_accessor :reference_date

  monetize :agreed_price

  belongs_to :member,  touch: true
  belongs_to :product
  has_many :sales,       inverse_of: :subscription, dependent: :nullify
  has_many :access_logs, dependent: :nullify

  validates :start_date, :end_date, presence: true
  validates :agreed_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :end_date_after_start_date

  before_validation :apply_business_rules,     on: :create
  before_validation :set_default_agreed_price, on: :create

  validate :prevent_overlapping_subscriptions, on: :create

  after_discard :discard_sales

  scope :active,   -> { where(subscriptions: { start_date: ..Date.current, end_date: Date.current.. }) }
  scope :expired,  -> { where(subscriptions: { end_date: ...Date.current }) }
  scope :upcoming, -> { where(subscriptions: { start_date: (Date.current + 1.day).. }) }

  scope :truly_active_at, ->(date) {
    kept
      .where(subscriptions: { start_date: ..date, end_date: date.. })
      .where("subscriptions.entry_limit IS NULL OR subscriptions.entry_limit = 0 OR subscriptions.entries_used < subscriptions.entry_limit")
  }

  scope :truly_active,   -> { truly_active_at(Date.current) }

  scope :for_discipline, ->(discipline) {
    joins(product: :disciplines).where(disciplines: { id: discipline.id })
  }

  def status
    @status ||= SubscriptionStatus.new(self)
  end

  def amount_paid
    if sales.loaded?
      sales.reject(&:discarded?).sum(&:amount_cents)
    else
      sales.kept.sum(:amount_cents)
    end
  end

  # archiviabile solo se ogni pagamento è ancora annullabile da user
  def discardable_by?(user)
    return false if discarded?

    payments = kept_sales
    payments.empty? ? user.admin? : payments.all? { it.reversible_by?(user) }
  end

  def amount_due
    [ agreed_price_cents.to_i - amount_paid, 0 ].max
  end

  def fully_paid?
    amount_paid >= agreed_price_cents
  end

  def unlimited_entries?
    entry_limit.nil? || entry_limit.zero?
  end

  def entries_used
    unlimited_entries? ? 0 : self[:entries_used]
  end

  def entries_remaining
    return nil if unlimited_entries?
    [ entry_limit - entries_used, 0 ].max
  end

  def out_of_entries?
    !unlimited_entries? && entries_used >= entry_limit
  end

  def future?
    start_date.present? && start_date > Date.current
  end

  def expired?(date = Date.current)
    end_date.present? && end_date < date
  end

  def days_left
    return nil unless end_date
    (end_date - Date.current).to_i
  end

  def expiring_soon?
    return false unless end_date
    return false if out_of_entries?
    !future? && days_left&.between?(0, 7) || false
  end

  private
    def kept_sales
      sales.loaded? ? sales.reject(&:discarded?) : sales.kept.to_a
    end

    def discard_sales
      sales.kept.each(&:discard!)
    end

    def apply_business_rules
      return unless product.present? && member.present?

      self.entry_limit ||= product.entry_limit
      return if end_date.present?

      if start_date.blank?
        ref_date = self.reference_date || Array(sales).map(&:sold_on).compact.first || Date.current
        self.start_date = member.suggested_start_date_for(product, ref_date)
      end

      duration        = Duration.for(product, start_date)
      self.start_date = duration.start_date
      self.end_date   = duration.end_date
    end

    def set_default_agreed_price
      return unless product.present?
      self.agreed_price_cents ||= product.price_cents
    end

    def prevent_overlapping_subscriptions
      return unless member && product
      return unless start_date && end_date

      if member.subscriptions.kept
           .where(product_id: product.id)
           .where.not(id: id)
           .where(subscriptions: { start_date: ..end_date, end_date: start_date.. })
           .exists?
        errors.add(:base, "Già un abbonamento per '#{product.name}' in queste date.")
      end
    end

    def end_date_after_start_date
      if start_date && end_date && end_date < start_date
        errors.add(:end_date, "deve essere successiva o uguale alla data di inizio")
      end
    end
end
