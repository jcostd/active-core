# il kiosk ora è un utente (ruolo kiosk), non un segno sulla sessione
class RemoveKioskFromSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :sessions, :kiosk, :boolean, default: false, null: false
  end
end
