class ProductDiscipline < ApplicationRecord
  belongs_to :product, touch: true
  belongs_to :discipline, touch: true

  validates :product_id, uniqueness: {
    scope: :discipline_id,
    message: "already includes this discipline"
  }

  validates :product, :discipline, presence: true
end
