# date e mesi dai parametri: formato rigido, altrimenti il fallback (niente eccezioni da input manomessi)
module SafeDateParsing
  private
    def parse_month_param(value, fallback: Date.current) = strict_date(value, /\A\d{4}-\d{2}\z/, "%Y-%m") || fallback

    def parse_date_param(value, fallback: Date.current) = strict_date(value, /\A\d{4}-\d{2}-\d{2}\z/, "%Y-%m-%d") || fallback

    def strict_date(value, format, pattern)
      Date.strptime(value.to_s.strip, pattern) if value.to_s.strip.match?(format)
    rescue Date::Error
      nil
    end
end
