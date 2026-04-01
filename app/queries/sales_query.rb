class SalesQuery < ApplicationQuery
  private
    def default_relation
      Sale.all
    end

    def apply_custom_filters(scope)
      scope.then { |s| filter_by_payment_method(s) }
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      term = "%#{@params[:query]}%"
      scope.joins(:member).where(
        "CAST(sales.receipt_number AS TEXT) LIKE :q OR members.first_name LIKE :q OR members.last_name LIKE :q",
        q: term
      )
    end

    def filter_by_payment_method(scope)
      return scope if @params[:payment_method].blank?

      scope.where(payment_method: @params[:payment_method])
    end

    def apply_sorting(scope)
      return super if @params[:sort].present?

      scope.order(sold_on: :desc, created_at: :desc)
    end
end
