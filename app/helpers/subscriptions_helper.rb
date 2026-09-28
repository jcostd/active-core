module SubscriptionsHelper
  # unica fonte di icone e colori; classi scritte per intero perché Tailwind le trovi
  SUBSCRIPTION_STATUS_STYLES = {
    expired:         { icon: "history",                badge: "badge-neutral", tint: "bg-neutral/10 text-neutral" },
    future:          { icon: "calendar_today",         badge: "badge-info",    tint: "bg-info/10 text-info" },
    expiring_soon:   { icon: "notification_important", badge: "badge-warning", tint: "bg-warning/10 text-warning" },
    active:          { icon: "success",                badge: "badge-success", tint: "bg-success/10 text-success" }
  }.freeze

  SUBSCRIPTION_PAYMENT_STYLES = { paid: "badge-success", due: "badge-warning", overdue: "badge-error" }.freeze

  def subscription_status_style(subscription) = SUBSCRIPTION_STATUS_STYLES.fetch(subscription.status)

  def subscription_status_badge(subscription)
    style = subscription_status_style(subscription)
    tag.span class: [ "badge badge-sm badge-soft gap-1", style[:badge] ] do
      safe_join([ icon(style[:icon], classes: "size-3"), subscription.status_label ])
    end
  end

  # "Da saldare 20,00 €", "Insoluto 20,00 €" o "Saldato"; niente per ciò che è gratuito
  def subscription_payment_badge(subscription)
    return if subscription.agreed_price_cents.to_i <= 0

    text = [ subscription.payment_status_label, (format_cents(subscription.amount_due) unless subscription.payment_status == :paid) ].compact.join(" ")
    tag.span text, class: [ "badge badge-sm badge-soft", SUBSCRIPTION_PAYMENT_STYLES.fetch(subscription.payment_status) ]
  end

  # rinnovare è vendere di nuovo lo stesso prodotto: le date le propone il POS
  def renew_sale_path(subscription)
    new_sale_path(sale: { member_id: subscription.member_id, product_id: subscription.product_id })
  end
end
