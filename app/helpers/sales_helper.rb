module SalesHelper
  PAYMENT_METHODS = {
    "cash"          => { label: "Contanti",    icon: "payments",        color: "badge-success" },
    "credit_card"   => { label: "Carta / POS", icon: "credit_card",     color: "badge-info" },
    "bank_transfer" => { label: "Bonifico",    icon: "account_balance", color: "badge-warning" },
    "other"         => { label: "Altro",       icon: "receipt",         color: "badge-ghost" }
  }.freeze

  SUBSCRIPTION_STATUS_STYLES = {
    expired:         { color: "badge-error",   icon: "error" },
    pending_payment: { color: "badge-warning", icon: "payments" },
    expiring_soon:   { color: "badge-warning", icon: "warning" },
    active:          { color: "badge-ghost",   icon: "check_circle" }
  }.freeze

  def subscription_badge_color(status_key)
    data = SUBSCRIPTION_STATUS_STYLES[status_key.to_sym] || SUBSCRIPTION_STATUS_STYLES[:active]
    data[:color]
  end

  def grouped_product_options
    products = Product.kept.order(:name).includes(:disciplines)

    groups = Hash.new { |h, k| h[k] = [] }
    uncategorized = []

    products.each do |product|
      active_disciplines = product.disciplines.reject(&:discarded?)

      if active_disciplines.any?
        active_disciplines.each do |discipline|
          groups[discipline.name] << [ product.name, product.id ]
        end
      else
        uncategorized << [ product.name, product.id ]
      end
    end

    result = groups.sort.map { |discipline_name, product_list| [ discipline_name, product_list ] }

    if uncategorized.any?
      result.unshift([ "Quote e Varie", uncategorized ])
    end

    result
  end

  # PER I FORM: f.select :payment_method, payment_method_options
  def payment_method_options
    PAYMENT_METHODS.map { |key, data| [ data[:label], key ] }
  end

  def payment_method_icon(method, classes: "size-6")
    data = PAYMENT_METHODS[method.to_s] || PAYMENT_METHODS["other"]
    icon(data[:icon], classes: classes)
  end

  def payment_method_badge(method)
    data = PAYMENT_METHODS[method.to_s] || PAYMENT_METHODS["other"]
    content_tag(:div, class: "badge badge-sm badge-soft gap-1 text-[10px] uppercase font-bold tracking-wider #{data[:color]}") do
      icon(data[:icon], classes: "size-3") + " #{data[:label]}"
    end
  end

  def transaction_status_indicator(sale)
    if sale.discarded?
      content_tag(:span, class: "text-error font-bold flex items-center gap-1") do
        icon("close", classes: "size-3") + " ANNULLATA"
      end
    else
      content_tag(:span, class: "text-success font-bold flex items-center gap-1") do
        icon("success", classes: "size-3") + " Pagamento Confermato"
      end
    end
  end
end
