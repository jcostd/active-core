class Member < ApplicationRecord
  include FtsSearchable, SoftDeletable, Personable, HasAddress, Avatarable

  normalizes :fiscal_code, with: ->(c) { c.strip.upcase }

  has_many :sales, dependent: :restrict_with_error
  has_many :access_logs, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  has_many :active_subscriptions, -> { kept.where("end_date >= ?", Date.current).order(:start_date) }, class_name: "Subscription"
  has_many :recent_sales, -> { order(created_at: :desc).limit(5) }, class_name: "Sale"

  has_many :memberships, -> { joins(:product).merge(Product.associative) },
           class_name: "Subscription"

  validates :birth_date, presence: true
  validates :fiscal_code,
            presence: true,
            uniqueness: { conditions: -> { kept } },
            format: { with: /\A[A-Z0-9]{16}\z/ }
  validates :phone, phone: { possible: true, allow_blank: true, types: [ :mobile, :fixed_line ] }

  def medical_certificate_valid?(date = Date.current)
    medical_certificate_expiry.present? && medical_certificate_expiry >= date
  end

  def membership_valid?(date = Date.current)
    expiry = memberships.kept.maximum(:end_date)
    expiry.present? && expiry >= date
  end

  def compliant?(date = Date.current)
    medical_certificate_valid?(date) && membership_valid?(date)
  end

  def relevant_subscriptions(date = Date.current)
    subscriptions
      .kept
      .where("end_date >= ?", date - 30.days)
      .order(end_date: :desc)
  end

  def renewal_info_for(product)
    dates = RenewalCalculator.new(self, product, Date.current).call
    last_sub = subscriptions.kept.where(product_id: product.id).order(end_date: :desc).first
    dates.merge(last_subscription_end: last_sub&.end_date)
  end
end
