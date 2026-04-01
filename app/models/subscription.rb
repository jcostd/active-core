class Subscription < ApplicationRecord
  include SoftDeletable, DateRangeable

  belongs_to :member, touch: true
  belongs_to :product

  has_many :sales, inverse_of: :subscription, dependent: :nullify
  has_many :access_logs, dependent: :nullify

  before_validation :apply_business_rules, on: :create

  def days_left
    (end_date - Date.current).to_i
  end

  def active?(date = Date.current)
    start_date <= date && end_date >= date
  end

  def future?
    start_date > Date.current
  end

  def expired?(date = Date.current)
    end_date < date
  end

  def days_difference(date = Date.current)
    (date - end_date).to_i.abs
  end

  def expiring_soon?
    !future? && days_left.between?(0, 7)
  end

  def assign_smart_dates(manual_start_date: nil)
    self.start_date = manual_start_date if manual_start_date.present?
    apply_business_rules
  end

  def amount_paid
    sales.reject(&:discarded?).sum(&:amount_cents)
  end

  def fully_paid?
    amount_paid >= product.price_cents
  end

  def unlimited_entries?
    entry_limit.nil? || entry_limit.zero?
  end

  private
    def apply_business_rules
      return unless product.present? && member.present?

      self.entry_limit ||= product.respond_to?(:entry_limit) ? product.entry_limit : nil

      return if end_date.present?

      if start_date.blank?
        reference_date = sales.first&.sold_on || Date.current
        self.start_date = RenewalCalculator.new(member, product, reference_date).call
      end

      result = Duration.new(product, start_date).calculate

      self.start_date = result[:start_date]
      self.end_date   = result[:end_date]
    end
end
