# app/models/sale.rb
class Sale < ApplicationRecord
  include SubscriptionIssuer, FiscalLockable, Monetizable, Trackable, SoftDeletable

  monetize :amount

  belongs_to :member
  belongs_to :user
  belongs_to :product

  # --- LE DUE RIGHE FONDAMENTALI PER IL FORM ---
  has_one :subscription, dependent: :destroy
  accepts_nested_attributes_for :subscription

  enum :payment_method, {
    cash: 1,
    credit_card: 2,
    bank_transfer: 3,
    other: 4
  }, default: :credit_card, validate: true

  validates :sold_on, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :member, :user, :product, presence: true
  validates :receipt_sequence, presence: true

  # CALLBACKS (L'ordine è importante!)
  before_validation :snapshot_product_details
  before_validation :sync_subscription_data # Sincronizza i dati prima di validare
  before_validation :assign_receipt_number, on: :create

  # --- LOGICA PER IL FORM LIVE (GET /sales/new) ---
  def prepare_draft(options = {})
    build_subscription unless subscription

    if options[:renew_subscription_id].present? && member.present?
      old_sub = member.subscriptions.find_by(id: options[:renew_subscription_id])
      if old_sub
        self.product = old_sub.product
        self.amount = product&.price if amount.blank? || amount.zero?
      end
    end

    if product_id.present?
      self.amount = product.price if amount.blank? || amount.zero?
    end

    apply_live_dates(options[:manual_start_date])
  end

  private

    # --- IL FIX PER IL SALVATAGGIO (POST /sales) ---
    def sync_subscription_data
      return unless subscription.present? && member.present? && product.present?

      # 1. Passa le associazioni dalla Sale alla Subscription
      subscription.member ||= self.member
      subscription.product ||= self.product

      # 2. Se dal form arriva solo la start_date, calcoliamo la end_date al volo
      if subscription.start_date.present? && subscription.end_date.blank?
        # Usiamo la tua classe Duration per calcolare la fine in base al prodotto
        result = Duration.new(self.product, subscription.start_date).calculate
        subscription.end_date = result[:end_date] if result.present?
      end
    end

    # --- LOGICA CALCOLO DATE LIVE (Per prepare_draft) ---
    def apply_live_dates(manual_start_date)
      return unless member && product

      if manual_start_date.present?
        parsed_date = Date.parse(manual_start_date) rescue Date.current
        subscription.start_date = parsed_date

        result = Duration.new(product, parsed_date).calculate
        subscription.end_date = result[:end_date] if result.present?
        return
      end

      ref_date = sold_on || Date.current
      result = RenewalCalculator.new(member, product, ref_date).call

      if result.present?
        subscription.start_date = result[:start_date]
        subscription.end_date   = result[:end_date]
      end
    end

    # --- SNAPSHOT & FISCALE ---
    def snapshot_product_details
      return unless product.present?

      self.product_name_snapshot = product.name

      if amount_cents.nil? || amount_cents.zero?
        self.amount_cents = product.price_cents
      end

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
