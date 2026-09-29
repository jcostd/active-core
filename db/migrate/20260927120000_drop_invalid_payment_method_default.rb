# 0 non è un metodo di pagamento: il default (carta) lo decide il modello
class DropInvalidPaymentMethodDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :sales, :payment_method, from: 0, to: nil
  end
end
