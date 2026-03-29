class MembersQuery
  def initialize(params = {}, relation = Member.all)
    @params = params
    @relation = relation
  end

  def results
    @relation
      .then { |scope| filter_by_state(scope) }       # 1. Filtra Attivi/Archiviati
      .then { |scope| filter_by_search(scope) }      # 2. Testo libero
      .then { |scope| filter_by_membership(scope) }  # 3. Stato Tesseramento
      .then { |scope| filter_by_med_cert(scope) }    # 4. Certificato Medico
      .then { |scope| apply_sorting(scope) }         # 5. Ordinamento finale
  end

  private
    def filter_by_state(scope)
      if @params[:state] == "archived"
        scope.discarded
      else
        scope.kept
      end
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?
      scope.search_text(@params[:query])
    end

    def filter_by_membership(scope)
      case @params[:membership_status]
      when "active"
        scope.joins(:memberships).where("subscriptions.end_date >= ?", Date.current).distinct
      when "expired"
        scope.joins(:memberships).where("subscriptions.end_date < ?", Date.current).distinct
      when "missing"
        scope.where.missing(:memberships)
      else
        scope
      end
    end

    def filter_by_med_cert(scope)
      case @params[:med_cert]
      when "valid"
        scope.where("medical_certificate_expiry >= ?", Date.current)
      when "expired"
        scope.where("medical_certificate_expiry < ?", Date.current)
      when "missing"
        scope.where(medical_certificate_expiry: nil)
      else
        scope
      end
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
