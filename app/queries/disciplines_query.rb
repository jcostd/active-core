class DisciplinesQuery < ApplicationQuery
  private
    def default_relation
      Discipline.all
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "name_desc"    then scope.order(name: :desc)
      when "created_asc"  then scope.order(created_at: :asc)
      when "created_desc" then scope.order(created_at: :desc)
      when "name_asc"     then scope.order(name: :asc)
      else
        @params[:query].present? ? scope : scope.order(name: :asc)
      end
    end
end
