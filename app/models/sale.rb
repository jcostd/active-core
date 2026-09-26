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

class Sale < ApplicationRecord
  # l'ordine conta: callback e validazioni girano nell'ordine di inclusione
  include SoftDeletable     # definisce i callback di archiviazione usati sotto
  include Refreshable
  include FiscalLockable
  include Monetizable
  include Trackable
  include Receiptable
  include Installments      # l'abbonamento calcola le sue date prima dei controlli seguenti
  include MembershipGuard
  include StaffLimits
  include Reversible
  include Filterable

  monetize :amount

  belongs_to :member, touch: true
  belongs_to :user
  belongs_to :product

  enum :payment_method, { cash: 1, credit_card: 2, bank_transfer: 3, other: 4 }, default: :credit_card, validate: true

  before_validation -> { self.sold_on ||= Date.current }, on: :create

  validates :sold_on, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :sellable, on: :create

  private
    # niente nuovi abbonamenti ad archiviati; le rate di quelli esistenti restano incassabili
    def sellable
      return if installment?

      errors.add(:member, "è archiviato") if member&.discarded?
      errors.add(:product, "è archiviato") if product&.discarded?
    end
end
