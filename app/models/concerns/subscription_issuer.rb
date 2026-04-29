module SubscriptionIssuer
  extend ActiveSupport::Concern

  included do
    belongs_to :subscription, optional: true, autosave: true, touch: true
    accepts_nested_attributes_for :subscription, reject_if: :all_blank

    after_discard   :discard_subscription_if_empty
    after_undiscard :undiscard_subscription

    validate :require_active_membership_for_courses, on: :create
  end

  private
    def discard_subscription_if_empty
      return unless subscription.present?
      return if subscription.discarded?
      return if subscription.sales.kept.where.not(id: id).exists?
      subscription.discard!
    end

    def undiscard_subscription
      subscription.undiscard! if subscription.present? && subscription.discarded?
    end

    def require_active_membership_for_courses
      return if product.nil? || product.associative?
      return unless subscription&.start_date

      unless member.membership_valid?(subscription.start_date)
        errors.add(:base, "Impossibile vendere #{product.name}: " \
                          "Il socio non avrà una Quota Associativa attiva " \
                          "il #{I18n.l(subscription.start_date)}.")
      end
    end
end
