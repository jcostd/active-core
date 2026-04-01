class UsersQuery < ApplicationQuery
  private
    def default_relation
      User.all
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      term = "%#{@params[:query]}%"
      scope.where(
        "users.first_name LIKE :q OR users.last_name LIKE :q OR users.email_address LIKE :q OR users.username LIKE :q",
        q: term
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
