class UsersQuery < ApplicationQuery
  private
    def default_relation
      User.all
    end

    def apply_custom_filters(scope)
      filter_by_role(scope)
    end

    def filter_by_role(scope)
      return scope if @params[:role].blank?
      scope.where(role: @params[:role])
    end
end
