class DisciplineSubscriptionsQuery < ApplicationQuery
  private
    def default_relation
      raise ArgumentError, "Richiesta la relation base (es. @discipline.recent_subscriptions)"
    end

    def filter_by_state(scope)
      base_scope = super(scope)

      case @params[:state]
      when "active"   then base_scope.active
      when "expired"  then base_scope.expired
      when "upcoming" then base_scope.upcoming
      else base_scope
      end
    end

    def filter_by_search(scope)
      return scope if @params[:query].blank?
      scope.joins(:member).merge(Member.search_text(@params[:query]))
    end

    def apply_custom_filters(scope)
      # Uniamo la tabella members a prescindere se usiamo il filtro del certificato
      s = @params[:med_cert].present? ? scope.joins(:member) : scope

      s.then { |q| filter_by_product(q) }
       .then { |q| filter_by_membership_status(q) }
       .then { |q| filter_by_med_cert(q) }
    end

    def filter_by_product(scope)
      return scope if @params[:product_id].blank?

      # Specifichiamo la tabella 'subscriptions' per evitare ambiguità SQL
      scope.where(subscriptions: { product_id: @params[:product_id] })
    end

    def filter_by_membership_status(scope)
      return scope if @params[:membership_status].blank?

      # 1. Troviamo gli ID di chi ha un "Tesseramento" (prodotto associativo) attivo in questo momento
      active_member_ids = Subscription.active
                                      .joins(:product)
                                      .where(products: { accounting_category: "associative" })
                                      .select(:member_id)

      # 2. Filtriamo la query principale basandoci su quegli ID
      if @params[:membership_status] == "active"
        scope.where(member_id: active_member_ids)
      else
        scope.where.not(member_id: active_member_ids)
      end
    end

    def filter_by_med_cert(scope)
      return scope if @params[:med_cert].blank?

      today = Date.current

      case @params[:med_cert]
      when "valid"
        # Scadenza futura o uguale a oggi
        scope.where("members.medical_certificate_expiry >= ?", today)
      when "expiring"
        # Scade nei prossimi 30 giorni
        scope.where(members: { medical_certificate_expiry: today..(today + 30.days) })
      when "invalid"
        # Scaduto (passato) o mai inserito (NULL)
        scope.where("members.medical_certificate_expiry < ? OR members.medical_certificate_expiry IS NULL", today)
      else
        scope
      end
    end

    def apply_sorting(scope)
      case @params[:sort]
      when "expiring_asc"  then scope.order(end_date: :asc)
      when "expiring_desc" then scope.order(end_date: :desc)
      when "recent"        then scope.order(created_at: :desc)
      else
        @params[:query].present? ? scope : scope.order(end_date: :asc)
      end
    end
end
