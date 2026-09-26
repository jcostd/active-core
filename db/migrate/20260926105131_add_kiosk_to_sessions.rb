class AddKioskToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :kiosk, :boolean, default: false, null: false
    add_index  :sessions, :updated_at
  end
end
