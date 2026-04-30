class Sale < ApplicationRecord
  include SoftDeletable
  include Refreshable
  include FiscalLockable, Monetizable, Trackable
  include Sale::Filterable

  monetize :amount

  belongs_to :member, touch: true
  belongs_to :user
  belongs_to :product

  belongs_to :subscription, optional: true, autosave: true, touch: true
  accepts_nested_attributes_for :subscription, reject_if: :all_blank

  after_discard   :discard_subscription_if_empty
  after_undiscard :undiscard_subscription

  validate :require_active_membership_for_courses, on: :create

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

    def discard_subscription_if_empty
      return unless subscription.present?
      return if subscription.discarded?
      return if subscription.sales.kept.where.not(id: id).exists?
      subscription.discard!
    end

    def undiscard_subscription
      subscription.undiscard! if subscription.present? && subscription.discarded?
    end

    def require_active_membership_for_courses
      return if product.nil? || product.associative?
      return unless subscription&.start_date

      unless member.membership_valid?(subscription.start_date)
        errors.add(:base, "Impossibile vendere #{product.name}: " \
                          "Il socio non avrà una Quota Associativa attiva " \
                          "il #{I18n.l(subscription.start_date)}.")
      end
    end
end
