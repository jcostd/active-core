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
    self.member_id ||= options[:preset_member_id]

    build_subscription unless subscription

    if options[:autosubmit]
      reset_draft_if_changed(options[:previous_product_id], options[:previous_member_id])
    elsif options[:renew_subscription_id].present?
      apply_renewal_template(options[:renew_subscription_id])
    end

    if product_id.present? && (amount.blank? || amount.zero?)
      self.amount = product.price
    end

    sync_subscription_data
    subscription.assign_smart_dates(manual_start_date: options[:manual_start_date])
  end

  private
    def reset_draft_if_changed(prev_product, prev_member)
      if prev_product.to_s != product_id.to_s || prev_member.to_s != member_id.to_s
        self.amount = nil
        subscription.start_date = nil
      end
    end

    def apply_renewal_template(renew_id)
      old_sub = Subscription.find_by(id: renew_id)
      return unless old_sub

      self.product_id ||= old_sub.product_id
      self.member_id  ||= old_sub.member_id

      subscription.start_date = old_sub.end_date >= Date.current ? (old_sub.end_date + 1.day) : Date.current
    end

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
