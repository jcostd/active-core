module KioskHelper
  # varianti delle card del kiosk per esito; classi scritte per intero perché Tailwind le trovi
  KIOSK_PENDING_STYLES = {
    ok:      { card: "bg-base-100 border-base-200", button: "btn-primary" },
    warning: { card: "bg-info/5 border-info/50",    button: "btn-info" },
    error:   { card: "bg-error/5 border-error/50",  button: "btn-error" }
  }.freeze

  KIOSK_CHECKED_IN_STYLES = {
    "ok"      => "bg-success/50 border-success/20",
    "warning" => "bg-success/50 border-info/50",
    "error"   => "bg-error/80 border-error"
  }.freeze

  def kiosk_pending_style(policy) = KIOSK_PENDING_STYLES.fetch(policy.status)
  def kiosk_checked_in_style(log) = KIOSK_CHECKED_IN_STYLES.fetch(log.status)

  # motivo breve da mostrare sotto il nome
  def kiosk_policy_note(policy)
    case policy.status
    when :error   then policy.member.membership_valid? ? "Abbonamento assente" : "Quota mancante"
    when :warning then policy.member.medical_certificate_valid? ? "In scadenza" : "Cert. scaduto"
    end
  end

  def kiosk_log_note(log)
    case log.status
    when "error"   then "Da regolarizzare"
    when "warning" then log.member.medical_certificate_valid? ? "In scadenza" : "Cert. scaduto"
    end
  end
end
