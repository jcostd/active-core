# Cosa lo staff non può fare: date nel passato, inizio anticipato, regalare prodotti a pagamento.
module Sale::StaffLimits
  extend ActiveSupport::Concern

  included do
    validate :staff_accounting_date, :staff_start_date, :staff_free_sale, on: :create, if: :staff_sale?
  end

  # inizio solo in avanti rispetto alla proposta del POS, e non oltre l'anno sportivo successivo
  # (la proposta vale sempre, anche se il socio ha già pagato più avanti)
  def staff_start_range
    return unless member && product

    earliest = member.next_period_for(product).start_date
    earliest..[ SportYear.current.next.end_date, earliest ].max
  end

  private
    def staff_sale?
      user && !user.admin?
    end

    def staff_accounting_date
      errors.add(:sold_on, "può essere modificata solo da un amministratore") if sold_on != Date.current
    end

    def staff_start_date
      return unless subscription&.new_record? && subscription.start_date && (range = staff_start_range)

      if subscription.start_date < range.begin
        errors.add(:subscription, "può iniziare al più presto il #{I18n.l(range.begin)}")
      elsif subscription.start_date > range.end
        errors.add(:subscription, "può iniziare al più tardi il #{I18n.l(range.end)}")
      end
    end

    # i prodotti gratuiti sì, quelli a pagamento no
    def staff_free_sale
      return unless amount_cents&.zero? && !installment? && product&.price_cents.to_i.positive?

      errors.add(:base, "Solo un amministratore può registrare una vendita a zero.")
    end
end
