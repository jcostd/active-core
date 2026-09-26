# Bozza del POS: completa una vendita non salvata con le proposte del sistema.
# Riceve solo parametri già permessi; il contesto del form arriva esplicito.
class Sale::Draft
  attr_reader :sale

  def initialize(sale, member_id: nil, renew_subscription_id: nil, installment_for_subscription_id: nil,
                 previous_member_id: nil, previous_product_id: nil, override_end_date: false)
    @sale = sale
    @renewed = Subscription.kept.find_by(id: renew_subscription_id) if renew_subscription_id.present?
    @installment = Subscription.kept.find_by(id: installment_for_subscription_id) if installment_for_subscription_id.present?
    @previous_ids = { member_id: previous_member_id.presence&.to_i, product_id: previous_product_id.presence&.to_i }
    @override_end_date = override_end_date

    sale.sold_on ||= Date.current
    sale.member_id ||= member_id
    @installment ? pay_installment : propose_subscription
  end

  private
    attr_reader :renewed, :installment

    def pay_installment
      sale.subscription   = installment
      sale.member_id    ||= installment.member_id
      sale.product_id   ||= installment.product_id
      sale.amount_cents ||= installment.amount_due
    end

    def propose_subscription
      subscription = sale.subscription || sale.build_subscription

      continue_renewal(subscription) if renewed
      subscription.member  ||= sale.member
      subscription.product ||= sale.product
      forget_choices(subscription) if identity_changed?

      propose_dates(subscription) if sale.member && sale.product
      propose_prices(subscription) if sale.product
    end

    # il rinnovo riparte dal giorno dopo la scadenza, o da oggi se è già scaduto
    def continue_renewal(subscription)
      sale.product_id ||= renewed.product_id
      sale.member_id  ||= renewed.member_id
      subscription.start_date ||= Duration.for(sale.product, [ renewed.end_date + 1, Date.current ].max).start_date
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
      subscription.start_date ||= Subscription.proposed_start_date(sale.member, sale.product)
      return if @override_end_date && subscription.end_date

      subscription.end_date = Duration.for(sale.product, subscription.start_date).end_date
    end

    # solo se nil: lo zero è una scelta voluta dell'admin
    def propose_prices(subscription)
      subscription.agreed_price_cents ||= sale.product.price_cents
      sale.amount_cents ||= subscription.agreed_price_cents
    end
end
