module User::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?

      term = "%#{query}%"
      where(
        "users.first_name LIKE :q OR users.last_name LIKE :q OR users.email_address LIKE :q OR users.username LIKE :q",
        q: term
      )
    }

    scope :with_role, ->(role) {
      where(users: { role: role })
    }

    scope :sorted_by, ->(param) {
      case param
      when "name_asc"     then order(users: { last_name: :asc, first_name: :asc })
      when "name_desc"    then order(users: { last_name: :desc, first_name: :desc })
      when "username_asc" then order(users: { username: :asc })
      when "created_asc"  then order(users: { created_at: :asc })
      when "created_desc" then order(users: { created_at: :desc })
      else                     order(users: { updated_at: :desc })
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = kept

      scope = scope.search_text(params[:query]) if params[:query].present?

      scope = case params[:role]
              when "admin" then scope.with_role(:admin)
              when "staff" then scope.with_role(:staff)
              else scope
              end

      scope.sorted_by(params[:sort])
    end
  end
end
