module SalesHelper
  PAYMENT_METHODS = {
    "cash"          => { label: "Contanti",    icon: "payments",        color: "badge-success" },
    "credit_card"   => { label: "Carta / POS", icon: "credit_card",     color: "badge-info" },
    "bank_transfer" => { label: "Bonifico",    icon: "account_balance", color: "badge-warning" },
    "other"         => { label: "Altro",       icon: "receipt",         color: "badge-ghost" }
  }.freeze

  def grouped_product_options
    Discipline.kept.order(:name).includes(:products).map do |discipline|
      active_products = discipline.products.kept.order(:name).pluck(:name, :id)

      [ discipline.name, active_products ]
    end.reject { |_, products| products.empty? }
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
