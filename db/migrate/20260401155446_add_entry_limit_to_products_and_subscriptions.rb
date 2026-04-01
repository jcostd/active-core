class AddEntryLimitToProductsAndSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :entry_limit, :integer, null: true
    add_column :subscriptions, :entry_limit, :integer, null: true
  end
end
