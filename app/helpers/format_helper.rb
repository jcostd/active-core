module FormatHelper
  # ==========================================
  # VISUALIZZAZIONE GENERICA
  # ==========================================

  def display_value(value, placeholder: "—")
    if value.blank?
      return tag.span(placeholder, class: "text-base-content/40 font-mono text-sm select-none")
    end
    block_given? ? yield(value) : value
  end

  # ==========================================
  # DATE E ORARI
  # ==========================================

  def format_date(date, format: :default)
    return display_value(nil) if date.nil?

    l(date.to_date, format: format)
  end

  def format_datetime(datetime, format: :default)
    return display_value(nil) if datetime.nil?

    l(datetime, format: format)
  end

  def format_time_ago(datetime)
    return display_value(nil) if datetime.nil?

    tag.span(title: l(datetime, format: :long)) do
      time_ago_in_words(datetime)
    end
  end

  # ==========================================
  # IMPORTI E NUMERI
  # ==========================================
  def format_money(amount, currency: "EUR")
    return display_value(nil) if amount.nil?

    number_to_currency(amount, unit: currency == "EUR" ? "€" : currency, format: "%n %u")
  end

  # Usa questo quando hai la colonna raw dal DB (es. sales.sum(:amount_cents))
  # Input: 1050 -> "10,50 €"
  def format_cents(cents, currency: "EUR")
    return display_value(nil) if cents.nil?

    format_money(cents / 100.0, currency: currency)
  end

  # ==========================================
  # CONTATTI E TESTI
  # ==========================================

  def format_phone(phone)
    return display_value(nil) if phone.blank?
    if defined?(Phonelib)
      parsed = Phonelib.parse(phone)
      return parsed.full_international if parsed.valid?
    end
    phone
  end

  def format_email(email)
    display_value(email) do |e|
      link_to(e, "mailto:#{e}", class: "link link-hover")
    end
  end

  # ==========================================
  # BOOLEANI
  # ==========================================
end
