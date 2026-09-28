class Sale < ApplicationRecord
  # l'ordine conta: callback e validazioni girano nell'ordine di inclusione
  include SoftDeletable     # definisce i callback di archiviazione usati sotto
  include Refreshable
  include FiscalLockable
  include Monetizable
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
