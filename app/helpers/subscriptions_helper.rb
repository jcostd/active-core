module SubscriptionsHelper
  # unica fonte di icone e colori; classi scritte per intero perché Tailwind le trovi
  SUBSCRIPTION_STATUS_STYLES = {
    expired:         { icon: "history",                badge: "badge-neutral", tint: "bg-neutral/10 text-neutral" },
    future:          { icon: "calendar_today",         badge: "badge-info",    tint: "bg-info/10 text-info" },
    expiring_soon:   { icon: "notification_important", badge: "badge-warning", tint: "bg-warning/10 text-warning" },
    active:          { icon: "success",                badge: "badge-success", tint: "bg-success/10 text-success" }
  }.freeze

  SUBSCRIPTION_PAYMENT_STYLES = { paid: "badge-success", due: "badge-warning", overdue: "badge-error" }.freeze

  def subscription_status_style(status)
    SUBSCRIPTION_STATUS_STYLES.fetch(status.key)
  end

  def subscription_status_badge(status)
    style = subscription_status_style(status)
    tag.span class: [ "badge badge-sm badge-soft gap-1", style[:badge] ] do
      safe_join([ icon(style[:icon], classes: "size-3"), status.label ])
    end
  end

  def subscription_status_icon(status)
    style = subscription_status_style(status)
    tag.div icon(style[:icon]), class: [ "p-2 rounded-box", style[:tint] ]
  end

  def subscription_row_wrapper(subscription, status, &block)
    classes = [ "list-row", "hover:bg-base-200/50", "transition-colors" ]
    classes << "opacity-60 grayscale" if status.key.to_sym == :expired

    content_tag(:li, id: dom_id(subscription), class: classes, &block)
  end

  # "Da saldare 20,00 €", "Insoluto 20,00 €" o "Saldato"; niente per ciò che è gratuito
  def subscription_payment_badge(subscription)
    return if subscription.agreed_price_cents.to_i <= 0

    status = subscription.status
    text = [ status.payment_label, (format_cents(subscription.amount_due) unless status.payment_key == :paid) ].compact.join(" ")
    tag.span text, class: [ "badge badge-sm badge-soft", SUBSCRIPTION_PAYMENT_STYLES.fetch(status.payment_key) ]
  end

  def subscription_days_left_indicator(subscription, status)
    return if status.key.to_sym == :expired

    safe_join([
      content_tag(:span, "|", class: "opacity-30 mx-0.5"),
      content_tag(:span, "#{subscription.days_left} gg rimasti", class: "font-mono")
    ])
  end

  def subscription_sale_receipt_link(sale)
    return unless sale.receipt_code.present?

    safe_join([
      content_tag(:span, "•", class: "opacity-50 mx-1"),
      link_to(sale.receipt_code, [ sale ], class: "link link-hover text-primary font-medium", data: { turbo_frame: "_top" })
    ])
  end

  def subscription_installment_action(subscription, amount_due)
    return unless amount_due > 0

    content_tag(:div, class: "flex items-center justify-between w-full max-w-sm mt-1 bg-warning/10 text-warning px-2 py-1.5 rounded-box") do
      concat content_tag(:span, "Resta: #{format_cents(amount_due)}", class: "text-xs font-bold")
      concat link_to(new_sale_path(member_id: subscription.member_id, installment_for_subscription_id: subscription.id),
                     class: "btn btn-xs btn-warning btn-soft rounded-full",
                     data: { turbo_frame: "modal" }, title: "Incassa Rata") {
        safe_join([ icon("payments", classes: "size-3"), " Incassa" ])
      }
    end
  end

  def subscription_renew_action(subscription, status)
    return unless [ :expired, :expiring_soon ].include?(status.key.to_sym)
    return if subscription.renewed?

    link_to renew_sale_path(subscription),
            class: "btn btn-square btn-sm btn-ghost text-info",
            data: { turbo_frame: "modal" }, title: "Rinnova Abbonamento" do
      icon("reset", classes: "size-5")
    end
  end

  # rinnovare è vendere di nuovo lo stesso prodotto: le date le propone il POS
  def renew_sale_path(subscription)
    new_sale_path(sale: { member_id: subscription.member_id, product_id: subscription.product_id })
  end

  def subscription_archive_action(subscription)
    return unless subscription.discardable_by?(current_user)

    ui_row_delete_button([ subscription ], confirm: "Annullando l'abbonamento annullerai anche i pagamenti collegati. Continuare?", title: "Annulla")
  end
end
