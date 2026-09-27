# Copyright (C) 2026 Jacopo Costantini <jacopocostantini32@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

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
