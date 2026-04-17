class ApplicationQuery
  def initialize(params = {}, relation = default_relation)
    @params = params
    @relation = relation
  end

  def results
    @relation
      .then { |scope| filter_by_state(scope) }
      .then { |scope| filter_by_search(scope) }
      .then { |scope| apply_custom_filters(scope) }
      .then { |scope| apply_sorting(scope) }
  end

  private
    def default_relation
      raise NotImplementedError, "Le sottoclassi devono definire default_relation"
    end

    def apply_custom_filters(scope)
      scope
    end

    def filter_by_state(scope)
      return scope.discarded if @params[:state] == "discarded"

      scope.kept
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?
      scope.search_text(@params[:query])
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "created_asc"  then scope.order(created_at: :asc)
      when "name_asc"     then scope.order(last_name: :asc, first_name: :asc)
      when "name_desc"    then scope.order(last_name: :desc, first_name: :desc)
      when "created_desc" then scope.order(created_at: :desc)
      else
        @params[:query].present? ? scope : scope.order(created_at: :desc)
      end
    end
end
