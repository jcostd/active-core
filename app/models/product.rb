class Product < ApplicationRecord
  include SoftDeletable, Monetizable, Refreshable
  include Product::Filterable

  monetize :price

  has_many :product_disciplines, dependent: :destroy
  has_many :disciplines, through: :product_disciplines
  has_many :sales, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :restrict_with_error

  enum :accounting_category, {
          institutional: "institutional",
          associative:   "associative"
        }, default: :institutional, validate: true

  normalizes :name, with: ->(name) { ProperCase.title(name) }

  validates :name, presence: true, uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :duration_days, numericality: { greater_than: 0, only_integer: true }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :terms_fixed_once_sold, on: :update

  # i più venduti prima: la proposta di default alla cassa
  scope :popular, -> { left_joins(:subscriptions).group(:id).order(Arel.sql("COUNT(subscriptions.id) DESC"), :name) }

  # prodotti che si rinnovano a vicenda: sé stesso, quelli con una disciplina in comune e, per una quota, tutte le quote
  def same_line
    line = Product.where(id:).or(Product.where(id: ProductDiscipline.where(discipline_id: product_disciplines.select(:discipline_id)).select(:product_id)))
    associative? ? line.or(Product.associative) : line
  end

  # categoria e durata decidono date e validità degli abbonamenti già venduti: dopo la prima vendita non cambiano
  def terms_locked?
    persisted? && subscriptions.exists?
  end

  private
    def terms_fixed_once_sold
      return unless terms_locked?

      %i[accounting_category duration_days].select { will_save_change_to_attribute?(it) }.each do |attribute|
        errors.add(attribute, "non può essere cambiata: il prodotto ha già abbonamenti venduti")
      end
    end
end
