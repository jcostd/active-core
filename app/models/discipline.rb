class Discipline < ApplicationRecord
  include SoftDeletable
  include Refreshable
  include Discipline::Filterable

  has_many :product_disciplines, dependent: :destroy
  has_many :products, through: :product_disciplines

  has_many :subscriptions, through: :products

  has_many :attendances, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { ProperCase.title(name) }
  validates :name, presence: true, uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :requires_membership, :requires_medical_certificate, inclusion: { in: [ true, false ] }
end
