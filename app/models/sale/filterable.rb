module Sale::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?

      term = "%#{query}%"
      joins(:member, :product).where(
        "CAST(sales.receipt_number AS TEXT) LIKE :q " \
        "OR members.first_name LIKE :q " \
        "OR members.last_name LIKE :q " \
        "OR products.name LIKE :q",
        q: term
      )
    }

    scope :by_payment_method, ->(method) {
      where(sales: { payment_method: method }) if method.present?
    }

    scope :by_product, ->(product_id) {
      where(sales: { product_id: product_id }) if product_id.present?
    }

    scope :sorted_by, ->(param, has_query: false) {
      case param
      when "name_asc"     then joins(:product).order(products: { name: :asc })
      when "name_desc"    then joins(:product).order(products: { name: :desc })
      when "created_asc"  then order(sales: { created_at: :asc })
      when "created_desc" then order(sales: { created_at: :desc })
      else
        if param.blank?
          order(sales: { sold_on: :desc, created_at: :desc })
        else
          has_query ? all : order(sales: { updated_at: :desc })
        end
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = params[:state] == "discarded" ? discarded : kept

      has_query = params[:query].present?
      scope = scope.search_text(params[:query]) if has_query

      scope = scope.by_payment_method(params[:payment_method])
                   .by_product(params[:product_id])

      scope.sorted_by(params[:sort], has_query: has_query)
    end
  end
end
