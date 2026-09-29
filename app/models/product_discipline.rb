class ProductDiscipline < ApplicationRecord
  belongs_to :product, touch: true
  belongs_to :discipline, touch: true

  validates :product_id, uniqueness: {
    scope: :discipline_id,
    message: "include già questa disciplina"
  }
end
