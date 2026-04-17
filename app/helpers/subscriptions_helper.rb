module SubscriptionsHelper
  STATUS_I18N = {
    active:          { label: "Attivo",      icon: "success" },
    expired:         { label: "Scaduto",     icon: "error" },
    expiring_soon:   { label: "In Scadenza", icon: "warning" },
    future:          { label: "Futuro",      icon: "clock" },
    pending_payment: { label: "Da Saldare",  icon: "payments" }
  }.with_indifferent_access.freeze

  def subscription_status_label(status_key)
    STATUS_I18N.dig(status_key, :label) || status_key.to_s.humanize
  end

  def subscription_status_icon(status_key)
    STATUS_I18N.dig(status_key, :icon) || "help"
  end

  # Wrapper per gestire le classi CSS condizionali (es. grigio se scaduto)
  def subscription_row_wrapper(subscription, status, &block)
    classes = ["list-row", "hover:bg-base-200/50", "transition-colors"]
    classes << "opacity-60 grayscale" if status.key.to_sym == :expired

    content_tag(:li, id: dom_id(subscription), class: classes, &block)
  end

  def subscription_payment_badge(subscription, amount_due)
    return if subscription.agreed_price_cents.to_i <= 0

    if amount_due > 0
      content_tag(:span, "Da saldare", class: "badge badge-sm badge-soft badge-warning")
    else
      content_tag(:span, "Saldato", class: "badge badge-sm badge-soft badge-success")
    end
  end

  def subscription_days_left_indicator(subscription, status)
    return if status.key.to_sym == :expired

    days = (subscription.end_date - Date.current).to_i
    safe_join([
      content_tag(:span, "|", class: "opacity-30 mx-0.5"),
      content_tag(:span, "#{days} gg rimasti", class: "font-mono")
    ])
  end

  def subscription_sale_receipt_link(sale)
    return unless sale.receipt_code.present?

    safe_join([
      content_tag(:span, "•", class: "opacity-50 mx-1"),
      link_to(sale.receipt_code, [sale], class: "link link-hover text-primary font-medium", data: { turbo_frame: "_top" })
    ])
  end

  def subscription_installment_action(subscription, amount_due)
    return unless amount_due > 0

    content_tag(:div, class: "flex items-center justify-between w-full max-w-sm mt-1 bg-warning/10 text-warning px-2 py-1.5 rounded-box") do
      concat content_tag(:span, "Resta: #{format_cents(amount_due)}", class: "text-xs font-bold")
      concat link_to(new_sale_path(member_id: subscription.member_id, installment_for_subscription_id: subscription.id),
                     class: "btn btn-xs btn-warning btn-soft rounded-full",
                     data: { turbo_frame: "modal" }, title: "Incassa Rata") {
        safe_join([icon("payments", classes: "size-3"), " Incassa"])
      }
    end
  end

  def subscription_renew_action(subscription, status)
    return unless [:expired, :expiring_soon].include?(status.key.to_sym)

    link_to new_sale_path(member_id: subscription.member_id, renew_subscription_id: subscription.id),
            class: "btn btn-square btn-sm btn-ghost text-info",
            data: { turbo_frame: "modal" }, title: "Rinnova Abbonamento" do
      icon("reset", classes: "size-5")
    end
  end

  def subscription_archive_action(subscription)
    return unless subscription.end_date >= 7.days.ago.to_date

    ui_row_delete_button([subscription], confirm: "Eliminando l'abbonamento annullerai l'incasso. Continuare?", title: "Archivia")
  end
end
