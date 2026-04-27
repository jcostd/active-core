class Product < ApplicationRecord
  include SoftDeletable, Monetizable, Refreshable

  monetize :price

  has_many :product_disciplines, dependent: :destroy
  has_many :disciplines, through: :product_disciplines
  has_many :sales, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :restrict_with_error

  enum :accounting_category, {
          institutional: "institutional",
          associative:   "associative"
        }, default: :institutional, validate: true

  normalizes :name, with: ->(n) { n.squish.titleize }

  validates :name, presence: true, uniqueness: { conditions: -> { kept } }
  validates :duration_days, numericality: { greater_than: 0, only_integer: true }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :entry_limit, numericality: { greater_than: 0, only_integer: true, allow_nil: true }

  def membership?
    associative?
  end

  def course?
    institutional?
  end

  def carnet_or_pt?
    entry_limit.present?
  end
end
