module PrivateLesson::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "held_desc" => { held_at: :desc },
    "held_asc"  => { held_at: :asc }
  }.freeze

  included do
    include Sortable

    scope :taught_by, ->(teacher) { where(teacher:) if teacher.present? }
    scope :search_text, ->(query) {
      if query.present?
        pattern = "%#{sanitize_sql_like(query.strip)}%"
        where("private_lessons.teacher LIKE :pattern OR private_lessons.athletes LIKE :pattern OR private_lessons.note LIKE :pattern", pattern:)
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      taught_by(params[:teacher]).search_text(params[:query]).sorted_by(params[:sort])
    end
  end
end
