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

class Member < ApplicationRecord
  include FtsSearchable, SoftDeletable, Personable, HasAddress, Avatarable
  include Refreshable
  include Member::Filterable

  RENEWAL_GRACE_PERIOD = 30

  normalizes :fiscal_code, with: ->(c) { c.strip.upcase.presence }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # casella del form: iscrizione senza CF, da completare in seguito
  attribute :fiscal_code_pending, :boolean, default: false

  has_many :sales,         dependent: :restrict_with_error
  has_many :attendances,   dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  has_many :recent_sales,
           -> { order(sales: { created_at: :desc }).limit(5) },
           class_name: "Sale"

  validates :birth_date, presence: true
  validates :fiscal_code,
            presence: { message: "non può essere lasciato in bianco: inseriscilo o spunta \"CF da completare\"" },
            unless: :fiscal_code_pending?
  validates :fiscal_code, uniqueness: { conditions: -> { kept } }, allow_nil: true
  # soci già presenti con CF errato restano modificabili: si verifica solo un CF nuovo o cambiato
  validate :fiscal_code_checksum, if: -> { fiscal_code.present? && (new_record? || will_save_change_to_fiscal_code?) }

  scope :missing_fiscal_code, -> { where(members: { fiscal_code: nil }) }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone,
            phone: { possible: true, allow_blank: true, types: [ :mobile, :fixed_line ] }

  def fiscal_code_pending?
    super || (persisted? && fiscal_code_in_database.nil?)
  end

  def fiscal_code_checksum
    errors.add(:fiscal_code, "non è valido: controlla lettere, cifre e carattere finale") unless FiscalCode.valid?(fiscal_code)
  end

  # "Via Roma 1, Roma (00100)", senza le parti che mancano
  def full_address
    [ address, [ city, ("(#{zip_code})" if zip_code.present?) ].compact_blank.join(" ") ].compact_blank.join(", ").presence
  end

  # l'unica risposta a "da quando parte il prossimo abbonamento a product?": dal giorno dopo l'ultimo
  # della stessa linea se non è scaduto da più di RENEWAL_GRACE_PERIOD giorni, altrimenti da from;
  # poi il prodotto allinea le date (mese solare, anno sportivo...)
  def next_period_for(product, from: Date.current)
    from = from.to_date
    previous_end = subscriptions.kept.where(product: product.same_line).maximum(:end_date)
    continues = previous_end && (from - previous_end.next_day).to_i <= RENEWAL_GRACE_PERIOD

    Duration.for(product, continues ? previous_end.next_day : from)
  end

  def medical_certificate_valid?(date = Date.current)
    medical_certificate_expiry.present? && medical_certificate_expiry >= date
  end

  def membership_valid?(date = Date.current)
    if subscriptions.loaded?
      subscriptions.any? do |s|
        s.kept? &&
        s.product&.associative? &&
        s.start_date && s.start_date <= date &&
        s.end_date && s.end_date >= date
      end
    else
      subscriptions.memberships.active_at(date).exists?
    end
  end

  # fine della copertura associativa continua a partire da date (quote consecutive sommate)
  def membership_covered_until(date)
    memberships = subscriptions.memberships.kept.where(subscriptions: { end_date: date.. }).order(:start_date)

    memberships.reduce(nil) do |covered, membership|
      break covered if membership.start_date > (covered ? covered + 1 : date)
      [ covered, membership.end_date ].compact.max
    end
  end

  # abbonamenti della disciplina che toccano il periodo; in memoria: chi li mostra li precarica
  def enrollments_in(discipline, during:)
    subscriptions
      .select { it.kept? && it.start_date <= during.last && it.end_date >= during.first && it.product.disciplines.include?(discipline) }
      .sort_by(&:start_date)
  end

  def relevant_subscriptions(date = Date.current)
    subs = subscriptions.loaded? ? subscriptions.select(&:kept?) : subscriptions.kept.to_a

    subs.select { it.end_date && it.end_date >= date - 30.days }
        .group_by(&:product_id)
        .map { |_, product_subs| product_subs.max_by(&:end_date) }
        .sort_by(&:end_date)
        .reverse
  end
end
