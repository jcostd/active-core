module Discipline::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?

      where("disciplines.name LIKE :q", q: "%#{query}%")
    }

    scope :sorted_by, ->(param, has_query = false) {
      case param
      when "name_asc"     then order(disciplines: { name: :asc })
      when "name_desc"    then order(disciplines: { name: :desc })
      when "created_asc"  then order(disciplines: { created_at: :asc })
      when "created_desc" then order(disciplines: { created_at: :desc })
      else
        has_query ? all : order(disciplines: { name: :asc })
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = kept

      scope = scope.search_text(params[:query]) if params[:query].present?

      scope.sorted_by(params[:sort], params[:query].present?)
    end
  end
end
