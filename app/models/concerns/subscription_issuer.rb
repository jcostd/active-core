module SubscriptionIssuer
  extend ActiveSupport::Concern

  included do
    has_one :subscription, dependent: :destroy, inverse_of: :sale
    accepts_nested_attributes_for :subscription, allow_destroy: true

    after_discard :discard_subscription
    after_undiscard :undiscard_subscription

    validate :require_active_membership_for_courses, on: :create
    validate :prevent_overlapping_subscriptions, on: :create
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

    def prevent_overlapping_subscriptions
      return unless member && product && subscription
      return unless subscription.start_date && subscription.end_date

      overlapping = member.subscriptions.kept
                          .where(product_id: product.id)
                          .where("start_date <= ? AND end_date >= ?", subscription.end_date, subscription.start_date)

      if overlapping.exists?
        errors.add(:base, "Attenzione: Il socio ha già un abbonamento per '#{product.name}' che si sovrappone a queste date (dal #{I18n.l(subscription.start_date)} al #{I18n.l(subscription.end_date)}).")
      end
    end
end
