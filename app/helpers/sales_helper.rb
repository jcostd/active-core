module SalesHelper
  def payment_method_badge(method)
    base_class = "badge badge-sm badge-soft gap-1 text-[10px] uppercase font-bold tracking-wider"

    case method.to_s
    when "cash"
      content_tag(:div, class: "#{base_class} badge-success") do
        icon("payments", classes: "size-3") + " Contanti"
      end
    when "credit_card"
      content_tag(:div, class: "#{base_class} badge-info") do
        icon("credit_card", classes: "size-3") + " Carta"
      end
    when "bank_transfer"
      content_tag(:div, class: "#{base_class} badge-warning") do
        icon("account_balance", classes: "size-3") + " Bonifico"
      end
    else
      content_tag(:div, class: "#{base_class} badge-ghost") do
        method.to_s.humanize
      end
    end
  end

  def payment_method_icon(method, classes: "size-6")
    case method.to_s
    when "cash"          then icon("payments", classes: classes)
    when "credit_card"   then icon("credit_card", classes: classes)
    when "bank_transfer" then icon("account_balance", classes: classes)
    else                      icon("paid", classes: classes)
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
