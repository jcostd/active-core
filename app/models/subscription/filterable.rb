module Subscription::Filterable
  extend ActiveSupport::Concern

  included do
    scope :search_text, ->(query) {
      return all if query.blank?
      joins(:member).merge(Member.search_text(query))
    }

    scope :by_state, ->(state) {
      case state
      when "active"   then active
      when "expired"  then expired
      when "upcoming" then upcoming
      else all
      end
    }

    scope :by_product, ->(product_id) {
      where(subscriptions: { product_id: product_id }) if product_id.present?
    }

    scope :by_membership_status, ->(status) {
      return all if status.blank?

      case status
      when "active"  then joins(:member).merge(Member.with_active_membership)
      when "expired" then joins(:member).merge(Member.without_active_membership)
      when "missing" then joins(:member).merge(Member.without_any_membership)
      else all
      end
    }

    scope :by_med_cert, ->(status) {
      return all if status.blank?

      case status
      when "valid"   then joins(:member).merge(Member.with_valid_med_cert)
      when "expired" then joins(:member).merge(Member.with_expired_med_cert)
      when "missing" then joins(:member).merge(Member.without_med_cert)
      else all
      end
    }

    scope :sorted_by, ->(param) {
      case param
      when "expiring_asc"  then order(subscriptions: { end_date: :asc })
      when "expiring_desc" then order(subscriptions: { end_date: :desc })
      when "recent"        then order(subscriptions: { created_at: :desc })
      else                      order(subscriptions: { end_date: :asc })
      end
    }

    scope :deduplicate_by_member, -> {
      where(id: select("MAX(subscriptions.id)").group("subscriptions.member_id"))
    }
  end

  class_methods do
    def apply_filters(params = {})
      scope = all

      scope = scope.search_text(params[:query])
                   .by_state(params[:state])
                   .by_product(params[:product_id])
                   .by_membership_status(params[:membership_status])
                   .by_med_cert(params[:med_cert])
                   .deduplicate_by_member

      has_query = params[:query].present?
      has_query && params[:sort].blank? ? scope : scope.sorted_by(params[:sort])
    end
  end
end
