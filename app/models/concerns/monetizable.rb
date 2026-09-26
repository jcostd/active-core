module Monetizable
  extend ActiveSupport::Concern

  included do
    validate :monetized_values_parse
  end

  class_methods do
    def monetize(attribute_name)
      cents_column = "#{attribute_name}_cents"

      define_method(attribute_name) do
        cents = send(cents_column)
        return nil unless cents
        (cents / 100.0).round(2)
      end

      define_method("#{attribute_name}=") do |value|
        unparsable_money.delete(attribute_name)
        return send("#{cents_column}=", nil) if value.blank?

        # A. Se è già un numero (es: 10.50 o 100)
        if value.is_a?(Numeric)
          # .round(2) evita problemi di virgola mobile (es. 10.5500000001)
          self.send("#{cents_column}=", (value.to_f.round(2) * 100).to_i)

        # B. Se è una stringa (Parsing avanzato)
        else
          # Rimuoviamo spazi e simbolo valuta
          clean = value.to_s.gsub(/[^\d.,-]/, "").strip

          # Caso critico: "1.200" (senza virgola). In Italia è 1200, in USA è 1.2
          # SOLUZIONE: Se c'è solo il punto, contiamo i decimali.
          # Se sono 3 (es: 1.000), assumiamo siano migliaia.

          if clean.include?(".") && !clean.include?(",")
            parts = clean.split(".")
            if parts.last.length == 3
              # È probabile che sia un separatore migliaia (1.000) -> togliamo il punto
              clean = clean.gsub(".", "")
            end
          end

          # Se ci sono sia punti che virgole (1.200,50), togliamo i punti (migliaia)
          if clean.include?(".") && clean.include?(",")
            clean = clean.gsub(".", "")
          end

          # Sostituiamo la virgola con punto per renderlo comprensibile a Ruby
          standardized = clean.gsub(",", ".")

          amount = BigDecimal(standardized, exception: false)

          # testo non numerico: niente crash, errore di validazione
          unless amount
            unparsable_money << attribute_name
            return send("#{cents_column}=", nil)
          end

          self.send("#{cents_column}=", (amount * 100).to_i)
        end
      end
    end
  end

  private
    def unparsable_money
      @unparsable_money ||= Set.new
    end

    def monetized_values_parse
      unparsable_money.each { errors.add(it, "non è un importo valido") }
    end
end
