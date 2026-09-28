# i dati dell'ASD stampati sulle ricevute; uno solo per installazione
class GymProfile < ApplicationRecord
  normalizes :name, with: ->(name) { name.squish }
  normalizes :address_line_1, :address_line_2, :city, with: ->(place) { ProperCase.place(place) }
  normalizes :zip_code, with: ->(zip) { zip.gsub(/\D/, "").presence }
  normalizes :vat_number, :bank_iban, with: ->(code) { code.gsub(/\s/, "").upcase.presence }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :phone, with: ->(phone) { phone.squish.presence }

  validates :name, presence: true
  # codice fiscale dell'associazione (11 cifre, come una partita IVA) o di una persona (16 caratteri)
  validates :vat_number, format: { with: /\A(\d{11}|[A-Z0-9]{16})\z/, message: "deve avere 11 cifre o 16 caratteri" }, allow_nil: true
  validates :bank_iban, format: { with: /\A[A-Z]{2}\d{2}[A-Z0-9]{11,30}\z/, message: "non è un IBAN valido" }, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  def self.current
    first_or_create!(name: "ActiveCore Gym")
  end

  def full_address
    [ address_line_1, address_line_2, "#{zip_code} #{city}".squish.presence ]
      .compact_blank
      .join(" - ")
  end
end
