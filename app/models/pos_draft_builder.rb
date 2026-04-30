class PosDraftBuilder
  attr_reader :context_params, :sale

  def initialize(sale_params:, context_params:, existing_sale: nil)
    @context_params = context_params
    @sale = existing_sale || Sale.new(sale_params)
    @sale.build_subscription unless @sale.subscription.present?
  end

  def build
    setup_base_defaults

    if installment?
      apply_installment_logic
    else
      apply_renewal_template  if renewing?
      reset_draft_if_changed  if form_submitted?
      sync_subscription_identity
      apply_smart_dates
      apply_default_price
    end

    sale
  end

  private

    def installment?
      context_params[:installment_for_subscription_id].present?
    end

    def renewing?
      context_params[:renew_subscription_id].present?
    end

    def form_submitted?
      context_params.has_key?(:sale)
    end

    def setup_base_defaults
      sale.sold_on   ||= Date.current
      sale.member_id ||= context_params[:preset_member_id] || context_params[:member_id]
    end

    def apply_installment_logic
      sub = Subscription.find_by(id: context_params[:installment_for_subscription_id])
      return unless sub

      sale.subscription = sub
      sale.member_id  ||= sub.member_id
      sale.product_id ||= sub.product_id

      if sale.amount.blank? || sale.amount.zero?
        sale.amount_cents = [ sub.agreed_price_cents - sub.amount_paid, 0 ].max
      end
    end

    def apply_renewal_template
      old_sub = Subscription.find_by(id: context_params[:renew_subscription_id])
      return unless old_sub

      sale.product_id ||= old_sub.product_id
      sale.member_id  ||= old_sub.member_id

      sale.subscription.start_date = (old_sub.end_date && old_sub.end_date >= Date.current) ?
                                       old_sub.end_date + 1.day :
                                       Date.current
    end

    def reset_draft_if_changed
      prev_product = context_params[:previous_product_id].to_i
      prev_member  = context_params[:previous_member_id].to_i

      if prev_product != sale.product_id.to_i || prev_member != sale.member_id.to_i
        sale.amount                        = nil
        sale.subscription.start_date       = nil
        sale.subscription.end_date         = nil
        sale.subscription.agreed_price     = nil
      end
    end

    # Assegna le associazioni alla subscription prima di calcolare date e prezzi
    def sync_subscription_identity
      return unless sale.subscription.new_record?

      sale.subscription.member  ||= sale.member
      sale.subscription.product ||= sale.product
    end

    def apply_smart_dates
      return unless sale.subscription.new_record? &&
                    sale.member.present? &&
                    sale.product.present?

      manual_start = context_params.dig(:sale, :subscription_attributes, :start_date)

      if context_params[:override_end_date] == "1"
        manual_end = context_params.dig(:sale, :subscription_attributes, :end_date)
        sale.subscription.end_date = manual_end.presence
      else
        sale.subscription.end_date = nil
      end

      sale.subscription.calculate_dates!(manual_start_date: manual_start)
    end

    def apply_default_price
      return unless sale.product_id.present?

      if sale.subscription.agreed_price.blank? || sale.subscription.agreed_price.zero?
        sale.subscription.agreed_price = sale.product.price
      end

      if sale.amount.blank? || sale.amount.zero?
        sale.amount = sale.subscription.agreed_price
      end
    end
end
