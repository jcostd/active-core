class UsersQuery < ApplicationQuery
  private
    def default_relation
      User.all
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      scope.where(
        "users.first_name LIKE :term OR users.last_name LIKE :term OR users.email_address LIKE :term OR users.username LIKE :term",
        term: term
      )
    end

    def apply_custom_filters(scope)
      filter_by_role(scope)
    end

    def filter_by_role(scope)
      return scope if @params[:role].blank?

      scope.where(role: @params[:role])
    end
end
