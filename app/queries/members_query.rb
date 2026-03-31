class MembersQuery < ApplicationQuery
  private
    def default_relation
      Member.all
    end

    def apply_custom_filters(scope)
      scope
        .then { |s| filter_by_membership(s) }
        .then { |s| filter_by_med_cert(s) }
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
end
