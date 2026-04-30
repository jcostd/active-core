module SafeDateParsing
  extend ActiveSupport::Concern

  included do
    helper_method :parse_month_param, :parse_date_param
  end

  private
    def parse_month_param(month_string, fallback: Date.current)
      return fallback if month_string.blank?

      normalized_string = month_string.to_s.strip

      unless normalized_string.match?(/\A\d{4}-\d{2}\z/)
        Rails.logger.warn("[SafeDateParsing] Formato mese non valido o manomesso: #{normalized_string.inspect}")
        return fallback
      end

      begin
        Date.strptime("#{normalized_string}-01", "%Y-%m-%d")
      rescue Date::Error => e
        Rails.logger.warn("[SafeDateParsing] Errore logico (Date::Error) per il mese #{normalized_string}: #{e.message}")
        fallback
      end
    end

    def parse_date_param(date_string, fallback: Date.current)
      return fallback if date_string.blank?

      normalized_string = date_string.to_s.strip

      unless normalized_string.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        Rails.logger.warn("[SafeDateParsing] Formato data non valido o manomesso: #{normalized_string.inspect}")
        return fallback
      end

      begin
        Date.strptime(normalized_string, "%Y-%m-%d")
      rescue Date::Error => e
        Rails.logger.warn("[SafeDateParsing] Errore logico (Date::Error) per la data #{normalized_string}: #{e.message}")
        fallback
      end
    end
end
