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

  attr_accessor :reference_date

  monetize :agreed_price

  belongs_to :member,  touch: true
  belongs_to :product
  has_many :sales,       inverse_of: :subscription, dependent: :nullify
  has_many :access_logs, dependent: :nullify

  validates :start_date, :end_date, presence: true
  validates :agreed_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_after_start_date
  validate :agreed_price_covers_payments, on: :update, if: :will_save_change_to_agreed_price_cents?

  before_validation :apply_business_rules,     on: :create
  before_validation :set_default_agreed_price, on: :create

  validate :prevent_overlapping_subscriptions, if: :period_changed?

  after_discard :discard_sales

  scope :active_at, ->(date) { kept.where(subscriptions: { start_date: ..date, end_date: date.. }) }
  scope :memberships, -> { joins(:product).merge(Product.associative) }
  scope :overlapping, ->(period) { where(subscriptions: { start_date: ..period.last.to_date, end_date: period.first.to_date.. }) }

  # rinnovato: stesso socio, un altro abbonamento che parte e finisce dopo questo,
  # nella stessa disciplina (o stesso prodotto, o entrambe quote associative)
  RENEWAL_EXISTS = <<~SQL.squish
    EXISTS (
      SELECT 1 FROM subscriptions renewals
      JOIN products renewal_products ON renewal_products.id = renewals.product_id
      JOIN products current_products ON current_products.id = subscriptions.product_id
      WHERE renewals.member_id = subscriptions.member_id
        AND renewals.id <> subscriptions.id
        AND renewals.discarded_at IS NULL
        AND renewals.start_date > subscriptions.start_date
        AND renewals.end_date > subscriptions.end_date
        AND (
          renewals.product_id = subscriptions.product_id
          OR (current_products.accounting_category = 'associative' AND renewal_products.accounting_category = 'associative')
          OR EXISTS (
            SELECT 1 FROM product_disciplines current_links
            JOIN product_disciplines renewal_links ON renewal_links.discipline_id = current_links.discipline_id
            WHERE current_links.product_id = subscriptions.product_id
              AND renewal_links.product_id = renewals.product_id
          )
        )
    )
  SQL

  scope :renewed,     -> { where(RENEWAL_EXISTS) }
  scope :not_renewed, -> { where.not(RENEWAL_EXISTS) }
  scope :expiring,    -> {
    kept.joins(:member).merge(Member.kept)
        .where(subscriptions: { end_date: Date.current..Date.current + 7 })
        .not_renewed
  }

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

  def renewed?
    return @renewed if defined?(@renewed)

    @renewed = persisted? && Subscription.renewed.exists?(id)
  end

  # una sola query per un'intera lista invece di una per riga
  def self.preload_renewed(records)
    records = records.to_a
    renewed_ids = renewed.where(id: records.map(&:id)).pluck(:id).to_set
    records.each { it.instance_variable_set(:@renewed, renewed_ids.include?(it.id)) }
  end

  def reload(*)
    remove_instance_variable(:@renewed) if defined?(@renewed)
    @status = nil
    super
  end

  def amount_due
    [ agreed_price_cents.to_i - amount_paid, 0 ].max
  end

  def fully_paid?
    amount_paid >= agreed_price_cents
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

      return if end_date.present?

      period = if start_date
        Duration.for(product, start_date)
      else
        member.next_period_for(product, from: reference_date || Array(sales).filter_map(&:sold_on).first || Date.current)
      end
      self.start_date, self.end_date = period.start_date, period.end_date
    end

    def set_default_agreed_price
      return unless product.present?
      self.agreed_price_cents ||= product.price_cents
    end

    def period_changed?
      new_record? || will_save_change_to_start_date? || will_save_change_to_end_date? || will_save_change_to_product_id?
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

    # abbuono: il prezzo si abbassa per chiudere un debito, mai sotto quanto già incassato
    def agreed_price_covers_payments
      return unless agreed_price_cents && agreed_price_cents < amount_paid

      errors.add(:agreed_price, "non può essere inferiore a quanto già incassato " \
                                "(#{ActiveSupport::NumberHelper.number_to_currency(amount_paid / 100.0)})")
    end

    def end_date_after_start_date
      if start_date && end_date && end_date < start_date
        errors.add(:end_date, "deve essere successiva o uguale alla data di inizio")
      end
    end
end
