class Subscription < ApplicationRecord
  include SoftDeletable, DateRangeable

  belongs_to :member, touch: true
  belongs_to :sale, inverse_of: :subscription, touch: true
  belongs_to :product

  validates :member, :product, :sale, presence: true

  before_validation :apply_business_rules, on: :create

  def days_left
    (end_date - Date.current).to_i
  end

  def future?
    start_date > Date.current
  end

  def expired?
    days_left < 0
  end

  def expiring_soon?
    !future? && days_left.between?(0, 7)
  end

  def assign_smart_dates(manual_start_date: nil)
    self.start_date = manual_start_date if manual_start_date.present?
    apply_business_rules
  end

  private
    def apply_business_rules
      return unless product.present? && member.present?

      return if end_date.present?

      if start_date.blank?
        reference_date = sale&.sold_on || Date.current
        self.start_date = RenewalCalculator.new(member, product, reference_date).call
      end

      result = Duration.new(product, start_date).calculate

      self.start_date = result[:start_date]
      self.end_date   = result[:end_date]
    end
end
