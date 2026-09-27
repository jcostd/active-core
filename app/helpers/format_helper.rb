module FormatHelper
  def display_value(value, placeholder: "—")
    return tag.span(placeholder, class: "text-base-content/40 font-mono text-sm select-none") if value.blank?

    block_given? ? yield(value) : value
  end

  def format_date(date, format: :default) = date ? l(date.to_date, format:) : display_value(nil)

  def format_datetime(datetime, format: :default) = datetime ? l(datetime, format:) : display_value(nil)

  def format_time_ago(datetime)
    return display_value(nil) unless datetime

    tag.span time_ago_in_words(datetime), title: l(datetime, format: :long)
  end

  def format_money(amount) = amount ? number_to_currency(amount, unit: "€", format: "%n %u") : display_value(nil)

  # importi salvati in centesimi: 1050 -> "10,50 €"
  def format_cents(cents) = cents ? format_money(cents / 100.0) : display_value(nil)

  def format_phone(phone)
    return display_value(nil) if phone.blank?

    parsed = Phonelib.parse(phone)
    parsed.valid? ? parsed.full_international : phone
  end

  def format_email(email) = display_value(email) { link_to(it, "mailto:#{it}", class: "link link-hover") }
end
