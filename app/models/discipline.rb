class Discipline < ApplicationRecord
  include SoftDeletable
  include Refreshable

  has_many :product_disciplines, dependent: :destroy
  has_many :products, through: :product_disciplines
  has_many :access_logs, dependent: :nullify

  normalizes :name, with: ->(n) { n.squish.titleize }
  validates :name, presence: true, uniqueness: { conditions: -> { kept } }

  def recent_subscriptions
    Subscription.kept
      .where(product_id: product_ids)
      .where("end_date >= ?", 30.days.ago)
      .includes(:member, :product)
      .order(end_date: :asc)
  end
end
