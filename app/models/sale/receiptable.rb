# Ricevuta: dati del prodotto congelati alla vendita e numero progressivo (solo contanti).
module Sale::Receiptable
  extend ActiveSupport::Concern

  included do
    before_validation :snapshot_product, on: :create
    before_validation :assign_receipt_number, on: :create

    validates :receipt_sequence, presence: true
  end

  private
    def snapshot_product
      return unless product

      self.product_name_snapshot = product.name
      self.receipt_sequence ||= product.accounting_category
    end

    def assign_receipt_number
      return unless cash? && receipt_number.nil? && receipt_sequence

      self.receipt_year ||= (sold_on || Date.current).year
      self.receipt_number = ReceiptCounter.next_number(receipt_year, receipt_sequence)
    end
end
