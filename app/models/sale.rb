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

class Sale < ApplicationRecord
  include SoftDeletable
  include Refreshable
  include FiscalLockable, Monetizable, Trackable
  include Sale::Filterable

  ADMIN_REVERSAL_WINDOW = 24.hours
  STAFF_REVERSAL_WINDOW = 15.minutes

  monetize :amount

  belongs_to :member, touch: true
  belongs_to :user
  belongs_to :product

  belongs_to :subscription, optional: true, autosave: true, touch: true
  accepts_nested_attributes_for :subscription, reject_if: :all_blank

  after_discard   :discard_subscription_if_empty
  after_undiscard :undiscard_subscription

  validate :require_active_membership_for_courses, on: :create
  validate :subscription_matches_sale
  validate :zero_amount_allowed,  on: :create
  validate :amount_within_due,    on: :create

  enum :payment_method, {
         cash: 1, credit_card: 2, bank_transfer: 3, other: 4
       }, default: :credit_card, validate: true

  validates :sold_on, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :member, :user, :product, presence: true
  validates :receipt_sequence, presence: true

  before_validation :snapshot_product_details, on: :create
  before_validation :sync_subscription_data
  before_validation :assign_receipt_number, on: :create

  # staff: solo i propri pagamenti
  def reversible_by?(user)
    return false if discarded? || !(user.admin? || user_id == user.id)

    created_at > (user.admin? ? ADMIN_REVERSAL_WINDOW : STAFF_REVERSAL_WINDOW).ago
  end

  private
    def sync_subscription_data
      return unless subscription.present? && subscription.new_record? && member.present? && product.present?
      subscription.member ||= self.member
      subscription.product ||= self.product
      subscription.reference_date ||= self.sold_on
    end

    def snapshot_product_details
      return unless product.present?

      self.product_name_snapshot = product.name
      self.amount_cents ||= default_amount_cents
      self.receipt_sequence ||= product.accounting_category
    end

    # rata: residuo dovuto; nuova vendita: prezzo concordato
    def default_amount_cents
      if subscription&.persisted?
        subscription.amount_due
      else
        subscription&.agreed_price_cents || product.price_cents
      end
    end

    def assign_receipt_number
      return unless cash?
      return if receipt_number.present? && receipt_year.present?

      self.receipt_year ||= sold_on&.year || Date.current.year
      if receipt_year.present? && receipt_sequence.present?
        self.receipt_number = ReceiptCounter.next_number(receipt_year, receipt_sequence)
      end
    end

    def discard_subscription_if_empty
      return unless subscription.present?
      return if subscription.discarded?
      return if subscription.sales.kept.where.not(id: id).exists?
      subscription.discard!
    end

    def undiscard_subscription
      subscription.undiscard! if subscription.present? && subscription.discarded?
    end

    # le rate pagano un diritto già venduto: il controllo è stato fatto allora
    def require_active_membership_for_courses
      return if product.nil? || product.associative?
      return unless subscription&.new_record? && subscription.start_date

      check_date = sold_on || subscription.start_date

      unless member.membership_valid?(check_date)
        errors.add(:base, "Impossibile vendere #{product.name}: " \
                          "Il socio non avrà una Quota Associativa attiva " \
                          "il #{I18n.l(check_date)}.")
      end
    end

    def subscription_matches_sale
      return unless subscription

      errors.add(:subscription, "non appartiene a questo socio") if subscription.member_id != member_id
      errors.add(:subscription, "non corrisponde al prodotto venduto") if subscription.product_id != product_id
      errors.add(:subscription, "è stato annullato") if new_record? && subscription.discarded?
    end

    def zero_amount_allowed
      return unless amount_cents&.zero?

      if subscription&.persisted?
        errors.add(:base, "La rata deve essere maggiore di zero.")
      elsif !user&.admin?
        errors.add(:base, "Solo un amministratore può registrare una vendita a zero.")
      end
    end

    def amount_within_due
      return unless subscription && amount_cents

      due = subscription.persisted? ? subscription.amount_due : subscription.agreed_price_cents || product&.price_cents
      return if due.nil? || amount_cents <= due

      errors.add(:amount, "supera il residuo dovuto (#{format("%.2f", due / 100.0).tr(".", ",")} €)")
    end
end
