module MembersHelper
  def member_membership_filters
    [
      [ "In Regola (Attivo)", "active" ],
      [ "Scaduto", "expired" ],
      [ "Mai Tesserato (Prospect)", "missing" ]
    ]
  end

  def member_med_cert_filters
    [
      [ "Valido", "valid" ],
      [ "Scaduto", "expired" ],
      [ "Mancante", "missing" ]
    ]
  end

  def member_status_color_class(member)
    if member.membership_valid? && member.medical_certificate_valid?
      "text-success"
    elsif member.membership_valid?
      "text-warning"
    else
      "text-error"
    end
  end

  def member_status_badges(member)
    badges = []

    # Badge Tessera
    badges << ui_status_badge(
      member.membership_valid?,
      valid_text: "Tessera Attiva",
      invalid_text: "Tessera Scaduta"
    )

    # Badge Certificato Medico
    unless member.medical_certificate_valid?
      badges << ui_status_badge(
        false,
        valid_text: "",
        invalid_text: "Cert. Medico",
        invalid_class: "badge-warning badge-soft"
      )
    end

    safe_join(badges, content_tag(:span, nil, class: "w-1 h-1 rounded-full bg-base-content/30 hidden sm:block"))
  end

  def member_empty_subscriptions_badge
    content_tag(:span, class: "text-[10px] uppercase font-bold tracking-wider opacity-40 flex items-center gap-1") do
      content_tag(:span, nil, class: "size-1.5 rounded-full bg-current") + " Nessun abbonamento attivo"
    end
  end
end
