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
    badges = []

    badges << ui_status_badge(member.membership_valid?, valid_text: "Quota valida", invalid_text: "Quota scaduta")

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
