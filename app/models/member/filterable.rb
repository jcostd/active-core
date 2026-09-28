module Member::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "updated_desc" => { updated_at: :desc },
    "name_asc"     => { last_name: :asc, first_name: :asc },
    "name_desc"    => { last_name: :desc, first_name: :desc },
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc }
  }.freeze

  included do
    include Sortable

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

    scope :by_membership, ->(status) {
      case status
      when "active"  then with_active_membership
      when "expired" then with_expired_membership
      when "missing" then without_any_membership
      end
    }

    scope :with_valid_med_cert,   -> { where(members: { medical_certificate_expiry: Date.current.. }) }
    scope :with_expired_med_cert, -> { where(members: { medical_certificate_expiry: ...Date.current }) }
    scope :without_med_cert,      -> { where(members: { medical_certificate_expiry: nil }) }

    scope :by_med_cert, ->(status) {
      case status
      when "valid"   then with_valid_med_cert
      when "expired" then with_expired_med_cert
      when "missing" then without_med_cert
      end
    }

    # iscritti a una disciplina in un periodo: un abbonamento non annullato che lo tocca (pagina Iscritti e kiosk)
    scope :enrolled_in, ->(discipline, during:, product_id: nil) {
      enrollments = Subscription.kept.for_discipline(discipline).overlapping(during)
      enrollments = enrollments.where(product_id:) if product_id.present?
      where(id: enrollments.select(:member_id))
    }

    # nel registro della disciplina in quel mese
    scope :attended, ->(discipline, month) {
      where(id: Attendance.where(discipline:).in_month(month).select(:member_id))
    }

    scope :by_attendance, ->(discipline, month, seen) {
      case seen
      when "yes" then attended(discipline, month)
      when "no"  then where.not(id: attended(discipline, month).select(:id))
      end
    }
  end

  class_methods do
    def apply_filters(params = {})
      kept.search_text(params[:query])
          .by_membership(params[:membership_status])
          .by_med_cert(params[:med_cert])
          .sorted_by(params[:sort])
    end
  end
end
