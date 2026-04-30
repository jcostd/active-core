module FiscalLockable
  extend ActiveSupport::Concern

  included do
    validate :prevent_fiscal_tampering, on: :update
  end

  private
    def prevent_fiscal_tampering
      fiscal_attributes = [ :receipt_number, :receipt_year, :receipt_sequence ]

      fiscal_attributes.each do |attr|
        next unless will_save_change_to_attribute?(attr)

        if attribute_in_database(attr).present?
          errors.add(attr, :immutable, message: "è un dato fiscale e non può essere modificato dopo l'emissione")
        end
      end
    end
end
