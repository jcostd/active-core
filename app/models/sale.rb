class Sale < ApplicationRecord
  include SubscriptionIssuer, FiscalLockable, Monetizable, Trackable, SoftDeletable

  monetize :amount

  belongs_to :member
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

  def prepare_draft(options = {})
    self.sold_on ||= Date.current
    build_subscription unless subscription

    if options[:renew_subscription_id].present? && member.present?
      old_sub = member.subscriptions.find_by(id: options[:renew_subscription_id])
      if old_sub
        self.product = old_sub.product
        self.amount = product&.price if amount.blank? || amount.zero?
      end
    end

    if product_id.present? && (amount.blank? || amount.zero?)
      self.amount = product.price
    end

    # 1. Passiamo alla Subscription le associazioni necessarie per fargli fare i calcoli
    sync_subscription_data

    # 2. Tell, Don't Ask: Diciamo alla Subscription di calcolare le sue date,
    # passandole l'eventuale forzatura dell'utente dal form.
    subscription.assign_smart_dates(manual_start_date: options[:manual_start_date])
  end

  private
    def sync_subscription_data
      return unless subscription.present? && member.present? && product.present?
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
