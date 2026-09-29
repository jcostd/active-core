module Discipline::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "name_asc"     => { name: :asc },
    "name_desc"    => { name: :desc },
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc }
  }.freeze

  included do
    include Sortable

    scope :search_text, ->(query) { where("disciplines.name LIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }
  end

  class_methods do
    def apply_filters(params = {})
      kept.search_text(params[:query]).sorted_by(params[:sort])
    end
  end
end
