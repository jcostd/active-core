class PosDraftBuilder
  attr_reader :context_params, :sale

  def initialize(sale_params:, context_params:, existing_sale: nil)
    @context_params = context_params.is_a?(ActionController::Parameters) ?
                        context_params.to_unsafe_h.deep_symbolize_keys :
                        context_params.deep_symbolize_keys
    @sale = existing_sale || Sale.new(sale_params)
    @sale.build_subscription unless @sale.subscription.present?
  end

  def build
    setup_base_defaults

    if installment?
      apply_installment_logic
    else
      apply_renewal_template if renewing?
      sync_subscription_identity
      reset_prices_if_identity_changed
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

    def override_end_date?
      context_params[:override_end_date] == "1"
    end

    def reset_prices_if_identity_changed
      return unless sale.subscription.new_record?

      current_product_id  = context_params.dig(:sale, :product_id).to_i
      current_member_id   = context_params.dig(:sale, :member_id).to_i
      previous_product_id = context_params[:previous_product_id].to_i
      previous_member_id  = context_params[:previous_member_id].to_i

      return if previous_product_id.zero? && previous_member_id.zero?

      product_changed = previous_product_id != 0 && current_product_id != previous_product_id
      member_changed  = previous_member_id  != 0 && current_member_id  != previous_member_id

      return unless product_changed || member_changed

      sale.amount_cents                    = nil
      sale.subscription.agreed_price_cents = nil
      sale.subscription.start_date         = nil
      sale.subscription.end_date           = nil unless override_end_date?
    end

    def setup_base_defaults
      sale.sold_on   ||= Date.current
      sale.member_id ||= context_params[:preset_member_id] || context_params[:member_id]
    end

    def apply_installment_logic
      sub = Subscription.find_by(id: context_params[:installment_for_subscription_id])
      return unless sub

      sale.subscription  = sub
      sale.member_id   ||= sub.member_id
      sale.product_id  ||= sub.product_id

      if sale.amount.blank? || sale.amount.zero?
        sale.amount_cents = [ sub.agreed_price_cents - sub.amount_paid, 0 ].max
      end
    end

    def apply_renewal_template
      old_sub = Subscription.find_by(id: context_params[:renew_subscription_id])
      return unless old_sub

      sale.product_id ||= old_sub.product_id
      sale.member_id  ||= old_sub.member_id

      sale.subscription.start_date ||=
        if old_sub.end_date && old_sub.end_date >= Date.current
          old_sub.end_date + 1.day
        else
          Date.current
        end
    end

    def sync_subscription_identity
      return unless sale.subscription.new_record?
      sale.subscription.member  ||= sale.member
      sale.subscription.product ||= sale.product
    end

    def apply_smart_dates
      return unless sale.subscription.new_record? && sale.member.present? && sale.product.present?

      manual_start = context_params.dig(:sale, :subscription_attributes, :start_date)
      manual_end   = context_params.dig(:sale, :subscription_attributes, :end_date)

      if manual_start.present?
        sale.subscription.start_date = manual_start
      elsif sale.subscription.start_date.blank?
        sale.subscription.start_date = sale.member.suggested_start_date_for(sale.product, Date.current)
      end

      unless manual_start.present?
        duration = Duration.for(sale.product, sale.subscription.start_date)
        sale.subscription.start_date = duration.start_date
      end

      if override_end_date? && manual_end.present?
        sale.subscription.end_date = manual_end
      else
        duration = Duration.for(sale.product, sale.subscription.start_date)
        sale.subscription.end_date = duration.end_date
      end

      sale.subscription.entry_limit ||= sale.product.entry_limit
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
