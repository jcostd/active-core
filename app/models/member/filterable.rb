module Member::Filterable
  extend ActiveSupport::Concern

  included do
    # contano solo le quote associative non annullate: i corsi non tesserano
    scope :with_active_membership, -> {
      where(id: Subscription.memberships.active_at(Date.current).select(:member_id))
    }

    scope :with_expired_membership, -> {
      where(id: Subscription.memberships.kept.select(:member_id)).where.not(id: with_active_membership.select(:id))
    }

    scope :without_any_membership, -> {
      where.not(id: Subscription.memberships.kept.select(:member_id))
    }

    # iscritti a una disciplina in un periodo: un abbonamento non annullato che lo tocca (pagina Iscritti e kiosk)
    scope :enrolled_in, ->(discipline, during:, product_id: nil) {
      enrollments = Subscription.kept.for_discipline(discipline).overlapping(during)
      enrollments = enrollments.where(product_id:) if product_id.present?
      where(id: enrollments.select(:member_id))
    }

    scope :without_recent_checkin_for, ->(discipline) {
      where.not(id: AccessLog.where(discipline: discipline).recent_for_kiosk.select(:member_id))
    }

    scope :with_valid_med_cert, -> {
      where(members: { medical_certificate_expiry: Date.current.. })
    }

    scope :with_expired_med_cert, -> {
      where(members: { medical_certificate_expiry: ...Date.current })
    }

    scope :without_med_cert, -> {
      where(members: { medical_certificate_expiry: nil })
    }

    scope :sorted_by, ->(param) {
      case param
      when "name_asc"     then order(members: { last_name: :asc, first_name: :asc })
      when "name_desc"    then order(members: { last_name: :desc, first_name: :desc })
      when "created_asc"  then order(members: { created_at: :asc })
      when "created_desc" then order(members: { created_at: :desc })
      else                     order(members: { updated_at: :desc })
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = kept
      scope = scope.search_text(params[:query]) if params[:query].present?

      scope = case params[:membership_status]
      when "active"  then scope.with_active_membership
      when "expired" then scope.with_expired_membership
      when "missing" then scope.without_any_membership
      else scope
      end

      scope = case params[:med_cert]
      when "valid"   then scope.with_valid_med_cert
      when "expired" then scope.with_expired_med_cert
      when "missing" then scope.without_med_cert
      else scope
      end

      scope.sorted_by(params[:sort])
    end
  end
end
