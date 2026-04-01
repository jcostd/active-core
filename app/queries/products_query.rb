class ProductsQuery < ApplicationQuery
  private
    def default_relation
      Product.all
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      scope.where("products.name LIKE ?", "%#{@params[:query]}%")
    end

    def apply_custom_filters(scope)
      scope
        .then { |s| filter_by_category(s) }
    end

    def filter_by_category(scope)
      return scope if @params[:accounting_category].blank?

      scope.where(accounting_category: @params[:accounting_category])
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "name_asc"     then scope.order(name: :asc)
      when "name_desc"    then scope.order(name: :desc)
      when "price_asc"    then scope.order(price_cents: :asc)
      when "price_desc"   then scope.order(price_cents: :desc)
      when "created_asc"  then scope.order(created_at: :asc)
      when "created_desc" then scope.order(created_at: :desc)
      else
        @params[:query].present? ? scope : scope.order(name: :asc)
      end
    end
end
