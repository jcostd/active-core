class Sale < ApplicationRecord
  include SubscriptionIssuer, FiscalLockable, Monetizable, Trackable, SoftDeletable
  include Refreshable

  monetize :amount

  belongs_to :member, touch: true
  belongs_to :user
  belongs_to :product

  enum :payment_method, {
         cash: 1, credit_card: 2, bank_transfer: 3, other: 4
       }, default: :credit_card, validate: true

  validates :sold_on, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :member, :user, :product, presence: true
  validates :receipt_sequence, presence: true

  before_validation :snapshot_product_details
  before_validation :sync_subscription_data
  before_validation :assign_receipt_number, on: :create

  private
    def sync_subscription_data
      return unless subscription.present? && subscription.new_record? && member.present? && product.present?
      subscription.member ||= self.member
      subscription.product ||= self.product
    end

    def snapshot_product_details
      return unless product.present?

      self.product_name_snapshot = product.name
      self.amount_cents = product.price_cents if amount_cents.nil? || amount_cents.zero?
      self.receipt_sequence ||= product.accounting_category
    end

    def assign_receipt_number
      return unless cash?
      return if receipt_number.present? && receipt_year.present?

      self.receipt_year ||= sold_on&.year || Date.current.year
      if receipt_year.present? && receipt_sequence.present?
        self.receipt_number = ReceiptCounter.next_number(receipt_year, receipt_sequence)
      end
    end
end
