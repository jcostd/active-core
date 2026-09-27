# Pagamento di un abbonamento: nuovo (con la vendita) o rata di uno esistente.
module Sale::Installments
  extend ActiveSupport::Concern

  included do
    belongs_to :subscription, optional: true, autosave: true, touch: true
    accepts_nested_attributes_for :subscription, reject_if: :all_blank

    before_validation :link_new_subscription
    before_validation :default_amount, on: :create

    validate :subscription_matches_sale
    validate :positive_installment, on: :create
    validate :amount_within_due, on: :create

    after_discard   :discard_subscription_if_last_payment
    after_undiscard :undiscard_subscription
  end

  def installment?
    subscription&.persisted?
  end

  private
    def link_new_subscription
      return unless subscription&.new_record?

      subscription.member ||= member
      subscription.product ||= product
      subscription.reference_date ||= sold_on
    end

    def default_amount
      self.amount_cents ||= amount_due
    end

    # rata: residuo dovuto; nuova vendita: prezzo concordato
    def amount_due
      installment? ? subscription.amount_due : subscription&.agreed_price_cents || product&.price_cents
    end

    def subscription_matches_sale
      return unless subscription

      errors.add(:subscription, "non appartiene a questo socio") if subscription.member_id != member_id
      errors.add(:subscription, "non corrisponde al prodotto venduto") if subscription.product_id != product_id
      errors.add(:subscription, "è stato annullato") if new_record? && subscription.discarded?
    end

    def positive_installment
      errors.add(:base, "La rata deve essere maggiore di zero.") if installment? && amount_cents&.zero?
    end

    def amount_within_due
      return unless subscription && amount_cents && amount_due && amount_cents > amount_due

      errors.add(:amount, "supera il residuo dovuto (#{ActiveSupport::NumberHelper.number_to_currency(amount_due / 100.0)})")
    end

    def discard_subscription_if_last_payment
      return if subscription.nil? || subscription.discarded?
      return if subscription.sales.kept.where.not(id:).exists?

      subscription.discard!
    end

    def undiscard_subscription
      subscription.undiscard! if subscription&.discarded?
    end
end
