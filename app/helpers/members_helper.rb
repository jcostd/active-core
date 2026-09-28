module MembersHelper
  def member_membership_filters
    [
      [ "Quota valida", "active" ],
      [ "Quota scaduta", "expired" ],
      [ "Mai tesserato", "missing" ]
    ]
  end

  def member_med_cert_filters
    [
      [ "Valido", "valid" ],
      [ "Scaduto", "expired" ],
      [ "Mancante", "missing" ]
    ]
  end

  def member_status_badges(member)
    safe_join [ ui_status_badge(member.membership_valid?, valid_text: "Quota valida", invalid_text: "Quota scaduta"),
                (ui_status_badge(false, valid_text: "", invalid_text: "Cert. Medico", invalid_tone: "badge-warning") unless member.medical_certificate_valid?) ].compact, " "
  end

  def member_empty_subscriptions_badge
    tag.span "Nessun abbonamento attivo", class: "text-[10px] uppercase font-bold tracking-wider opacity-40"
  end
end
