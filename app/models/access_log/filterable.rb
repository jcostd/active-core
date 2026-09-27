module AccessLog::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "date_desc" => { entered_at: :desc },
    "date_asc"  => { entered_at: :asc }
  }.freeze

  included do
    include Sortable

    scope :search_text, ->(query) { where(member_id: Member.search_text(query).select("members.id")) if query.present? }
    scope :with_status, ->(status) { where(status:) if status.in?(statuses.keys) }
    scope :for_discipline, ->(discipline_id) { where(discipline_id:) if discipline_id.present? }
  end

  class_methods do
    def apply_filters(params = {})
      search_text(params[:query]).with_status(params[:status]).for_discipline(params[:discipline_id]).sorted_by(params[:sort])
    end
  end
end
