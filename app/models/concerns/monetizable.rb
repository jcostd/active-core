# Importi in centesimi con accessori in euro: `monetize :price` su `price_cents`.
module Monetizable
  extend ActiveSupport::Concern

  # 1.200,50  1,200.50  12,5  12.50  € 45  (migliaia solo a gruppi di tre cifre)
  AMOUNT = /\A(?<sign>-)?(?<units>\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](?<decimals>\d{1,2}))?\z/

  # oltre i dieci milioni di euro è un errore di battitura (e non entrerebbe nella colonna)
  MAX_CENTS = 999_999_999

  # centesimi, oppure nil se il testo non è un importo
  def self.cents(value)
    cents = parse(value)
    cents if cents && cents.abs <= MAX_CENTS
  end

  def self.parse(value)
    return (BigDecimal(value.to_s) * 100).round.to_i if value.is_a?(Numeric)

    match = AMOUNT.match(value.to_s.delete(" €"))
    return unless match

    (BigDecimal("#{match[:sign]}#{match[:units].delete(".,")}.#{match[:decimals] || 0}") * 100).round.to_i
  end
  private_class_method :parse

  included do
    validate :monetized_values_parse
  end

  class_methods do
    def monetize(attribute)
      define_method(attribute) do
        public_send("#{attribute}_cents")&.fdiv(100)
      end

      define_method("#{attribute}=") do |value|
        cents = Monetizable.cents(value) unless value.blank?
        value.present? && cents.nil? ? unparsable_money << attribute : unparsable_money.delete(attribute)
        public_send("#{attribute}_cents=", cents)
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
