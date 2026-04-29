module Product::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?

      where("products.name LIKE :q", q: "%#{query}%")
    }

    scope :with_accounting_category, ->(category) {
      where(products: { accounting_category: category })
    }

    scope :sorted_by, ->(param, has_query = false) {
      case param
      when "name_asc"     then order(products: { name: :asc })
      when "name_desc"    then order(products: { name: :desc })
      when "price_asc"    then order(products: { price_cents: :asc })
      when "price_desc"   then order(products: { price_cents: :desc })
      when "created_asc"  then order(products: { created_at: :asc })
      when "created_desc" then order(products: { created_at: :desc })
      else
        has_query ? all : order(products: { created_at: :desc })
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = kept

      scope = scope.search_text(params[:query]) if params[:query].present?

      scope = case params[:accounting_category]
              when "institutional" then scope.with_accounting_category(:institutional)
              when "associative"   then scope.with_accounting_category(:associative)
              else scope
              end

      scope.sorted_by(params[:sort], params[:query].present?)
    end
  end
end
