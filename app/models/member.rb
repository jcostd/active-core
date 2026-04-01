class Member < ApplicationRecord
  include FtsSearchable, SoftDeletable, Personable, HasAddress, Avatarable
  include Refreshable

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

  def compliant?(date = Date.current)
    medical_certificate_valid?(date) && membership_valid?(date)
  end

  def membership_valid?(date = Date.current)
    if memberships.loaded?
      expiry = memberships.reject(&:discarded?).filter_map(&:end_date).max
      expiry.present? && expiry >= date
    else
      memberships.kept.where("end_date >= ?", date).exists?
    end
  end

  def valid_subscription_for(discipline)
    active_subscriptions
      .joins(product: :disciplines)
      .find_by(disciplines: { id: discipline.id })
  end

  def relevant_subscriptions(date = Date.current)
    subscriptions
      .reject(&:discarded?)
      .select { |s| s.end_date && s.end_date >= (date - 30.days) }
      .sort_by { |s| s.end_date || Date.new(1970) }
      .reverse
  end

  def renewal_info_for(product)
    dates = RenewalCalculator.new(self, product, Date.current).call
    last_sub = subscriptions.kept.where(product_id: product.id).order(end_date: :desc).first
    dates.merge(last_subscription_end: last_sub&.end_date)
  end
end
