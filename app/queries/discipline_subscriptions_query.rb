class DisciplineSubscriptionsQuery < ApplicationQuery
  private
    def default_relation
      raise ArgumentError, "Richiesta la relation base (es. @discipline.recent_subscriptions)"
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      scope.joins(:member).merge(Member.search_text(@params[:query]))
    end

    def apply_custom_filters(scope)
      scope
        .then { |s| filter_by_product(s) }
    end

    def filter_by_product(scope)
      return scope if @params[:product_id].blank?

      scope.where(product_id: @params[:product_id])
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "expiring_asc"  then scope.order(end_date: :asc)
      when "expiring_desc" then scope.order(end_date: :desc)
      when "recent"        then scope.order(created_at: :desc)
      else
        @params[:query].present? ? scope : scope.order(end_date: :asc)
      end
    end
end
