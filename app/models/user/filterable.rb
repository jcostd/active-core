module User::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "updated_desc" => { updated_at: :desc },
    "name_asc"     => { last_name: :asc, first_name: :asc },
    "name_desc"    => { last_name: :desc, first_name: :desc },
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc }
  }.freeze

  included do
    include Sortable

    scope :search_text, ->(query) {
      where("users.first_name LIKE :q OR users.last_name LIKE :q OR users.username LIKE :q",
            q: "%#{sanitize_sql_like(query)}%") if query.present?
    }

    scope :with_role, ->(role) { where(role:) if role.in?(roles.keys) }
  end

  class_methods do
    def apply_filters(params = {})
      kept.search_text(params[:query]).with_role(params[:role]).sorted_by(params[:sort])
    end
  end
end
