class AddAgreedPriceToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :agreed_price_cents, :integer, default: 0, null: false
  end
end
