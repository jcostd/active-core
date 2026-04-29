class Discipline < ApplicationRecord
  include SoftDeletable
  include Refreshable
  include Discipline::Filterable

  has_many :product_disciplines, dependent: :destroy
  has_many :products, through: :product_disciplines

  has_many :subscriptions, through: :products

  has_many :access_logs, dependent: :nullify

  normalizes :name, with: ->(n) { n.squish.titleize }
  validates :name, presence: true, uniqueness: { conditions: -> { kept } }

  def recent_subscriptions
    subscriptions
      .kept
      .where("subscriptions.end_date >= ?", 30.days.ago)
      .includes(:member, :product)
  end
end
