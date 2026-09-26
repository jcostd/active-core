# Cosa lo staff non può fare: date nel passato, inizio anticipato, regalare prodotti a pagamento.
module Sale::StaffLimits
  extend ActiveSupport::Concern

  included do
    validate :staff_accounting_date, :staff_start_date, :staff_free_sale, on: :create, if: :staff_sale?
  end

  private
    def staff_sale?
      user && !user.admin?
    end

    def staff_accounting_date
      errors.add(:sold_on, "può essere modificata solo da un amministratore") if sold_on != Date.current
    end

    # inizio solo in avanti rispetto alla proposta del POS
    def staff_start_date
      return unless subscription&.new_record? && subscription.start_date && member && product

      earliest = Subscription.proposed_start_date(member, product)
      errors.add(:subscription, "può iniziare al più presto il #{I18n.l(earliest)}") if subscription.start_date < earliest
    end

    # i prodotti gratuiti sì, quelli a pagamento no
    def staff_free_sale
      return unless amount_cents&.zero? && !installment? && product&.price_cents.to_i.positive?

      errors.add(:base, "Solo un amministratore può registrare una vendita a zero.")
    end
end
