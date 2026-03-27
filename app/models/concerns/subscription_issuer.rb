module SubscriptionIssuer
  extend ActiveSupport::Concern

  included do
    has_one :subscription, dependent: :destroy, inverse_of: :sale
    accepts_nested_attributes_for :subscription, allow_destroy: true

    after_discard :discard_subscription
    after_undiscard :undiscard_subscription

    validate :require_active_membership_for_courses, on: :create
  end

  private

    def discard_subscription
      subscription.discard! if subscription.present? && !subscription.discarded?
    end

    def undiscard_subscription
      subscription.undiscard! if subscription.present? && subscription.discarded?
    end

    def require_active_membership_for_courses
      return if product.nil? || product.associative?
      return unless subscription && subscription.start_date

      unless member.membership_valid?(subscription.start_date)
        errors.add(:base, "Impossibile vendere #{product.name}: Il socio non avrà una Quota Associativa attiva il #{I18n.l(subscription.start_date)}.")
      end
    end
end
