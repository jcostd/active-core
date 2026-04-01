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
end
