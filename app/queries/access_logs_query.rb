class AccessLogsQuery < ApplicationQuery
  private
    def default_relation
      AccessLog.all
    end

    def filter_by_state(scope)
      scope
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?

      matching_members = Member.search_text(@params[:query])
      scope.where(member_id: matching_members.select(:id))
    end

    def apply_custom_filters(scope)
      scope
        .then { |s| filter_by_status(s) }
        .then { |s| filter_by_discipline(s) }
    end

    def filter_by_status(scope)
      return scope if @params[:status].blank?
      scope.where(status: @params[:status])
    end

    def filter_by_discipline(scope)
      return scope if @params[:discipline_id].blank?
      scope.where(discipline_id: @params[:discipline_id])
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "date_asc"  then scope.order(entered_at: :asc)
      when "date_desc" then scope.order(entered_at: :desc)
      else
        scope.order(entered_at: :desc)
      end
    end
end
