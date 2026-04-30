module AccessLog::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?

      matching_members = Member.search_text(query).select("members.id")
      where(access_logs: { member_id: matching_members })
    }

    scope :with_status, ->(status) {
      where(access_logs: { status: status })
    }

    scope :for_discipline, ->(discipline_id) {
      where(access_logs: { discipline_id: discipline_id })
    }

    scope :sorted_by, ->(param) {
      case param
      when "date_asc"  then order(access_logs: { entered_at: :asc })
      when "date_desc" then order(access_logs: { entered_at: :desc })
      else                  order(access_logs: { entered_at: :desc })
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = all

      scope = scope.search_text(params[:query]) if params[:query].present?
      scope = scope.with_status(params[:status]) if params[:status].present?
      scope = scope.for_discipline(params[:discipline_id]) if params[:discipline_id].present?

      scope.sorted_by(params[:sort])
    end
  end
end
