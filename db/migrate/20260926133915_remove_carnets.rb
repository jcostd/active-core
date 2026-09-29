# carnet rimossi: il personal training sarà una funzione separata dal kiosk
class RemoveCarnets < ActiveRecord::Migration[8.1]
  def change
    remove_column :products,      :entry_limit,  :integer
    remove_column :subscriptions, :entry_limit,  :integer
    remove_column :subscriptions, :entries_used, :integer, default: 0, null: false
  end
end
