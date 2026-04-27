class SubscriptionStatus
  attr_reader :subscription

  def initialize(subscription)
    @subscription = subscription
  end

  def requires_attention?
    [ :pending_payment, :expired, :expiring_soon, :out_of_entries ].include?(key)
  end

  def key
    if !subscription.fully_paid?
      :pending_payment
    elsif subscription.expired? || subscription.out_of_entries?
      :expired
    elsif subscription.future?
      :future
    elsif subscription.expiring_soon?
      :expiring_soon
    else
      :active
    end
  end

  def label
    case key
    when :pending_payment then "Da Saldare"
    when :expired         then "Scaduto"
    when :future          then "Futuro"
    when :expiring_soon   then "In Scadenza"
    when :active          then "Attivo"
    end
  end

  def color
    case key
    when :pending_payment then "error"
    when :expired         then "neutral"
    when :future          then "info"
    when :expiring_soon   then "warning"
    when :active          then "success"
    end
  end

  def icon
    case key
    when :pending_payment then "payments"
    when :expired         then "history"
    when :future          then "calendar_today"
    when :expiring_soon   then "notification_important"
    when :active          then "success"
    end
  end
end
