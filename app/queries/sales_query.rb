class SalesQuery < ApplicationQuery
  private
    def default_relation
      Sale.all
    end

    def apply_custom_filters(scope)
      scope
        .then { |s| filter_by_payment_method(s) }
        .then { |s| filter_by_product(s) }
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      term = "%#{@params[:query]}%"

      scope.joins(:member, :product).where(
        "CAST(sales.receipt_number AS TEXT) LIKE :q " \
        "OR members.first_name LIKE :q " \
        "OR members.last_name LIKE :q " \
        "OR products.name LIKE :q",
        q: term
      )
    end

    def filter_by_payment_method(scope)
      return scope if @params[:payment_method].blank?

      scope.where(payment_method: @params[:payment_method])
    end

    def filter_by_product(scope)
      return scope if @params[:product_id].blank?

      scope.where(product_id: @params[:product_id])
    end

    def apply_sorting(scope)
      return scope.order(sold_on: :desc, created_at: :desc) if @params[:sort].blank?

      case @params[:sort]
      when "name_asc"
        scope.joins(:product).order("products.name ASC")
      when "name_desc"
        scope.joins(:product).order("products.name DESC")
      else
        super
      end
    end
end
