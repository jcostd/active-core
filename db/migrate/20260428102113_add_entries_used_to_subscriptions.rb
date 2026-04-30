class AddEntriesUsedToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :entries_used, :integer, default: 0, null: false
  end
end
