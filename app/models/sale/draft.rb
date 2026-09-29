# Bozza del POS: completa una vendita non salvata con le proposte del sistema.
# Riceve solo parametri già permessi; il contesto del form arriva esplicito.
class Sale::Draft
  attr_reader :sale

  def initialize(sale, member_id: nil, installment_for_subscription_id: nil,
                 previous_member_id: nil, previous_product_id: nil, override_end_date: false)
    @sale = sale
    @installment = Subscription.kept.find_by(id: installment_for_subscription_id) if installment_for_subscription_id.present?
    @previous_ids = { member_id: previous_member_id.presence&.to_i, product_id: previous_product_id.presence&.to_i }
    @override_end_date = override_end_date

    sale.sold_on ||= Date.current
    sale.member_id ||= member_id
    @installment ? pay_installment : propose_subscription
  end

  private
    attr_reader :installment

    def pay_installment
      sale.subscription   = installment
      sale.member_id    ||= installment.member_id
      sale.product_id   ||= installment.product_id
      sale.amount_cents ||= installment.amount_due
    end

    def propose_subscription
      subscription = sale.subscription || sale.build_subscription

      subscription.member  ||= sale.member
      subscription.product ||= sale.product
      forget_choices(subscription) if identity_changed?

      propose_dates(subscription) if sale.member && sale.product
      propose_prices(subscription) if sale.product
    end

    # socio o prodotto cambiati nel form: prezzi e date ripartono da zero
    def identity_changed?
      @previous_ids.any? { |attribute, previous| previous && previous != sale.public_send(attribute) }
    end

    def forget_choices(subscription)
      sale.amount_cents = nil
      subscription.agreed_price_cents = nil
      subscription.start_date = nil
      subscription.end_date = nil unless @override_end_date
    end

    def propose_dates(subscription)
      subscription.start_date ||= sale.member.next_period_for(sale.product).start_date
      return if @override_end_date && subscription.end_date

      subscription.end_date = Duration.for(sale.product, subscription.start_date).end_date
    end

    # solo se nil: lo zero è una scelta voluta dell'admin
    def propose_prices(subscription)
      subscription.agreed_price_cents ||= sale.product.price_cents
      sale.amount_cents ||= subscription.agreed_price_cents
    end
end
