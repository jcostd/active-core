# nil = unset, 0 = deliberate (admin free sale)
class DropZeroDefaultFromMoneyColumns < ActiveRecord::Migration[8.1]
  def change
    change_column_default :sales,         :amount_cents,       from: 0, to: nil
    change_column_default :subscriptions, :agreed_price_cents, from: 0, to: nil
  end
end
