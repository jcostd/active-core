# nil = non impostato, 0 = voluto (vendita gratuita dell'admin)
class DropZeroDefaultFromMoneyColumns < ActiveRecord::Migration[8.1]
  def change
    change_column_default :sales,         :amount_cents,       from: 0, to: nil
    change_column_default :subscriptions, :agreed_price_cents, from: 0, to: nil
  end
end
